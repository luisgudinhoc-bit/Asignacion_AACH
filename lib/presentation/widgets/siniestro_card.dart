import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/whatsapp_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/models/siniestro_model.dart';
import '../providers/ajustador_provider.dart';
import '../providers/siniestro_provider.dart';
import '../screens/asignacion_rapida_screen.dart';
import '../screens/detalle_siniestro_screen.dart';

/// Tarjeta operativa para visualización rápida y acciones en un toque en el tablero
class SiniestroCard extends ConsumerWidget {
  final SiniestroModel siniestro;

  const SiniestroCard({
    super.key,
    required this.siniestro,
  });

  Color _getStatusColor(SiniestroEstatus estatus) {
    switch (estatus) {
      case SiniestroEstatus.asignado:
        return AppColors.statusAsignado;
      case SiniestroEstatus.enAtencion:
        return AppColors.statusEnAtencion;
      case SiniestroEstatus.concluido:
        return AppColors.statusConcluido;
      case SiniestroEstatus.cancelado:
        return AppColors.statusCancelado;
    }
  }

  void _showCierreBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tipo de Conclusión / Cierre',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text(
                  'Folio: ${siniestro.folio} • ${siniestro.aseguradora}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                ...AppConstants.tiposCierre.map((tipo) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle_outline, color: AppColors.statusConcluido),
                    title: Text(tipo, style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      ref.read(siniestroListProvider.notifier).updateEstatus(
                            siniestro.id,
                            SiniestroEstatus.concluido,
                            tipoCierre: tipo,
                          );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Siniestro concluido ($tipo).'),
                          backgroundColor: AppColors.statusConcluido,
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _resendWhatsApp(BuildContext context, WidgetRef ref) async {
    final ajustadores = ref.read(ajustadoresProvider);
    final ajMatch = ajustadores.where(
      (a) =>
          a.nombre.toLowerCase() == siniestro.ajustador.toLowerCase() ||
          siniestro.ajustador.toLowerCase().contains(a.nombre.toLowerCase()),
    ).firstOrNull;

    final msg = WhatsAppService.buildAsignacionMessage(
      folio: siniestro.folio,
      aseguradora: siniestro.aseguradora,
      ajustador: siniestro.ajustador,
      tipoEvento: siniestro.tipoEvento,
      vehiculo: siniestro.vehiculo,
      placas: siniestro.placas,
      asegurado: siniestro.asegurado,
      telefonoAsegurado: siniestro.telefonoAsegurado,
      ubicacion: siniestro.direccionCompleta,
      linkMaps: siniestro.linkMaps,
      observaciones: siniestro.observaciones,
      fechaHora: siniestro.fechaAsignacion,
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Reenviar Ficha Operativa',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text(
                  'Folio: ${siniestro.folio} • ${siniestro.aseguradora}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                if (ajMatch != null && ajMatch.telefonoWhatsApp.isNotEmpty)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(Icons.person, color: AppColors.whatsappGreen),
                    ),
                    title: Text('Enviar directo a ${ajMatch.nombre}'),
                    subtitle: Text(ajMatch.telefonoWhatsApp),
                    onTap: () {
                      Navigator.pop(ctx);
                      WhatsAppService.sendWhatsAppMessage(
                        phone: ajMatch.telefonoWhatsApp,
                        message: msg,
                      );
                    },
                  ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0F2F1),
                    child: Icon(Icons.groups_rounded, color: Color(0xFF128C7E)),
                  ),
                  title: const Text('Enviar a Grupo de WhatsApp'),
                  subtitle: const Text('Abre el selector de chats y grupos'),
                  onTap: () {
                    Navigator.pop(ctx);
                    WhatsAppService.shareToWhatsAppGeneric(msg);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _getStatusColor(siniestro.estatus);
    final ciaColor = AppColors.getAseguradoraColor(siniestro.aseguradora);

    // Alerta de tiempo transcurrido (ej: > 45 min en asignado)
    final isOverdue = siniestro.estatus == SiniestroEstatus.asignado &&
        DateFormatter.isTimeAlert(siniestro.fechaAsignacion, 45);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOverdue
              ? AppColors.accent
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
          width: isOverdue ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DetalleSiniestroScreen(siniestroId: siniestro.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado: Aseguradora, Folio, Estatus y Tiempo
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ciaColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: ciaColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      siniestro.aseguradora,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: ciaColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      siniestro.folio.isNotEmpty ? siniestro.folio : 'SIN FOLIO',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          siniestro.estatus.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Tiempo transcurrido e indicador de sincronización
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: isOverdue ? AppColors.accent : theme.hintColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormatter.timeElapsed(siniestro.fechaAsignacion),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isOverdue ? FontWeight.bold : FontWeight.w500,
                      color: isOverdue ? AppColors.accent : theme.hintColor,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    siniestro.sincronizado ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded,
                    size: 15,
                    color: siniestro.sincronizado
                        ? AppColors.statusConcluido
                        : AppColors.statusAsignado,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    siniestro.sincronizado ? 'Sheets' : 'Local',
                    style: TextStyle(
                      fontSize: 11,
                      color: siniestro.sincronizado
                          ? AppColors.statusConcluido
                          : AppColors.statusAsignado,
                    ),
                  ),
                ],
              ),
              const Divider(height: 18),

              // Cuerpo: Ajustador, Tipo Evento, Auto y Placas
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                    child: Text(
                      siniestro.ajustador.isNotEmpty ? siniestro.ajustador[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    siniestro.ajustador.isNotEmpty ? siniestro.ajustador : 'Sin Asignar',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      siniestro.tipoEvento,
                      style: TextStyle(fontSize: 11, color: theme.textTheme.bodyMedium?.color),
                    ),
                  ),
                ],
              ),

              if (siniestro.vehiculo.isNotEmpty || siniestro.placas.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.directions_car_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${siniestro.vehiculo} ${siniestro.colorVehiculo.isNotEmpty ? "• ${siniestro.colorVehiculo}" : ""}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (siniestro.placas.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          siniestro.placas,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              if (siniestro.ubicacion.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        siniestro.ubicacion,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              if (siniestro.tipoCierre != null && siniestro.tipoCierre!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.statusConcluido.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Cierre: ${siniestro.tipoCierre}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.statusConcluido,
                    ),
                  ),
                ),
              ],

              // Acciones Rápidas
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (siniestro.telefonoAsegurado.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.phone_rounded, size: 18, color: AppColors.primaryLight),
                      tooltip: 'Llamar al Asegurado',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => launchUrl(Uri.parse('tel:${siniestro.telefonoAsegurado}')),
                    ),
                  if (siniestro.linkMaps.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.map_rounded, size: 18, color: Colors.redAccent),
                      tooltip: 'Abrir Google Maps',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => launchUrl(
                        Uri.parse(siniestro.linkMaps),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, size: 18, color: AppColors.whatsappGreen),
                    tooltip: 'Reenviar Ficha por WhatsApp',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _resendWhatsApp(context, ref),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryLight),
                    tooltip: 'Editar Siniestro',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AsignacionRapidaScreen(
                            isStandaloneScreen: true,
                            siniestroToEdit: siniestro,
                          ),
                        ),
                      );
                    },
                  ),
                  const Spacer(),

                  // Botón de Transición de Estado
                  if (siniestro.estatus == SiniestroEstatus.asignado)
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.read(siniestroListProvider.notifier).updateEstatus(
                              siniestro.id,
                              SiniestroEstatus.enAtencion,
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🔵 Estatus actualizado a: En Atención / Arribo'),
                            backgroundColor: AppColors.statusEnAtencion,
                          ),
                        );
                      },
                      icon: const Icon(Icons.near_me_rounded, size: 15),
                      label: const Text('Arribo', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusEnAtencion,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),

                  if (siniestro.estatus == SiniestroEstatus.enAtencion)
                    ElevatedButton.icon(
                      onPressed: () => _showCierreBottomSheet(context, ref),
                      icon: const Icon(Icons.check_circle_rounded, size: 15),
                      label: const Text('Concluir', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusConcluido,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
