import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
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
  Future<void> pullFromRemote() async {
    final spreadsheetId = LocalStorageService.getSpreadsheetId();
    if (spreadsheetId.isEmpty || !_sheetsService.isSignedIn) {
      return;
    }

    _state = SyncState.syncing;
    notifyListeners();

    try {
      final remoteList = await _sheetsService.fetchSiniestros(spreadsheetId);
      for (final remote in remoteList) {
        final local = LocalStorageService.getSiniestroById(remote.id);
        if (local == null) {
          // No existe localmente, guardarlo como sincronizado
          await LocalStorageService.saveSiniestro(remote.copyWith(sincronizado: true));
        }
      }
      _lastSyncTime = DateTime.now();
      _state = SyncState.synced;
    } catch (e) {
      _state = SyncState.error;
      _lastErrorMessage = e.toString();
    } finally {
      _refreshPendingCount();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
