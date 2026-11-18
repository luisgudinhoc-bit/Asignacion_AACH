import 'package:url_launcher/url_launcher.dart';
import '../utils/string_extensions.dart';

/// Servicio para generación de mensajes y apertura directa de WhatsApp
class WhatsAppService {
  /// Genera la Ficha Operativa Formateada para el Ajustador
  static String buildAsignacionMessage({
    required String folio,
    required String aseguradora,
    required String ajustador,
    required String tipoEvento,
    String? vehiculo,
    String? placas,
    String? asegurado,
    String? telefonoAsegurado,
    String? ubicacion,
    String? linkMaps,
    String? observaciones,
    DateTime? fechaHora,
  }) {
    final horaStr = fechaHora != null
        ? '${fechaHora.hour.toString().padLeft(2, '0')}:${fechaHora.minute.toString().padLeft(2, '0')} hrs (${fechaHora.day.toString().padLeft(2, '0')}/${fechaHora.month.toString().padLeft(2, '0')}/${fechaHora.year})'
        : 'Inmediata';

    final buffer = StringBuffer();
    buffer.writeln('🚨 *ASIGNACIÓN DE SINIESTRO - AACH* 🚨');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📋 *Folio / Siniestro:* $folio');
    buffer.writeln('🏢 *Aseguradora:* $aseguradora');
    buffer.writeln('👤 *Ajustador:* $ajustador');
    buffer.writeln('⚠️ *Tipo de Evento:* $tipoEvento');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (asegurado != null && asegurado.trim().isNotEmpty) {
      buffer.writeln('👤 *Asegurado / Conductor:* ${asegurado.trim()}');
    }
    if (telefonoAsegurado != null && telefonoAsegurado.trim().isNotEmpty) {
      buffer.writeln('📞 *Tel. Contacto:* ${telefonoAsegurado.trim()}');
    }
    if (vehiculo != null && vehiculo.trim().isNotEmpty) {
      buffer.writeln('🚘 *Vehículo:* ${vehiculo.trim()}');
    }
    if (placas != null && placas.trim().isNotEmpty) {
      buffer.writeln('🔢 *Placas:* ${placas.trim().toUpperCase()}');
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    if (ubicacion != null && ubicacion.trim().isNotEmpty) {
      buffer.writeln('📍 *Ubicación:* ${ubicacion.trim()}');
    }
    if (linkMaps != null && linkMaps.trim().isNotEmpty) {
      buffer.writeln('🗺️ *Google Maps:* ${linkMaps.trim()}');
    }
    if (observaciones != null && observaciones.trim().isNotEmpty) {
      buffer.writeln('📝 *Notas de Cabina:* ${observaciones.trim()}');
    }

    buffer.writeln('⏰ *Hora Asignación:* $horaStr');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('⚡ *Favor de confirmar de recibido y reportar arribo.*');

    return buffer.toString();
  }

  /// Envía un mensaje a WhatsApp a un número específico
  static Future<bool> sendWhatsAppMessage({
    required String phone,
    required String message,
  }) async {
    final cleanPhone = phone.toMexicanWhatsAppPhone();
    final encodedText = Uri.encodeComponent(message);

    // Intento 1: Esquema de WhatsApp nativo
    final nativeUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedText');
    if (await canLaunchUrl(nativeUri)) {
      return await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
    }

    // Intento 2: Enlace universal wa.me
    final webUri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedText');
    if (await canLaunchUrl(webUri)) {
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }

    return false;
  }

  /// Abre WhatsApp sin número predeterminado (selector de chat de WhatsApp)
  static Future<bool> shareToWhatsAppGeneric(String message) async {
    final encodedText = Uri.encodeComponent(message);
    final nativeUri = Uri.parse('whatsapp://send?text=$encodedText');
    if (await canLaunchUrl(nativeUri)) {
      return await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
    }

    final webUri = Uri.parse('https://api.whatsapp.com/send?text=$encodedText');
    if (await canLaunchUrl(webUri)) {
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }

    return false;
  }
}
