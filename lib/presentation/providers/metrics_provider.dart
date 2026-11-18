import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/siniestro_metrics.dart';
import '../../domain/models/siniestro_model.dart';
import 'siniestro_provider.dart';

enum DateRangeFilter {
  hoy('Hoy'),
  semana('Semana Actual'),
  quincena('Quincena Actual'),
  mes('Mes Actual'),
  todo('Histórico Completo');

  final String label;
  const DateRangeFilter(this.label);
}

class MetricsFilterState {
  final DateRangeFilter dateRange;
  final String aseguradora;
  final String ajustador;

  const MetricsFilterState({
    this.dateRange = DateRangeFilter.hoy,
    this.aseguradora = 'Todas',
    this.ajustador = 'Todos',
  });

  MetricsFilterState copyWith({
    DateRangeFilter? dateRange,
    String? aseguradora,
    String? ajustador,
  }) {
    return MetricsFilterState(
      dateRange: dateRange ?? this.dateRange,
      aseguradora: aseguradora ?? this.aseguradora,
      ajustador: ajustador ?? this.ajustador,
    );
  }
}

final metricsFilterProvider = StateProvider<MetricsFilterState>((ref) {
  return const MetricsFilterState();
});

/// Filtra la lista de siniestros según los criterios de corte métrico
final metricsSiniestrosProvider = Provider<List<SiniestroModel>>((ref) {
  final all = ref.watch(siniestroListProvider);
  final filter = ref.watch(metricsFilterProvider);
  final now = DateTime.now();

  var list = all;

  // Filtro de rango de fecha
  switch (filter.dateRange) {
    case DateRangeFilter.hoy:
      list = list.where((s) {
        return s.fechaAsignacion.year == now.year &&
            s.fechaAsignacion.month == now.month &&
            s.fechaAsignacion.day == now.day;
      }).toList();
      break;
    case DateRangeFilter.semana:
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final cleanStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      list = list.where((s) => s.fechaAsignacion.isAfter(cleanStart)).toList();
      break;
    case DateRangeFilter.quincena:
      final isFirstHalf = now.day <= 15;
      final startDay = isFirstHalf ? 1 : 16;
      final cleanStart = DateTime(now.year, now.month, startDay);
      list = list.where((s) => s.fechaAsignacion.isAfter(cleanStart)).toList();
      break;
    case DateRangeFilter.mes:
      final cleanStart = DateTime(now.year, now.month, 1);
      list = list.where((s) => s.fechaAsignacion.isAfter(cleanStart)).toList();
      break;
    case DateRangeFilter.todo:
      break;
  }

  // Filtro por Aseguradora
  if (filter.aseguradora != 'Todas') {
    list = list.where((s) => s.aseguradora.toLowerCase() == filter.aseguradora.toLowerCase()).toList();
  }

  // Filtro por Ajustador
  if (filter.ajustador != 'Todos') {
    list = list.where((s) => s.ajustador.toLowerCase() == filter.ajustador.toLowerCase()).toList();
  }

  return list;
});

/// Objeto de métricas consolidadas
final calculatedMetricsProvider = Provider<SiniestroMetrics>((ref) {
  final list = ref.watch(metricsSiniestrosProvider);
  return SiniestroMetrics.fromList(list);
});
