import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/models/siniestro_model.dart';
import '../utils/date_formatter.dart';
import 'whatsapp_service.dart';

/// Servicio para exportación de datos a CSV y resúmenes para WhatsApp
class ExportService {
  /// Exporta la lista de siniestros a un archivo CSV y abre el menú del sistema para compartir
  static Future<void> exportSiniestrosToCsv(List<SiniestroModel> siniestros) async {
    final List<List<dynamic>> rows = [];

    // Encabezados
    rows.add([
      'ID',
      'Folio',
      'Aseguradora',
      'Ajustador',
      'Estatus',
      'Tipo de Evento',
      'Ubicación',
      'Link Maps',
      'Asegurado',
      'Teléfono',
      'Vehículo',
      'Color',
      'Placas',
      'Póliza',
      'Fecha Asignación',
      'Hora Asignación',
      'Fecha Arribo',
      'Fecha Conclusión',
      'Tipo Cierre',
      'Observaciones',
      'Sincronizado',
    ]);

    // Filas de datos
    for (final s in siniestros) {
      rows.add([
        s.id,
        s.folio,
        s.aseguradora,
        s.ajustador,
        s.estatus.displayName,
        s.tipoEvento,
        s.ubicacion,
        s.linkMaps,
        s.asegurado,
        s.telefonoAsegurado,
        s.vehiculo,
        s.colorVehiculo,
        s.placas,
        s.poliza,
        DateFormatter.formatDate(s.fechaAsignacion),
        DateFormatter.formatTime(s.fechaAsignacion),
        s.fechaArribo != null ? DateFormatter.formatFull(s.fechaArribo!) : '',
        s.fechaConclusion != null ? DateFormatter.formatFull(s.fechaConclusion!) : '',
        s.tipoCierre ?? '',
        s.observaciones,
        s.sincronizado ? 'SI' : 'PENDIENTE',
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final tempDir = await getTemporaryDirectory();
    final fileName =
        'Reporte_Siniestros_AACH_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(csvString);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Reporte Operativo de Siniestros AACH - ${DateFormatter.formatDate(DateTime.now())}',
      subject: 'Reporte Operativo AACH',
    );
  }

  /// Genera y comparte el corte del día o período formateado para WhatsApp
  static Future<void> shareCorteWhatsApp({
    required List<SiniestroModel> siniestros,
    required String periodoLabel,
  }) async {
    final buffer = StringBuffer();
    final fechaHoy = DateFormatter.formatDate(DateTime.now());

    final total = siniestros.length;
    final concluidos = siniestros.where((s) => s.estatus == SiniestroEstatus.concluido).length;
    final enAtencion = siniestros.where((s) => s.estatus == SiniestroEstatus.enAtencion).length;
    final asignados = siniestros.where((s) => s.estatus == SiniestroEstatus.asignado).length;
    final cancelados = siniestros.where((s) => s.estatus == SiniestroEstatus.cancelado).length;

    buffer.writeln('📊 *RESUMEN OPERATIVO - AACH* 📊');
    buffer.writeln('📅 *Período:* $periodoLabel ($fechaHoy)');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📈 *Total de Siniestros:* $total');
    buffer.writeln('🟢 *Concluidos:* $concluidos');
    buffer.writeln('🔵 *En Atención / Arribo:* $enAtencion');
    buffer.writeln('🟡 *Asignados (Pendientes):* $asignados');
    buffer.writeln('🔴 *Cancelados / Falsos:* $cancelados');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Desglose de Cierres
    final Map<String, int> cierresMap = {};
    for (final s in siniestros.where((s) => s.estatus == SiniestroEstatus.concluido)) {
      final tipo = s.tipoCierre?.trim().isNotEmpty == true ? s.tipoCierre! : 'Sin Detalle';
      cierresMap[tipo] = (cierresMap[tipo] ?? 0) + 1;
    }

    if (cierresMap.isNotEmpty) {
      buffer.writeln('📋 *Desglose de Cierres:*');
      cierresMap.forEach((cierre, count) {
        buffer.writeln('  • $cierre: $count');
      });
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }

    // Desglose por Ajustador
    final Map<String, int> ajustadoresMap = {};
    for (final s in siniestros) {
      final nombre = s.ajustador.trim().isNotEmpty ? s.ajustador : 'Sin Asignar';
      ajustadoresMap[nombre] = (ajustadoresMap[nombre] ?? 0) + 1;
    }

    if (ajustadoresMap.isNotEmpty) {
      buffer.writeln('👤 *Productividad por Ajustador:*');
      ajustadoresMap.forEach((ajustador, count) {
        buffer.writeln('  • $ajustador: $count siniestros');
      });
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }

    buffer.writeln('🚀 *AACH Ajustadores Asociados - Control Operativo*');

    await WhatsAppService.shareToWhatsAppGeneric(buffer.toString());
  }
}
