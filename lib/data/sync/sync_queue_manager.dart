import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/models/siniestro_model.dart';
import '../../domain/models/sync_item_model.dart';
import '../datasources/google_sheets_service.dart';
import '../datasources/local_storage_service.dart';
import '../repositories/siniestro_repository.dart';

/// Estados globales del motor de sincronización
enum SyncState {
  synced,
  pendingOffline,
  syncing,
  authRequired,
  error,
}

/// Administrador central de la cola de sincronización offline-first con Google Sheets
class SyncQueueManager extends ChangeNotifier {
  final GoogleSheetsService _sheetsService;
  final SiniestroRepository _siniestroRepository;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _autoPullTimer;

  SyncState _state = SyncState.synced;
  String? _lastErrorMessage;
  DateTime? _lastSyncTime;
  int _pendingCount = 0;

  SyncState get state => _state;
  String? get lastErrorMessage => _lastErrorMessage;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get pendingCount => _pendingCount;
  bool get isSyncing => _state == SyncState.syncing;

  SyncQueueManager({
    required GoogleSheetsService sheetsService,
    required SiniestroRepository siniestroRepository,
  })  : _sheetsService = sheetsService,
        _siniestroRepository = siniestroRepository {
    _initConnectivityListener();
    _refreshPendingCount();
    _startAutoPullTimer();
  }

