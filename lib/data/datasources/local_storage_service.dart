import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/models/ajustador_model.dart';
import '../../domain/models/siniestro_model.dart';
import '../../domain/models/sync_item_model.dart';

/// Servicio de almacenamiento local 100% offline basado en Hive
class LocalStorageService {
  static late Box _siniestrosBox;
  static late Box _ajustadoresBox;
  static late Box _syncQueueBox;
  static late Box _settingsBox;

  /// Inicializa Hive y abre las cajas de almacenamiento
  static Future<void> init() async {
    await Hive.initFlutter();

    _siniestrosBox = await Hive.openBox(AppConstants.siniestrosBox);
    _ajustadoresBox = await Hive.openBox(AppConstants.ajustadoresBox);
    _syncQueueBox = await Hive.openBox(AppConstants.syncQueueBox);
    _settingsBox = await Hive.openBox(AppConstants.appSettingsBox);

    // Precargar ajustadores iniciales si la caja está vacía
    if (_ajustadoresBox.isEmpty) {
      for (final a in AjustadorModel.defaultAjustadores) {
        await _ajustadoresBox.put(a.id, a.toMap());
      }
      debugPrint('Precargados ${AjustadorModel.defaultAjustadores.length} ajustadores iniciales.');
    }
  }

  // ==================== SINIESTROS ====================

  static List<SiniestroModel> getSiniestros() {
    final list = <SiniestroModel>[];
    for (final key in _siniestrosBox.keys) {
      final data = _siniestrosBox.get(key);
      if (data is Map) {
        list.add(SiniestroModel.fromMap(data));
      }
    }
    // Ordenar por fecha de asignación más reciente primero
    list.sort((a, b) => b.fechaAsignacion.compareTo(a.fechaAsignacion));
    return list;
  }

  static SiniestroModel? getSiniestroById(String id) {
    final data = _siniestrosBox.get(id);
    if (data is Map) {
      return SiniestroModel.fromMap(data);
    }
    return null;
  }

  static Future<void> saveSiniestro(SiniestroModel siniestro) async {
    await _siniestrosBox.put(siniestro.id, siniestro.toMap());
  }

  static Future<void> deleteSiniestro(String id) async {
    await _siniestrosBox.delete(id);
  }

  // ==================== AJUSTADORES ====================

  static List<AjustadorModel> getAjustadores() {
    final list = <AjustadorModel>[];
    for (final key in _ajustadoresBox.keys) {
      final data = _ajustadoresBox.get(key);
      if (data is Map) {
        list.add(AjustadorModel.fromMap(data));
      }
    }
    return list;
  }

  static Future<void> saveAjustador(AjustadorModel ajustador) async {
    await _ajustadoresBox.put(ajustador.id, ajustador.toMap());
  }

  static Future<void> deleteAjustador(String id) async {
    await _ajustadoresBox.delete(id);
  }

  // ==================== COLA DE SINCRONIZACIÓN ====================

  static List<SyncItemModel> getSyncQueue() {
    final list = <SyncItemModel>[];
    for (final key in _syncQueueBox.keys) {
      final data = _syncQueueBox.get(key);
      if (data is Map) {
        list.add(SyncItemModel.fromMap(data));
      }
    }
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  static Future<void> enqueueSync(SyncItemModel item) async {
    await _syncQueueBox.put(item.id, item.toMap());
  }

  static Future<void> removeSyncItem(String id) async {
    await _syncQueueBox.delete(id);
  }

  static Future<void> updateSyncItem(SyncItemModel item) async {
    await _syncQueueBox.put(item.id, item.toMap());
  }

  static Future<void> clearSyncQueue() async {
    await _syncQueueBox.clear();
  }

  // ==================== AJUSTES Y CONFIGURACIÓN ====================

  static String? getSpreadsheetId() {
    return _settingsBox.get('spreadsheet_id') as String?;
  }

  static Future<void> setSpreadsheetId(String id) async {
    await _settingsBox.put('spreadsheet_id', id);
  }

  static String? getUserEmail() {
    return _settingsBox.get('user_email') as String?;
  }

  static Future<void> setUserEmail(String email) async {
    await _settingsBox.put('user_email', email);
  }

  static bool isDarkMode() {
    return _settingsBox.get('is_dark_mode') as bool? ?? false;
  }

  static Future<void> setDarkMode(bool isDark) async {
    await _settingsBox.put('is_dark_mode', isDark);
  }
}
