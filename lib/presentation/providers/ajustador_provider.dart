import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/google_sheets_service.dart';
import '../../data/datasources/local_storage_service.dart';
import '../../domain/models/ajustador_model.dart';

class AjustadorNotifier extends StateNotifier<List<AjustadorModel>> {
  AjustadorNotifier() : super([]) {
    loadAjustadores();
  }

  void loadAjustadores() {
    state = LocalStorageService.getAjustadores();
  }

  Future<void> addAjustador({
    required String nombre,
    required String telefonoWhatsApp,
    GoogleSheetsService? sheetsService,
    String? spreadsheetId,
  }) async {
    final nuevo = AjustadorModel(
      nombre: nombre.trim(),
      telefonoWhatsApp: telefonoWhatsApp.trim(),
      activo: true,
    );
    await LocalStorageService.saveAjustador(nuevo);
    loadAjustadores();

    if (sheetsService != null && spreadsheetId != null && sheetsService.isSignedIn) {
      try {
        await sheetsService.syncAjustadoresToSheets(spreadsheetId, state);
      } catch (e) {
        debugPrint('Error al sincronizar ajustador agregado con Sheets: $e');
      }
    }
  }

  Future<void> toggleActivo(
    String id, {
    GoogleSheetsService? sheetsService,
    String? spreadsheetId,
  }) async {
    final index = state.indexWhere((a) => a.id == id);
    if (index != -1) {
      final actual = state[index];
      final actualizado = actual.copyWith(activo: !actual.activo);
      await LocalStorageService.saveAjustador(actualizado);
      loadAjustadores();

      if (sheetsService != null && spreadsheetId != null && sheetsService.isSignedIn) {
        try {
          await sheetsService.syncAjustadoresToSheets(spreadsheetId, state);
        } catch (e) {
          debugPrint('Error al sincronizar cambio de estatus de ajustador con Sheets: $e');
        }
      }
    }
  }

  Future<void> updateAjustador(
    AjustadorModel ajustador, {
    GoogleSheetsService? sheetsService,
    String? spreadsheetId,
  }) async {
    await LocalStorageService.saveAjustador(ajustador);
    loadAjustadores();

    if (sheetsService != null && spreadsheetId != null && sheetsService.isSignedIn) {
      try {
        await sheetsService.syncAjustadoresToSheets(spreadsheetId, state);
      } catch (e) {
        debugPrint('Error al sincronizar ajustador actualizado con Sheets: $e');
      }
    }
  }

  Future<void> deleteAjustador(
    String id, {
    GoogleSheetsService? sheetsService,
    String? spreadsheetId,
  }) async {
    await LocalStorageService.deleteAjustador(id);
    loadAjustadores();

    if (sheetsService != null && spreadsheetId != null && sheetsService.isSignedIn) {
      try {
        await sheetsService.syncAjustadoresToSheets(spreadsheetId, state);
      } catch (e) {
        debugPrint('Error al sincronizar eliminación de ajustador con Sheets: $e');
      }
    }
  }

  /// Sincronización bidireccional completa con la pestaña AJUSTADORES de Google Sheets
  Future<void> syncWithGoogleSheets(
    GoogleSheetsService sheetsService,
    String spreadsheetId,
  ) async {
    if (!sheetsService.isSignedIn) {
      throw Exception('Debe iniciar sesión con Google para sincronizar los ajustadores.');
    }

    // 1. Obtener ajustadores de la hoja de cálculo
    final remoteList = await sheetsService.fetchAjustadores(spreadsheetId);

    // 2. Obtener lista local actual
    final localList = LocalStorageService.getAjustadores();

    // 3. Fusión inteligente por nombre (o ID)
    final mergedMap = <String, AjustadorModel>{};
    for (final local in localList) {
      mergedMap[local.nombre.toLowerCase().trim()] = local;
    }
    for (final remote in remoteList) {
      final key = remote.nombre.toLowerCase().trim();
      if (mergedMap.containsKey(key)) {
        // Preservar ID si ya existía localmente
        final local = mergedMap[key]!;
        mergedMap[key] = remote.copyWith(id: local.id);
      } else {
        mergedMap[key] = remote;
      }
    }

    final mergedList = mergedMap.values.toList();

    // 4. Guardar localmente
    await LocalStorageService.saveAllAjustadores(mergedList);

    // 5. Enviar lista completa y limpia de vuelta a Google Sheets
    await sheetsService.syncAjustadoresToSheets(spreadsheetId, mergedList);

    // 6. Actualizar estado
    state = mergedList;
  }
}

final ajustadoresProvider =
    StateNotifierProvider<AjustadorNotifier, List<AjustadorModel>>((ref) {
  return AjustadorNotifier();
});

/// Ajustadores con estatus activo disponibles para asignación
final activeAjustadoresProvider = Provider<List<AjustadorModel>>((ref) {
  final todos = ref.watch(ajustadoresProvider);
  return todos.where((a) => a.activo).toList();
});