  void _startAutoPullTimer() {
    // Sondeo periódico cada 20 segundos para recibir Arribo y Cierre en vivo desde campo
    _autoPullTimer?.cancel();
    _autoPullTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_state != SyncState.syncing) {
        pullFromRemote();
      }
    });
  }

  void _refreshPendingCount() {
    _pendingCount = LocalStorageService.getSyncQueue().length;
    if (_pendingCount == 0 && _state != SyncState.syncing) {
      _state = SyncState.synced;
    } else if (_pendingCount > 0 && _state != SyncState.syncing) {
      _state = SyncState.pendingOffline;
    }
    notifyListeners();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection && _pendingCount > 0 && _state != SyncState.syncing) {
        debugPrint('Conectividad detectada. Disparando sincronización en segundo plano...');
        processQueue();
      }
      if (hasConnection && _state != SyncState.syncing) {
        pullFromRemote();
      }
    });
  }

  /// Procesa secuencialmente todos los elementos pendientes en la cola de sincronización
  Future<void> processQueue() async {
    final spreadsheetId = LocalStorageService.getSpreadsheetId();
    if (spreadsheetId.trim().isEmpty) {
      _state = SyncState.authRequired;
      _lastErrorMessage = 'ID de Hoja de Cálculo no configurado.';
      notifyListeners();
      return;
    }

    if (!_sheetsService.isSignedIn) {
      // Intentar login silencioso primero
      final silentOk = await _sheetsService.signInSilently();
      if (!silentOk) {
        _state = SyncState.authRequired;
        _lastErrorMessage = 'Se requiere iniciar sesión con Google para sincronizar.';
        notifyListeners();
        return;
      }
    }

    _state = SyncState.syncing;
    _lastErrorMessage = null;
    notifyListeners();

    try {
      // 1. Asegurar pestañas y encabezados
      await _sheetsService.ensureSheetTabsAndHeaders(spreadsheetId);

      // 2. Procesar cola
      final queue = LocalStorageService.getSyncQueue();
      for (final item in queue) {
        try {
          if (item.action == SyncAction.create) {
            final siniestro = SiniestroModel.fromMap(item.payload);
            final rowNumber = await _sheetsService.appendSiniestro(spreadsheetId, siniestro);
            await _siniestroRepository.markAsSynchronized(siniestro.id, rowNumber: rowNumber);
            await LocalStorageService.removeSyncItem(item.id);
          } else if (item.action == SyncAction.update) {
            final siniestro = SiniestroModel.fromMap(item.payload);
            await _sheetsService.updateSiniestro(spreadsheetId, siniestro);
            await _siniestroRepository.markAsSynchronized(siniestro.id);
            await LocalStorageService.removeSyncItem(item.id);
          } else if (item.action == SyncAction.delete) {
            // En Google Sheets no se suele borrar la fila física para auditoría, se elimina de la cola
            await LocalStorageService.removeSyncItem(item.id);
          }
        } catch (itemError) {
          debugPrint('Error procesando elemento ${item.id}: $itemError');
          final updatedItem = item.copyWith(
            retryCount: item.retryCount + 1,
            errorMessage: itemError.toString(),
          );
          await LocalStorageService.updateSyncItem(updatedItem);
        }
      }

      _lastSyncTime = DateTime.now();
      _refreshPendingCount();
    } catch (e) {
      debugPrint('Error general en sincronización: $e');
      _state = SyncState.error;
      _lastErrorMessage = e.toString();
      _refreshPendingCount();
    }
  }

  /// Descarga y fusiona los registros remotos de Google Sheets a la base local
  /// (Detecta automáticamente Arribos y Cierres enviados por MAGG Receptor)
  Future<void> pullFromRemote() async {
    String spreadsheetId = LocalStorageService.getSpreadsheetId();
    if (spreadsheetId.trim().isEmpty) {
      spreadsheetId = AppConstants.defaultSpreadsheetId;
    }

    if (spreadsheetId.trim().isEmpty) {
      return;
    }

    _state = SyncState.syncing;
    notifyListeners();

    try {
      List<SiniestroModel> remoteList = [];

      // 1. Intentar primero con la API autenticada si hay sesión
      if (_sheetsService.isSignedIn) {
        try {
          remoteList = await _sheetsService.fetchSiniestros(spreadsheetId);
        } catch (apiErr) {
          debugPrint('Aviso al consultar Sheets API, intentando gviz fallback: $apiErr');
        }
      }

      // 2. Si no hay sesión o falló la API, usar el fallback público gviz/tq CSV
      if (remoteList.isEmpty) {
        try {
          remoteList = await _sheetsService.fetchSiniestrosViaGviz(spreadsheetId);
        } catch (gvizErr) {
          debugPrint('Error en fallback gviz: $gvizErr');
        }
      }

      if (remoteList.isEmpty) {
        _state = SyncState.synced;
        _lastSyncTime = DateTime.now();
        notifyListeners();
        return;
      }

      // 3. Fusionar con registros locales emparejando por Folio
      final allLocales = LocalStorageService.getSiniestros();
      bool huboCambios = false;

      for (final remote in remoteList) {
        final rFolio = remote.folio.trim().toLowerCase();
        if (rFolio.isEmpty) continue;

        final local = allLocales.where((s) => s.folio.trim().toLowerCase() == rFolio).firstOrNull;

        if (local == null) {
          // No existe localmente: registrar como nuevo
          await LocalStorageService.saveSiniestro(remote.copyWith(sincronizado: true));
          huboCambios = true;
        } else {
          // Ya existe: verificar si el remoto trae Arribo o Conclusión desde MAGG
          bool changed = false;
          SiniestroModel updated = local;

          // Arribo reportado
          if (remote.fechaArribo != null &&
              (local.fechaArribo == null || local.estatus == SiniestroEstatus.asignado)) {
            updated = updated.copyWith(
              fechaArribo: remote.fechaArribo,
              estatus: remote.estatus != SiniestroEstatus.asignado
                  ? remote.estatus
                  : SiniestroEstatus.enAtencion,
            );
            changed = true;
          }

          // Conclusión reportada
          if (remote.fechaConclusion != null &&
              (local.fechaConclusion == null || local.estatus != SiniestroEstatus.concluido)) {
            updated = updated.copyWith(
              fechaConclusion: remote.fechaConclusion,
              tipoCierre: remote.tipoCierre ?? local.tipoCierre,
              estatus: SiniestroEstatus.concluido,
            );
            changed = true;
          }

          // Cambio de estatus general
          if (remote.estatus != local.estatus && remote.estatus != SiniestroEstatus.asignado) {
            updated = updated.copyWith(estatus: remote.estatus);
            changed = true;
          }

          // Guardar número de fila en Sheets si se detectó
          if (remote.rowNumberSheets != null && local.rowNumberSheets != remote.rowNumberSheets) {
            updated = updated.copyWith(rowNumberSheets: remote.rowNumberSheets);
            changed = true;
          }

          if (changed) {
            await LocalStorageService.saveSiniestro(updated.copyWith(sincronizado: true));
            huboCambios = true;
          }
        }
      }

      _lastSyncTime = DateTime.now();
      _state = SyncState.synced;
      if (huboCambios) {
        notifyListeners();
      }
    } catch (e) {
      _state = SyncState.error;
      _lastErrorMessage = e.toString();
    } finally {
      _refreshPendingCount();
    }
  }

  @override
  void dispose() {
    _autoPullTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
