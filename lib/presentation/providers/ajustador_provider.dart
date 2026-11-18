import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  }) async {
    final nuevo = AjustadorModel(
      nombre: nombre.trim(),
      telefonoWhatsApp: telefonoWhatsApp.trim(),
      activo: true,
    );
    await LocalStorageService.saveAjustador(nuevo);
    loadAjustadores();
  }

  Future<void> toggleActivo(String id) async {
    final index = state.indexWhere((a) => a.id == id);
    if (index != -1) {
      final actual = state[index];
      final actualizado = actual.copyWith(activo: !actual.activo);
      await LocalStorageService.saveAjustador(actualizado);
      loadAjustadores();
    }
  }

  Future<void> updateAjustador(AjustadorModel ajustador) async {
    await LocalStorageService.saveAjustador(ajustador);
    loadAjustadores();
  }

  Future<void> deleteAjustador(String id) async {
    await LocalStorageService.deleteAjustador(id);
    loadAjustadores();
  }

  Future<void> restoreDefaults() async {
    for (final aj in AjustadorModel.defaultAjustadores) {
      await LocalStorageService.saveAjustador(aj);
    }
    loadAjustadores();
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
