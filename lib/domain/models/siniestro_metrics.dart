import 'siniestro_model.dart';

/// Métricas calculadas para cortes y tablero de control
class SiniestroMetrics {
  final int total;
  final int asignados;
  final int enAtencion;
  final int concluidos;
  final int cancelados;
  final Duration? tiempoPromedioArribo;
  final Duration? tiempoPromedioConclusion;
  final Map<String, int> desgloseCierres;
  final Map<String, int> desgloseAseguradoras;
  final Map<String, int> desgloseAjustadores;

  const SiniestroMetrics({
    required this.total,
    required this.asignados,
    required this.enAtencion,
    required this.concluidos,
    required this.cancelados,
    this.tiempoPromedioArribo,
    this.tiempoPromedioConclusion,
    required this.desgloseCierres,
    required this.desgloseAseguradoras,
    required this.desgloseAjustadores,
  });

  factory SiniestroMetrics.fromList(List<SiniestroModel> list) {
    int total = list.length;
    int asignados = 0;
    int enAtencion = 0;
    int concluidos = 0;
    int cancelados = 0;

    final Map<String, int> cierres = {};
    final Map<String, int> aseguradoras = {};
    final Map<String, int> ajustadores = {};

    final List<int> minutosArribo = [];
    final List<int> minutosConclusion = [];

    for (final s in list) {
      switch (s.estatus) {
        case SiniestroEstatus.asignado:
          asignados++;
          break;
        case SiniestroEstatus.enAtencion:
          enAtencion++;
          break;
        case SiniestroEstatus.concluido:
          concluidos++;
          final cierre = s.tipoCierre?.trim().isNotEmpty == true
              ? s.tipoCierre!
              : 'Sin Detalle';
          cierres[cierre] = (cierres[cierre] ?? 0) + 1;
          break;
        case SiniestroEstatus.cancelado:
          cancelados++;
          break;
      }

      // Aseguradora
      final cia = s.aseguradora.trim().isNotEmpty ? s.aseguradora : 'Otro';
      aseguradoras[cia] = (aseguradoras[cia] ?? 0) + 1;

      // Ajustador
      final aj = s.ajustador.trim().isNotEmpty ? s.ajustador : 'Sin Asignar';
      ajustadores[aj] = (ajustadores[aj] ?? 0) + 1;

      // Cálculo de Tiempos
      if (s.fechaArribo != null) {
        final diff = s.fechaArribo!.difference(s.fechaAsignacion).inMinutes;
        if (diff >= 0 && diff <= 300) {
          minutosArribo.add(diff);
        }
      }

      if (s.fechaConclusion != null) {
        final diff = s.fechaConclusion!.difference(s.fechaAsignacion).inMinutes;
        if (diff >= 0 && diff <= 600) {
          minutosConclusion.add(diff);
        }
      }
    }

    Duration? avgArribo;
    if (minutosArribo.isNotEmpty) {
      final avg = minutosArribo.reduce((a, b) => a + b) / minutosArribo.length;
      avgArribo = Duration(minutes: avg.round());
    }

    Duration? avgConclusion;
    if (minutosConclusion.isNotEmpty) {
      final avg = minutosConclusion.reduce((a, b) => a + b) / minutosConclusion.length;
      avgConclusion = Duration(minutes: avg.round());
    }

    return SiniestroMetrics(
      total: total,
      asignados: asignados,
      enAtencion: enAtencion,
      concluidos: concluidos,
      cancelados: cancelados,
      tiempoPromedioArribo: avgArribo,
      tiempoPromedioConclusion: avgConclusion,
      desgloseCierres: cierres,
      desgloseAseguradoras: aseguradoras,
      desgloseAjustadores: ajustadores,
    );
  }
}
