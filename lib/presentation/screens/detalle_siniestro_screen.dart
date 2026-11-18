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

/// Pantalla de detalle operativo integral de un siniestro
class DetalleSiniestroScreen extends ConsumerWidget {
  final String siniestroId;

  const DetalleSiniestroScreen({
    super.key,
    required this.siniestroId,
  });

  void _showCierreDialog(BuildContext context, WidgetRef ref, SiniestroModel siniestro) {
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
                const Text(
                  'Seleccionar Tipo de Cierre',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...AppConstants.tiposCierre.map((tipo) {
                  return ListTile(
                    leading: const Icon(Icons.check_circle_outline, color: AppColors.statusConcluido),
                    title: Text(tipo),
                    onTap: () {
                      ref.read(siniestroListProvider.notifier).updateEstatus(
                            siniestro.id,
                            SiniestroEstatus.concluido,
                            tipoCierre: tipo,
                          );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Siniestro concluido con: $tipo'),
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

  Future<void> _resendWhatsApp(BuildContext context, WidgetRef ref, SiniestroModel siniestro) async {
    final ajustadores = ref.read(ajustadoresProvider);
    final ajMatch = ajustadores.firstWhere(
      (a) => a.nombre.toLowerCase() == siniestro.ajustador.toLowerCase(),
      orElse: () => ajustadores.first,
    );

    final msg = WhatsAppService.buildAsignacionMessage(
      folio: siniestro.folio,
      aseguradora: siniestro.aseguradora,
      ajustador: siniestro.ajustador,
      tipoEvento: siniestro.tipoEvento,
      vehiculo: siniestro.vehiculo,
      placas: siniestro.placas,
      asegurado: siniestro.asegurado,
      telefonoAsegurado: siniestro.telefonoAsegurado,
      ubicacion: siniestro.ubicacion,
      linkMaps: siniestro.linkMaps,
      observaciones: siniestro.observaciones,
      fechaHora: siniestro.fechaAsignacion,
    );

    await WhatsAppService.sendWhatsAppMessage(
      phone: ajMatch.telefonoWhatsApp,
      message: msg,
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Siniestro?'),
        content: const Text(
          'Esta acción eliminará el registro de la base local y encolará la remoción en Google Sheets.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusCancelado),
            onPressed: () {
              ref.read(siniestroListProvider.notifier).deleteSiniestro(siniestroId);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final siniestros = ref.watch(siniestroListProvider);
    final siniestro = siniestros.firstWhere(
      (s) => s.id == siniestroId,
      orElse: () => SiniestroModel(folio: '', aseguradora: '', ajustador: ''),
    );

    if (siniestro.folio.isEmpty && siniestro.id != siniestroId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle de Siniestro')),
        body: const Center(child: Text('Siniestro no encontrado o fue eliminado.')),
      );
    }

    final ciaColor = AppColors.getAseguradoraColor(siniestro.aseguradora);

    return Scaffold(
      appBar: AppBar(
        title: Text('Folio: ${siniestro.folio}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Compartir Ficha',
            onPressed: () => _resendWhatsApp(context, ref, siniestro),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            tooltip: 'Eliminar Siniestro',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Banner de Estatus y Cambio Rápido
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ciaColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ciaColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      siniestro.aseguradora,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ciaColor,
                      ),
                    ),
                    Chip(
                      label: Text(
                        siniestro.estatus.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      backgroundColor: Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Asignado a: ${siniestro.ajustador} • ${DateFormatter.formatDate(siniestro.fechaAsignacion)} ${DateFormatter.formatTime(siniestro.fechaAsignacion)} hrs',
                  style: const TextStyle(fontSize: 13),
                ),
                if (siniestro.tipoCierre != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Cierre registrado: ${siniestro.tipoCierre}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.statusConcluido,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (siniestro.estatus != SiniestroEstatus.enAtencion)
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.read(siniestroListProvider.notifier).updateEstatus(
                                siniestro.id,
                                SiniestroEstatus.enAtencion,
                              );
                        },
                        icon: const Icon(Icons.near_me_rounded, size: 16),
                        label: const Text('Marcar Arribo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.statusEnAtencion,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    if (siniestro.estatus != SiniestroEstatus.concluido)
                      ElevatedButton.icon(
                        onPressed: () => _showCierreDialog(context, ref, siniestro),
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: const Text('Concluir Siniestro'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.statusConcluido,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    if (siniestro.estatus != SiniestroEstatus.cancelado)
                      OutlinedButton.icon(
                        onPressed: () {
                          ref.read(siniestroListProvider.notifier).updateEstatus(
                                siniestro.id,
                                SiniestroEstatus.cancelado,
                              );
                        },
                        icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                        label: const Text('Cancelar / Falso', style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tiempos Operativos
          _buildInfoCard(
            title: 'Tiempos de Atención',
            icon: Icons.timer_outlined,
            children: [
              _buildRow('Fecha de Asignación', DateFormatter.formatFull(siniestro.fechaAsignacion)),
              _buildRow(
                'Fecha de Arribo',
                siniestro.fechaArribo != null
                    ? DateFormatter.formatFull(siniestro.fechaArribo!)
                    : 'Pendiente de arribo',
              ),
              if (siniestro.fechaArribo != null)
                _buildRow(
                  'Tiempo de Respuesta al Sitio',
                  '${siniestro.fechaArribo!.difference(siniestro.fechaAsignacion).inMinutes} minutos',
                ),
              _buildRow(
                'Fecha de Conclusión',
                siniestro.fechaConclusion != null
                    ? DateFormatter.formatFull(siniestro.fechaConclusion!)
                    : 'En proceso',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Datos del Vehículo
          _buildInfoCard(
            title: 'Vehículo Asegurado',
            icon: Icons.directions_car_outlined,
            children: [
              _buildRow('Vehículo', siniestro.vehiculo.isNotEmpty ? siniestro.vehiculo : 'No especificado'),
              _buildRow('Color', siniestro.colorVehiculo.isNotEmpty ? siniestro.colorVehiculo : 'No especificado'),
              _buildRow('Placas', siniestro.placas.isNotEmpty ? siniestro.placas : 'Sin placas'),
              _buildRow('Póliza / Inciso', siniestro.poliza.isNotEmpty ? siniestro.poliza : 'No especificado'),
              _buildRow('Tipo de Evento', siniestro.tipoEvento),
            ],
          ),
          const SizedBox(height: 12),

          // Datos del Asegurado / Contacto
          _buildInfoCard(
            title: 'Asegurado / Reportante',
            icon: Icons.person_outline_rounded,
            children: [
              _buildRow('Nombre', siniestro.asegurado.isNotEmpty ? siniestro.asegurado : 'No especificado'),
              _buildRow('Teléfono', siniestro.telefonoAsegurado.isNotEmpty ? siniestro.telefonoAsegurado : 'Sin teléfono'),
              if (siniestro.telefonoAsegurado.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => launchUrl(Uri.parse('tel:${siniestro.telefonoAsegurado}')),
                      icon: const Icon(Icons.phone, size: 16),
                      label: const Text('Llamar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => WhatsAppService.sendWhatsAppMessage(
                        phone: siniestro.telefonoAsegurado,
                        message: 'Estimado ${siniestro.asegurado}, soy el ajustador de ${siniestro.aseguradora} asignado a su reporte ${siniestro.folio}. Me encuentro en camino.',
                      ),
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Text('WhatsApp'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.whatsappGreen),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Ubicación
          _buildInfoCard(
            title: 'Ubicación del Siniestro',
            icon: Icons.location_on_outlined,
            children: [
              _buildRow('Lugar', siniestro.ubicacion.isNotEmpty ? siniestro.ubicacion : 'No especificado'),
              if (siniestro.linkMaps.isNotEmpty) ...[
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(siniestro.linkMaps),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.map_rounded),
                  label: const Text('Abrir en Google Maps'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Observaciones de Cabina
          if (siniestro.observaciones.isNotEmpty)
            _buildInfoCard(
              title: 'Notas de Cabina',
              icon: Icons.notes_rounded,
              children: [
                Text(siniestro.observaciones, style: const TextStyle(fontSize: 13)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
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
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primaryLight),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const Divider(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
