import '../../domain/models/siniestro_model.dart';
import '../../domain/models/sync_item_model.dart';
import '../datasources/local_storage_service.dart';

/// Repositorio principal de siniestros con estrategia Offline-First
class SiniestroRepository {
  /// Obtiene la lista completa de siniestros desde Hive con filtros opcionales
  List<SiniestroModel> getSiniestros({
    SiniestroEstatus? filterStatus,
    String? searchQuery,
    String? filterAseguradora,
    String? filterAjustador,
  }) {
    var list = LocalStorageService.getSiniestros();

    if (filterStatus != null) {
      list = list.where((s) => s.estatus == filterStatus).toList();
    }

    if (filterAseguradora != null && filterAseguradora.isNotEmpty && filterAseguradora != 'Todas') {
      list = list.where((s) => s.aseguradora.toLowerCase() == filterAseguradora.toLowerCase()).toList();
    }

    if (filterAjustador != null && filterAjustador.isNotEmpty && filterAjustador != 'Todos') {
      list = list.where((s) => s.ajustador.toLowerCase() == filterAjustador.toLowerCase()).toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final query = searchQuery.trim().toLowerCase();
      list = list.where((s) {
        return s.folio.toLowerCase().contains(query) ||
            s.asegurado.toLowerCase().contains(query) ||
            s.placas.toLowerCase().contains(query) ||
            s.ajustador.toLowerCase().contains(query) ||
            s.aseguradora.toLowerCase().contains(query) ||
            s.ubicacion.toLowerCase().contains(query);
      }).toList();
    }

    return list;
  }

  /// Obtiene un siniestro por su identificador único
  SiniestroModel? getById(String id) {
    return LocalStorageService.getSiniestroById(id);
  }

  /// Guarda un nuevo siniestro:
  /// 1. Persiste de inmediato en Hive local.
  /// 2. Encola acción de sincronización para Google Sheets.
  Future<void> save(SiniestroModel siniestro) async {
    final toSave = siniestro.copyWith(
      sincronizado: false,
      ultimaActualizacion: DateTime.now(),
    );
    await LocalStorageService.saveSiniestro(toSave);

    await LocalStorageService.enqueueSync(
      SyncItemModel(
        siniestroId: toSave.id,
        action: SyncAction.create,
        payload: toSave.toMap(),
      ),
    );
  }

  /// Actualiza un siniestro existente
  Future<void> update(SiniestroModel siniestro) async {
    final toSave = siniestro.copyWith(
      sincronizado: false,
      ultimaActualizacion: DateTime.now(),
    );
    await LocalStorageService.saveSiniestro(toSave);

    await LocalStorageService.enqueueSync(
      SyncItemModel(
        siniestroId: toSave.id,
        action: SyncAction.update,
        payload: toSave.toMap(),
      ),
    );
  }

  /// Transiciona el estatus operativo de un siniestro con sellos de tiempo automáticos
  Future<SiniestroModel?> updateEstatus(
    String id,
    SiniestroEstatus nuevoEstatus, {
    String? tipoCierre,
  }) async {
    final siniestro = getById(id);
    if (siniestro == null) return null;

    DateTime? arribo = siniestro.fechaArribo;
    DateTime? conclusion = siniestro.fechaConclusion;

    if (nuevoEstatus == SiniestroEstatus.enAtencion && arribo == null) {
      arribo = DateTime.now();
    } else if (nuevoEstatus == SiniestroEstatus.concluido && conclusion == null) {
      conclusion = DateTime.now();
    }

    final updated = siniestro.copyWith(
      estatus: nuevoEstatus,
      fechaArribo: arribo,
      fechaConclusion: conclusion,
      tipoCierre: tipoCierre ?? siniestro.tipoCierre,
      sincronizado: false,
      ultimaActualizacion: DateTime.now(),
    );

    await update(updated);
    return updated;
  }

  /// Elimina un siniestro localmente y encola eliminación remota
  Future<void> delete(String id) async {
    final existing = getById(id);
    await LocalStorageService.deleteSiniestro(id);

    if (existing != null) {
      await LocalStorageService.enqueueSync(
        SyncItemModel(
          siniestroId: id,
          action: SyncAction.delete,
          payload: {'id': id, 'folio': existing.folio},
        ),
      );
    }
  }

  /// Marca un siniestro como sincronizado exitosamente con Google Sheets
  Future<void> markAsSynchronized(String id, {int? rowNumber}) async {
    final s = getById(id);
    if (s != null) {
      final updated = s.copyWith(
        sincronizado: true,
        rowNumberSheets: rowNumber ?? s.rowNumberSheets,
      );
      await LocalStorageService.saveSiniestro(updated);
    }
  }
}
