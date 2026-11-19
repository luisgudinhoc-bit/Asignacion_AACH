import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/google_sheets_service.dart';
import '../../data/datasources/local_storage_service.dart';
import '../../domain/models/aseguradora_model.dart';

class AseguradoraNotifier extends StateNotifier<List<AseguradoraModel>> {
  AseguradoraNotifier() : super([]) {
    loadAseguradoras();
  }

  void loadAseguradoras() {
    state = LocalStorageService.getAseguradoras();
  }

  Future<void> addAseguradora({
    required String nombre,
    required String prefijoHabitual,
    required String telefonoCabina,
    GoogleSheetsService? sheetsService,
    String? spreadsheetId,
  }) async {
    final nueva = AseguradoraModel(
      nombre: nombre.trim(),
      prefijoHabitual: prefijoHabitual.trim(),
      telefonoCabina: telefonoCabina.trim(),
    );
    await LocalStorageService.saveAseguradora(nueva);
    loadAseguradoras();

    if (sheetsService != null && spreadsheetId != null && sheetsService.isSignedIn) {
      try {
        await sheetsService.syncAseguradorasToSheets(spreadsheetId, state);
      } catch (e) {
        debugPrint('Error al sincronizar aseguradora agregada con Sheets: $e');
      }
    }
  }

  Future<void> updateAseguradora(
    AseguradoraModel aseguradora, {
    GoogleSheetsService? sheetsService,
    String? spreadsheetId,
  }) async {
    await LocalStorageService.saveAseguradora(aseguradora);
    loadAseguradoras();

    if (sheetsService != null && spreadsheetId != null && sheetsService.isSignedIn) {
      try {
        await sheetsService.syncAseguradorasToSheets(spreadsheetId, state);
      } catch (e) {
        debugPrint('Error al sincronizar aseguradora actualizada con Sheets: $e');
      }
    }
  }

  Future<void> deleteAseguradora(
    String nombre, {
    GoogleSheetsService? sheetsService,
    String? spreadsheetId,
  }) async {
    await LocalStorageService.deleteAseguradora(nombre);
    loadAseguradoras();

    if (sheetsService != null && spreadsheetId != null && sheetsService.isSignedIn) {
      try {
        await sheetsService.syncAseguradorasToSheets(spreadsheetId, state);
      } catch (e) {
        debugPrint('Error al sincronizar eliminación de aseguradora con Sheets: $e');
      }
    }
  }

  /// Sincronización bidireccional completa con la pestaña CATALOGO_ASEGURADORAS de Google Sheets
  Future<void> syncWithGoogleSheets(
    GoogleSheetsService sheetsService,
    String spreadsheetId,
  ) async {
    if (!sheetsService.isSignedIn) {
      throw Exception('Debe iniciar sesión con Google para sincronizar el catálogo.');
    }

    // 1. Obtener aseguradoras remotas de Sheets
    final remoteList = await sheetsService.fetchAseguradoras(spreadsheetId);

    // 2. Obtener lista local actual
    final localList = LocalStorageService.getAseguradoras();

    // 3. Fusión inteligente: preservar datos y no duplicar por nombre
    final mergedMap = <String, AseguradoraModel>{};
    for (final local in localList) {
      mergedMap[local.nombre.toLowerCase().trim()] = local;
    }
    for (final remote in remoteList) {
      // Si ya existía, el remoto manda o actualiza
      mergedMap[remote.nombre.toLowerCase().trim()] = remote;
    }

    final mergedList = mergedMap.values.toList();

    // 4. Guardar localmente
    await LocalStorageService.saveAllAseguradoras(mergedList);

    // 5. Enviar lista completa y limpia de vuelta a Google Sheets
    await sheetsService.syncAseguradorasToSheets(spreadsheetId, mergedList);

    // 6. Actualizar estado
    state = mergedList;
  }
}

final aseguradorasProvider =
    StateNotifierProvider<AseguradoraNotifier, List<AseguradoraModel>>((ref) {
  return AseguradoraNotifier();
});

/// Lista de solo nombres de aseguradoras disponibles para chips y selectores
final aseguradorasNamesProvider = Provider<List<String>>((ref) {
  final list = ref.watch(aseguradorasProvider);
  if (list.isEmpty) {
    return ['Inbursa', 'Quálitas', 'Mapfre', 'GNP Seguros', 'AXA Seguros', 'HDI Seguros', 'Chubb Seguros', 'Crabi', 'SPT Seguros', 'Otra Compañía'];
  }
  return list.map((a) => a.nombre).toList();
});
