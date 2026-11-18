import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/siniestro_repository.dart';
import '../../domain/models/siniestro_model.dart';
import 'sync_provider.dart';

final siniestroRepositoryProvider = Provider<SiniestroRepository>((ref) {
  return SiniestroRepository();
});

class SiniestroFilterState {
  final SiniestroEstatus? status;
  final String searchQuery;
  final String aseguradora;
  final String ajustador;

  const SiniestroFilterState({
    this.status,
    this.searchQuery = '',
    this.aseguradora = 'Todas',
    this.ajustador = 'Todos',
  });

  SiniestroFilterState copyWith({
    SiniestroEstatus? Function()? status,
    String? searchQuery,
    String? aseguradora,
    String? ajustador,
  }) {
    return SiniestroFilterState(
      status: status != null ? status() : this.status,
      searchQuery: searchQuery ?? this.searchQuery,
      aseguradora: aseguradora ?? this.aseguradora,
      ajustador: ajustador ?? this.ajustador,
    );
  }
}

final siniestroFilterProvider = StateProvider<SiniestroFilterState>((ref) {
  return const SiniestroFilterState();
});

class SiniestroListNotifier extends StateNotifier<List<SiniestroModel>> {
  final SiniestroRepository _repository;
  final Ref _ref;

  SiniestroListNotifier(this._repository, this._ref) : super([]) {
    loadSiniestros();
  }

  void loadSiniestros() {
    state = _repository.getSiniestros();
  }

  Future<SiniestroModel> createSiniestro(SiniestroModel siniestro) async {
    await _repository.save(siniestro);
    loadSiniestros();
    // Notificar al gestor de sincronización
    _ref.read(syncManagerProvider).processQueue();
    return siniestro;
  }

  Future<void> updateSiniestro(SiniestroModel siniestro) async {
    await _repository.update(siniestro);
    loadSiniestros();
    _ref.read(syncManagerProvider).processQueue();
  }

  Future<void> updateEstatus(
    String id,
    SiniestroEstatus nuevoEstatus, {
    String? tipoCierre,
  }) async {
    await _repository.updateEstatus(id, nuevoEstatus, tipoCierre: tipoCierre);
    loadSiniestros();
    _ref.read(syncManagerProvider).processQueue();
  }

  Future<void> deleteSiniestro(String id) async {
    await _repository.delete(id);
    loadSiniestros();
    _ref.read(syncManagerProvider).processQueue();
  }
}

final siniestroListProvider =
    StateNotifierProvider<SiniestroListNotifier, List<SiniestroModel>>((ref) {
  final repo = ref.watch(siniestroRepositoryProvider);
  return SiniestroListNotifier(repo, ref);
});

/// Proveedor filtrado según el estado de búsqueda y pestañas
final filteredSiniestrosProvider = Provider<List<SiniestroModel>>((ref) {
  final all = ref.watch(siniestroListProvider);
  final filter = ref.watch(siniestroFilterProvider);

  var list = all;

  if (filter.status != null) {
    list = list.where((s) => s.estatus == filter.status).toList();
  }

  if (filter.aseguradora != 'Todas') {
    list = list.where((s) => s.aseguradora.toLowerCase() == filter.aseguradora.toLowerCase()).toList();
  }

  if (filter.ajustador != 'Todos') {
    list = list.where((s) => s.ajustador.toLowerCase() == filter.ajustador.toLowerCase()).toList();
  }

  if (filter.searchQuery.trim().isNotEmpty) {
    final q = filter.searchQuery.trim().toLowerCase();
    list = list.where((s) {
      return s.folio.toLowerCase().contains(q) ||
          s.asegurado.toLowerCase().contains(q) ||
          s.placas.toLowerCase().contains(q) ||
          s.ajustador.toLowerCase().contains(q) ||
          s.aseguradora.toLowerCase().contains(q) ||
          s.ubicacion.toLowerCase().contains(q);
    }).toList();
  }

  return list;
});
