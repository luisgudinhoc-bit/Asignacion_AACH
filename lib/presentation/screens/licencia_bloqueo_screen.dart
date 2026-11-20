import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../data/datasources/licensing_service.dart';

/// Pantalla de bloqueo estricto cuando un dispositivo no está dado de alta o fue desactivado en Google Sheets
class LicenciaBloqueoScreen extends StatefulWidget {
  final EstadoLicencia estado;
  final ValueChanged<EstadoLicencia> onLicenciaAprobada;

  const LicenciaBloqueoScreen({
    super.key,
    required this.estado,
    required this.onLicenciaAprobada,
  });

  @override
  State<LicenciaBloqueoScreen> createState() => _LicenciaBloqueoScreenState();
}

class _LicenciaBloqueoScreenState extends State<LicenciaBloqueoScreen> {
  bool _verificando = false;
  late EstadoLicencia _estadoActual;
  final LicensingService _licensingService = LicensingService();

  @override
  void initState() {
    super.initState();
    _estadoActual = widget.estado;
  }

  Future<void> _reintentar() async {
    setState(() => _verificando = true);
    final nuevoEstado = await _licensingService.verificarLicencia(forzarRefresco: true);
    if (!mounted) return;

    setState(() {
      _estadoActual = nuevoEstado;
      _verificando = false;
    });

    if (nuevoEstado.autorizada) {
      widget.onLicenciaAprobada(nuevoEstado);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nuevoEstado.estado == 'SIN CONEXIÓN'
                ? 'Sin conexión a internet. Conéctate a WiFi o datos para validar el acceso.'
                : 'Dispositivo no autorizado (${nuevoEstado.estado}). Contacta a Luis Gudiño.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent.shade700,
        ),
      );
    }
  }

  void _copiarId() {
    Clipboard.setData(ClipboardData(text: _estadoActual.deviceId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ID de dispositivo copiado al portapapeles.'),
        backgroundColor: AppColors.secondary,
      ),
    );
  }

  Future<void> _enviarWhatsAppALuis() async {
    final mensaje = _estadoActual.mensajeWhatsAppRenovacion;
    final telLimpio = _estadoActual.telefonoAdmin.replaceAll(RegExp(r'[^0-9]'), '');
    final encoded = Uri.encodeComponent(mensaje);
    final uri = Uri.parse('https://wa.me/$telLimpio?text=$encoded');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _copiarId();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool esBloqueado = _estadoActual.estado == 'BLOQUEADO' ||
        _estadoActual.estado == 'INACTIVO' ||
        _estadoActual.estado == 'SUSPENDIDO' ||
        _estadoActual.estado == 'BAJA';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Cabecera institucional
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_rounded, color: AppColors.primary, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        'Asignacion AACH',
                        style: TextStyle(
                          color: Colors.blueGrey.shade900,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Icono de Candado / Bloqueo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent, width: 2),
                  ),
                  child: Icon(
                    esBloqueado ? Icons.block_flipped : Icons.lock_person_rounded,
                    size: 42,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 20),

                // Título
                Text(
                  esBloqueado ? 'ACCESO SUSPENDIDO / BLOQUEADO' : 'DISPOSITIVO NO AUTORIZADO',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),

                // Estado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    'ESTADO: ${_estadoActual.estado}',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Explicación
                Text(
                  _estadoActual.motivoBloqueo.isNotEmpty
                      ? _estadoActual.motivoBloqueo
                      : 'Este dispositivo no se encuentra activado en el control de licencias de Luis Gudiño.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),

                // Tarjeta de Hardware ID (Placa)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ID DE DISPOSITIVO (PLACA):',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          InkWell(
                            onTap: _copiarId,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.copy_rounded, color: Colors.amberAccent, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Copiar',
                                    style: TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _estadoActual.deviceId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(color: Color(0xFF334155), height: 18),
                      Row(
                        children: [
                          const Icon(Icons.smartphone_rounded, color: Colors.white54, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _estadoActual.nombreDispositivo,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Botón Enviar WhatsApp
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    label: const Text(
                      'Enviar ID a Luis Gudiño por WhatsApp',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.whatsappGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    onPressed: _enviarWhatsAppALuis,
                  ),
                ),
                const SizedBox(height: 12),

                // Botón Verificar Activación
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: _verificando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                    label: Text(
                      _verificando ? 'Consultando Google Sheets...' : 'Verificar Activación',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _verificando ? null : _reintentar,
                  ),
                ),
                const SizedBox(height: 16),

                // Nota informativa
                Text(
                  'El administrador puede activar o desactivar este equipo en cualquier momento desde Google Sheets en tiempo real.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.blueGrey.shade400,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
