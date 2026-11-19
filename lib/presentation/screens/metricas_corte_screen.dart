import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/export_service.dart';
import '../../core/theme/app_colors.dart';
import '../../data/datasources/local_storage_service.dart';
import '../../domain/models/siniestro_metrics.dart';
import '../../domain/models/siniestro_model.dart';
import '../providers/ajustador_provider.dart';
import '../providers/aseguradora_provider.dart';
import '../providers/auth_provider.dart';
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
                        final textColor = isSelected
                            ? Colors.white
                            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: Text(
                              range.label,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            labelStyle: TextStyle(
                              color: textColor,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              fontSize: 13,
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

          // 5. Botón Principal: Cerrar y Congelar Corte en Excel
          ElevatedButton.icon(
            onPressed: () => _showCerrarCorteDialog(
              context,
              ref,
              filter,
              metrics,
              siniestros,
            ),
            icon: const Icon(Icons.lock_clock_rounded, size: 20),
            label: const Text(
              'Cerrar Corte de Turno / Quincena',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),

          // 6. Botones Secundarios: WhatsApp y Drive
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: siniestros.isEmpty
                      ? null
                      : () => ExportService.shareCorteWhatsApp(
                            siniestros: siniestros,
                            periodoLabel: filter.dateRange.label,
                          ),
                  icon: const Icon(Icons.share_rounded, color: AppColors.whatsappGreen, size: 18),
                  label: const Text('WhatsApp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
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
                          content: Text('⚠️ Configura primero el enlace en "Ajustes".'),
                          backgroundColor: AppColors.statusAsignado,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.table_chart_rounded, size: 18),
                  label: const Text('Ver en Drive', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showCerrarCorteDialog(
    BuildContext context,
    WidgetRef ref,
    MetricsFilterState filter,
    SiniestroMetrics metrics,
    List<SiniestroModel> siniestros,
  ) {
    final obsController = TextEditingController();
    bool isSaving = false;

    // Calcular desglose por ajustador
    final ajMap = <String, int>{};
    for (final s in siniestros) {
      if (s.ajustador.isNotEmpty) {
        ajMap[s.ajustador] = (ajMap[s.ajustador] ?? 0) + 1;
      }
    }
    final ajStr = ajMap.entries.map((e) => '${e.key}: ${e.value}').join(' | ');

    // Calcular desglose de cierres
    final cierresStr = metrics.desgloseCierres.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(' | ');

    final efectividadStr = metrics.total > 0
        ? '${((metrics.concluidos / metrics.total) * 100).toStringAsFixed(1)}%'
        : '0%';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.lock_clock_rounded, color: AppColors.primaryLight),
                  SizedBox(width: 8),
                  Text('Cerrar Corte', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Se registrará una fila congelada en la pestaña HISTORIAL_CORTES de tu Google Sheet.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Período:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(filter.dateRange.label, style: const TextStyle(fontSize: 12, color: AppColors.primaryLight, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Asignados:', style: TextStyle(fontSize: 12)),
                              Text('${metrics.total}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Concluidos:', style: TextStyle(fontSize: 12)),
                              Text('${metrics.concluidos} ($efectividadStr)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.statusConcluido)),
                            ],
                          ),
                          if (ajStr.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            const Text('Servicios por Ajustador:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            Text(ajStr, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: obsController,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones del Corte (opcional)',
                        hintText: 'Ej. Corte fin de quincena, turno matutino...',
                        prefixIcon: Icon(Icons.comment_outlined, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final sheetsService = ref.read(googleSheetsServiceProvider);
                          if (!sheetsService.isSignedIn) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('⚠️ Debe iniciar sesión con Google en "Ajustes" para congelar el corte en Sheets.'),
                                backgroundColor: AppColors.statusAsignado,
                              ),
                            );
                            return;
                          }

                          setState(() => isSaving = true);
                          try {
                            final spreadsheetId = LocalStorageService.getSpreadsheetId();
                            await sheetsService.appendCorteHistorico(
                              spreadsheetId,
                              periodo: filter.dateRange.label,
                              totalAsignados: metrics.total,
                              totalConcluidos: metrics.concluidos,
                              efectividad: efectividadStr,
                              serviciosPorAjustador: ajStr.isNotEmpty ? ajStr : 'Sin asignaciones',
                              tiempoPromArribo: metrics.tiempoPromedioArribo != null
                                  ? '${metrics.tiempoPromedioArribo!.inMinutes} min'
                                  : 'N/A',
                              duracionPromAtencion: metrics.tiempoPromedioConclusion != null
                                  ? '${metrics.tiempoPromedioConclusion!.inMinutes} min'
                                  : 'N/A',
                              desgloseCierres: cierresStr.isNotEmpty ? cierresStr : 'Sin cierres',
                              observaciones: obsController.text.trim(),
                            );

                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Corte congelado con éxito en la pestaña HISTORIAL_CORTES de tu Google Sheet.'),
                                  backgroundColor: AppColors.statusConcluido,
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() => isSaving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al congelar corte: $e'),
                                  backgroundColor: AppColors.statusCancelado,
                                ),
                              );
                            }
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Congelar en Excel'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
