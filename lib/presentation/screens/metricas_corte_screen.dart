import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/export_service.dart';
import '../../core/theme/app_colors.dart';
import '../../data/datasources/local_storage_service.dart';
import '../providers/ajustador_provider.dart';
import '../providers/aseguradora_provider.dart';
import '../providers/metrics_provider.dart';
import '../widgets/metric_summary_card.dart';

/// Pantalla de métricas de desempeño, cortes por turno y exportación
class MetricasCorteScreen extends ConsumerWidget {
  const MetricasCorteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(metricsFilterProvider);
    final metrics = ref.watch(calculatedMetricsProvider);
    final siniestros = ref.watch(metricsSiniestrosProvider);
    final ajustadores = ref.read(ajustadoresProvider);
    final aseguradoras = ref.watch(aseguradorasNamesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Corte Operativo y Métricas',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // 1. Selector de Rango de Fechas
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Período de Corte',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: DateRangeFilter.values.map((range) {
                        final isSelected = filter.dateRange == range;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: Text(
                              range.label,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
                            ),
                            onSelected: (val) {
                              if (val) {
                                ref.read(metricsFilterProvider.notifier).state =
                                    filter.copyWith(dateRange: range);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(height: 20),

                  // Filtros de Aseguradora y Ajustador
                  Row(
                    children: [
                      // Aseguradora Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: filter.aseguradora,
                          decoration: const InputDecoration(
                            labelText: 'Aseguradora',
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: ['Todas', ...aseguradoras].map((cia) {
                            return DropdownMenuItem(value: cia, child: Text(cia, style: const TextStyle(fontSize: 13)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(metricsFilterProvider.notifier).state =
                                  filter.copyWith(aseguradora: val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Ajustador Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: filter.ajustador,
                          decoration: const InputDecoration(
                            labelText: 'Ajustador',
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: ['Todos', ...ajustadores.map((a) => a.nombre)].map((nombre) {
                            return DropdownMenuItem(value: nombre, child: Text(nombre, style: const TextStyle(fontSize: 13)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(metricsFilterProvider.notifier).state =
                                  filter.copyWith(ajustador: val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 2. Tarjetas de Resumen KPI (Grid)
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.45,
            children: [
              MetricSummaryCard(
                title: 'Total Asignados',
                value: '${metrics.total}',
                icon: Icons.assignment_outlined,
                color: AppColors.primaryLight,
              ),
              MetricSummaryCard(
                title: 'Concluidos',
                value: '${metrics.concluidos}',
                icon: Icons.check_circle_outline,
                color: AppColors.statusConcluido,
                subtitle: metrics.total > 0
                    ? '${((metrics.concluidos / metrics.total) * 100).toStringAsFixed(1)}% efectividad'
                    : '0%',
              ),
              MetricSummaryCard(
                title: 'En Atención / Arribo',
                value: '${metrics.enAtencion}',
                icon: Icons.near_me_outlined,
                color: AppColors.statusEnAtencion,
              ),
              MetricSummaryCard(
                title: 'Pendientes / Cancelados',
                value: '${metrics.asignados} / ${metrics.cancelados}',
                icon: Icons.pending_actions_rounded,
                color: AppColors.statusAsignado,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. Tiempos Promedios de Respuesta
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tiempo Promedio de Arribo',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          metrics.tiempoPromedioArribo != null
                              ? '${metrics.tiempoPromedioArribo!.inMinutes} min'
                              : '--',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 36, width: 1, color: Colors.grey.shade300),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Duración Promedio Atención',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          metrics.tiempoPromedioConclusion != null
                              ? '${metrics.tiempoPromedioConclusion!.inMinutes} min'
                              : '--',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 4. Desglose de Tipos de Cierre
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Desglose por Tipo de Cierre',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Divider(height: 16),
                  if (metrics.desgloseCierres.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Sin siniestros concluidos en este período.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ...metrics.desgloseCierres.entries.map((entry) {
                      final pct = metrics.concluidos > 0
                          ? entry.value / metrics.concluidos
                          : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text('${entry.value} (${(pct * 100).toStringAsFixed(0)}%)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: pct,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.statusConcluido),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 5. Botones Operativos de Consulta y Resumen
          ElevatedButton.icon(
            onPressed: () async {
              final url = LocalStorageService.getSpreadsheetUrl();
              if (url != null) {
                final uri = Uri.parse(url);
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('No se pudo abrir el navegador: $e')),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ Primero configura la URL o ID de tu hoja en la pestaña "Ajustes".'),
                    backgroundColor: AppColors.statusAsignado,
                  ),
                );
              }
            },
            icon: const Icon(Icons.table_chart_rounded),
            label: const Text('Consultar Archivo en Google Drive'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: siniestros.isEmpty
                ? null
                : () => ExportService.shareCorteWhatsApp(
                      siniestros: siniestros,
                      periodoLabel: filter.dateRange.label,
                    ),
            icon: const Icon(Icons.share_rounded, color: AppColors.whatsappGreen),
            label: const Text('Compartir Resumen por WhatsApp'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
