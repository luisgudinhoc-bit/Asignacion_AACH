import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/datasources/licensing_service.dart';
import '../../data/datasources/local_storage_service.dart';
import '../../domain/models/ajustador_model.dart';
import '../../domain/models/aseguradora_model.dart';
import '../providers/ajustador_provider.dart';
import '../providers/aseguradora_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

/// Pantalla de configuración del sistema, catálogo de ajustadores, aseguradoras y vinculación de Sheets
class AjustesScreen extends ConsumerStatefulWidget {
  const AjustesScreen({super.key});

  @override
  ConsumerState<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends ConsumerState<AjustesScreen> {
  final _sheetIdController = TextEditingController();
  bool _isTestingSheet = false;
  bool _isSyncingAjustadores = false;
  bool _isSyncingAseguradoras = false;
  EstadoLicencia? _licenciaActual;
  bool _isValidatingLicencia = false;

  @override
  void initState() {
    super.initState();
    _licenciaActual = LicensingService().estadoActual;
    _cargarLicenciaAsync();
    final savedId = LocalStorageService.getSpreadsheetId();
    if (savedId.isNotEmpty) {
      _sheetIdController.text = savedId;
    }
  }

  Future<void> _cargarLicenciaAsync() async {
    final lic = await LicensingService().verificarLicencia(forzarRefresco: false);
    if (mounted) setState(() => _licenciaActual = lic);
  }

  Future<void> _revalidarLicenciaManual() async {
    setState(() => _isValidatingLicencia = true);
    final lic = await LicensingService().verificarLicencia(forzarRefresco: true);
    if (mounted) {
      setState(() {
        _licenciaActual = lic;
        _isValidatingLicencia = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lic.autorizada
              ? 'Licencia activa confirmada en Google Sheets (${lic.titular}).'
              : 'Estado de dispositivo: ${lic.estado}.'),
          backgroundColor: lic.autorizada ? AppColors.secondary : Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _sheetIdController.dispose();
    super.dispose();
  }

  Future<void> _saveSpreadsheetId() async {
    final rawInput = _sheetIdController.text.trim();
    if (rawInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese un ID o enlace de hoja válido.')),
      );
      return;
    }

    setState(() => _isTestingSheet = true);
    final cleanId = LocalStorageService.sanitizeSpreadsheetId(rawInput);
    _sheetIdController.text = cleanId;
    await LocalStorageService.setSpreadsheetId(cleanId);

    try {
      final sheetsService = ref.read(googleSheetsServiceProvider);
      if (sheetsService.isSignedIn) {
        await sheetsService.ensureSheetTabsAndHeaders(cleanId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Pestañas SINIESTROS, AJUSTADORES y CATALOGO_ASEGURADORAS verificadas en Google Sheets.'),
              backgroundColor: AppColors.statusConcluido,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Enlace/ID guardado correctamente.'),
              backgroundColor: AppColors.statusConcluido,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ID guardado. Aviso al verificar hoja: $e'),
            backgroundColor: AppColors.statusAsignado,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTestingSheet = false);
    }
  }

  Future<void> _openSpreadsheetInDrive() async {
    final url = LocalStorageService.getSpreadsheetUrl();
    if (url != null) {
      final uri = Uri.parse(url);
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo abrir el enlace: $e')),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Ingrese y guarde primero la URL o ID de su hoja de cálculo.'),
          backgroundColor: AppColors.statusAsignado,
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final authNotifier = ref.read(authProvider.notifier);
    final success = await authNotifier.signIn();
    if (!success && mounted) {
      final error = ref.read(authProvider).error;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primaryLight),
              SizedBox(width: 8),
              Text('Cuenta de Google', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'No se pudo conectar con Google en este momento.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (error != null) ...[
                Text(
                  'Detalle:\n$error',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.blueGrey),
                ),
                const SizedBox(height: 10),
              ],
              const Text(
                'Recomendaciones:\n'
                '• En Android: Revisa que en Google Cloud Console tengas agregada la huella SHA-1 de tu APK y el paquete "com.aach.asignacionsiniestros".\n'
                '• En Web (localhost:8080): Agrega http://localhost:8080 en los "Orígenes de JavaScript autorizados" de tu ID de cliente web.\n'
                '• En la pantalla de consentimiento OAuth, agrega tu correo como usuario de prueba.\n\n'
                '💡 Recuerda: Puedes abrir y consultar tu hoja directamente con el botón "Abrir en Drive" sin necesidad de inicio de sesión.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }

  // ==================== SINCRONIZACIÓN AJUSTADORES ====================

  Future<void> _syncAjustadoresWithSheets() async {
    final spreadsheetId = LocalStorageService.getSpreadsheetId();
    if (spreadsheetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Configure y guarde primero la URL o ID de su hoja de cálculo.'),
          backgroundColor: AppColors.statusAsignado,
        ),
      );
      return;
    }

    final sheetsService = ref.read(googleSheetsServiceProvider);
    if (!sheetsService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Inicie sesión con Google para sincronizar los ajustadores.'),
          backgroundColor: AppColors.statusAsignado,
        ),
      );
      return;
    }

    setState(() => _isSyncingAjustadores = true);
    try {
      await ref.read(ajustadoresProvider.notifier).syncWithGoogleSheets(sheetsService, spreadsheetId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Catálogo de ajustadores sincronizado exitosamente con Google Sheets.'),
            backgroundColor: AppColors.statusConcluido,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al sincronizar ajustadores: $e'),
            backgroundColor: AppColors.statusCancelado,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingAjustadores = false);
    }
  }

  // ==================== SINCRONIZACIÓN ASEGURADORAS ====================

  Future<void> _syncAseguradorasWithSheets() async {
    final spreadsheetId = LocalStorageService.getSpreadsheetId();
    if (spreadsheetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Configure y guarde primero la URL o ID de su hoja de cálculo.'),
          backgroundColor: AppColors.statusAsignado,
        ),
      );
      return;
    }

    final sheetsService = ref.read(googleSheetsServiceProvider);
    if (!sheetsService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Inicie sesión con Google para sincronizar el catálogo de aseguradoras.'),
          backgroundColor: AppColors.statusAsignado,
        ),
      );
      return;
    }

    setState(() => _isSyncingAseguradoras = true);
    try {
      await ref.read(aseguradorasProvider.notifier).syncWithGoogleSheets(sheetsService, spreadsheetId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Catálogo de aseguradoras sincronizado exitosamente con Google Sheets.'),
            backgroundColor: AppColors.statusConcluido,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al sincronizar aseguradoras: $e'),
            backgroundColor: AppColors.statusCancelado,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingAseguradoras = false);
    }
  }

  // ==================== DIÁLOGOS DE AJUSTADORES ====================

  void _showAddAjustadorDialog() {
    final nombreCtrl = TextEditingController();
    final telCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar Ajustador'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre Completo',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: telCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono WhatsApp (10 dígitos)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton.icon(
            icon: const Icon(Icons.save_rounded, size: 16),
            onPressed: () {
              if (nombreCtrl.text.trim().isNotEmpty && telCtrl.text.trim().isNotEmpty) {
                final sheetsService = ref.read(googleSheetsServiceProvider);
                final spreadsheetId = LocalStorageService.getSpreadsheetId();
                ref.read(ajustadoresProvider.notifier).addAjustador(
                      nombre: nombreCtrl.text.trim(),
                      telefonoWhatsApp: telCtrl.text.trim(),
                      sheetsService: sheetsService,
                      spreadsheetId: spreadsheetId,
                    );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ajustador ${nombreCtrl.text.trim()} agregado.'),
                    backgroundColor: AppColors.statusConcluido,
                  ),
                );
              }
            },
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showEditAjustadorDialog(AjustadorModel ajustador) {
    final nombreCtrl = TextEditingController(text: ajustador.nombre);
    final telCtrl = TextEditingController(text: ajustador.telefonoWhatsApp);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar Ajustador: ${ajustador.nombre}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre Completo',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: telCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono WhatsApp (10 dígitos)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 16),
            onPressed: () {
              if (nombreCtrl.text.trim().isNotEmpty && telCtrl.text.trim().isNotEmpty) {
                final sheetsService = ref.read(googleSheetsServiceProvider);
                final spreadsheetId = LocalStorageService.getSpreadsheetId();
                final actualizado = ajustador.copyWith(
                  nombre: nombreCtrl.text.trim(),
                  telefonoWhatsApp: telCtrl.text.trim(),
                );
                ref.read(ajustadoresProvider.notifier).updateAjustador(
                      actualizado,
                      sheetsService: sheetsService,
                      spreadsheetId: spreadsheetId,
                    );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ajustador ${actualizado.nombre} actualizado.'),
                    backgroundColor: AppColors.statusConcluido,
                  ),
                );
              }
            },
            label: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAjustador(AjustadorModel ajustador) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Ajustador?'),
        content: Text(
          'Se eliminará a "${ajustador.nombre}" del catálogo de ajustadores locales.\n\nEsta acción no afectará los siniestros ya registrados.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusCancelado),
            onPressed: () {
              final sheetsService = ref.read(googleSheetsServiceProvider);
              final spreadsheetId = LocalStorageService.getSpreadsheetId();
              ref.read(ajustadoresProvider.notifier).deleteAjustador(
                    ajustador.id,
                    sheetsService: sheetsService,
                    spreadsheetId: spreadsheetId,
                  );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ajustador ${ajustador.nombre} eliminado.'),
                  backgroundColor: AppColors.statusCancelado,
                ),
              );
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==================== DIÁLOGOS DE ASEGURADORAS ====================

  void _showAddAseguradoraDialog() {
    final nombreCtrl = TextEditingController();
    final prefijoCtrl = TextEditingController();
    final telCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar Aseguradora'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre Aseguradora (ej. Quálitas)',
                prefixIcon: Icon(Icons.business_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: prefijoCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Prefijo Habitual (ej. 04, INB, GNP)',
                prefixIcon: Icon(Icons.tag_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: telCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono Cabina de Emergencia',
                prefixIcon: Icon(Icons.phone_in_talk_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton.icon(
            icon: const Icon(Icons.save_rounded, size: 16),
            onPressed: () {
              if (nombreCtrl.text.trim().isNotEmpty) {
                final sheetsService = ref.read(googleSheetsServiceProvider);
                final spreadsheetId = LocalStorageService.getSpreadsheetId();
                ref.read(aseguradorasProvider.notifier).addAseguradora(
                      nombre: nombreCtrl.text.trim(),
                      prefijoHabitual: prefijoCtrl.text.trim(),
                      telefonoCabina: telCtrl.text.trim(),
                      sheetsService: sheetsService,
                      spreadsheetId: spreadsheetId,
                    );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Aseguradora ${nombreCtrl.text.trim()} agregada.'),
                    backgroundColor: AppColors.statusConcluido,
                  ),
                );
              }
            },
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showEditAseguradoraDialog(AseguradoraModel aseguradora) {
    final nombreCtrl = TextEditingController(text: aseguradora.nombre);
    final prefijoCtrl = TextEditingController(text: aseguradora.prefijoHabitual);
    final telCtrl = TextEditingController(text: aseguradora.telefonoCabina);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar Aseguradora: ${aseguradora.nombre}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre Aseguradora',
                prefixIcon: Icon(Icons.business_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: prefijoCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Prefijo Habitual',
                prefixIcon: Icon(Icons.tag_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: telCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono Cabina de Emergencia',
                prefixIcon: Icon(Icons.phone_in_talk_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 16),
            onPressed: () {
              if (nombreCtrl.text.trim().isNotEmpty) {
                final sheetsService = ref.read(googleSheetsServiceProvider);
                final spreadsheetId = LocalStorageService.getSpreadsheetId();
                final actualizada = AseguradoraModel(
                  nombre: nombreCtrl.text.trim(),
                  prefijoHabitual: prefijoCtrl.text.trim(),
                  telefonoCabina: telCtrl.text.trim(),
                );
                ref.read(aseguradorasProvider.notifier).updateAseguradora(
                      actualizada,
                      sheetsService: sheetsService,
                      spreadsheetId: spreadsheetId,
                    );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Aseguradora ${actualizada.nombre} actualizada.'),
                    backgroundColor: AppColors.statusConcluido,
                  ),
                );
              }
            },
            label: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAseguradora(AseguradoraModel aseguradora) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Aseguradora?'),
        content: Text(
          'Se eliminará a "${aseguradora.nombre}" del catálogo local.\n\nEsta acción no afectará los siniestros ya registrados.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusCancelado),
            onPressed: () {
              final sheetsService = ref.read(googleSheetsServiceProvider);
              final spreadsheetId = LocalStorageService.getSpreadsheetId();
              ref.read(aseguradorasProvider.notifier).deleteAseguradora(
                    aseguradora.nombre,
                    sheetsService: sheetsService,
                    spreadsheetId: spreadsheetId,
                  );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Aseguradora ${aseguradora.nombre} eliminada.'),
                  backgroundColor: AppColors.statusCancelado,
                ),
              );
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final ajustadores = ref.watch(ajustadoresProvider);
    final aseguradoras = ref.watch(aseguradorasProvider);
    final themeMode = ref.watch(themeProvider);
    final theme = Theme.of(context);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ajustes del Sistema',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 0. Control de Acceso y Licencia por Hardware ID
          _buildSectionHeader('0. Control de Acceso y Licencia (Hardware ID)'),
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
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: (_licenciaActual?.autorizada ?? false)
                            ? AppColors.secondary.withValues(alpha: 0.15)
                            : Colors.red.withValues(alpha: 0.15),
                        child: Icon(
                          (_licenciaActual?.autorizada ?? false)
                              ? Icons.verified_user_rounded
                              : Icons.gpp_bad_rounded,
                          color: (_licenciaActual?.autorizada ?? false)
                              ? AppColors.secondary
                              : Colors.redAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (_licenciaActual?.autorizada ?? false)
                                  ? 'Dispositivo Autorizado'
                                  : 'Acceso Restringido',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              'Estado: ${_licenciaActual?.estado ?? "Verificando..."} • ${_licenciaActual?.titular ?? ""}',
                              style: TextStyle(fontSize: 12, color: theme.hintColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'ID PLACA HARDWARE:',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                            ),
                            InkWell(
                              onTap: () {
                                if (_licenciaActual?.deviceId != null) {
                                  Clipboard.setData(ClipboardData(text: _licenciaActual!.deviceId));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('ID de dispositivo copiado al portapapeles.')),
                                  );
                                }
                              },
                              child: const Row(
                                children: [
                                  Icon(Icons.copy_rounded, size: 12, color: AppColors.primaryLight),
                                  SizedBox(width: 4),
                                  Text('Copiar ID', style: TextStyle(fontSize: 11, color: AppColors.primaryLight, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          _licenciaActual?.deviceId ?? 'Consultando ID...',
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isValidatingLicencia ? null : _revalidarLicenciaManual,
                          icon: _isValidatingLicencia
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.sync_rounded, size: 16),
                          label: const Text('Revalidar en Sheets', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(
                                'https://docs.google.com/spreadsheets/d/11iwmA57GhfX--GZCY9ZGOSjN8Ah2Syhpu44LZii8NSs');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('Hoja de Licencias', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 1. Vinculación Google OAuth 2.0
          _buildSectionHeader('1. Cuenta de Google (OAuth 2.0)'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: authState.isAuthenticated
                            ? AppColors.statusConcluido.withValues(alpha: 0.15)
                            : Colors.grey.shade200,
                        child: Icon(
                          authState.isAuthenticated
                              ? Icons.cloud_done_rounded
                              : Icons.cloud_off_rounded,
                          color: authState.isAuthenticated
                              ? AppColors.statusConcluido
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authState.isAuthenticated ? 'Conectado a Google' : 'No Conectado',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              authState.user?.email ?? 'Permite sincronizar con Google Sheets sin servidor.',
                              style: TextStyle(fontSize: 12, color: theme.hintColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: authState.isAuthenticated
                        ? OutlinedButton.icon(
                            onPressed: () => ref.read(authProvider.notifier).signOut(),
                            icon: const Icon(Icons.logout_rounded, size: 16),
                            label: const Text('Cerrar Sesión'),
                          )
                        : ElevatedButton.icon(
                            onPressed: authState.isLoading ? null : _handleGoogleSignIn,
                            icon: authState.isLoading
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.login_rounded, size: 16),
                            label: const Text('Iniciar Sesión con Google'),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Hoja Maestra de Google Sheets
          _buildSectionHeader('2. Hoja Maestra de Google Sheets'),
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
                    'ID o Enlace de la Hoja de Cálculo (Spreadsheet ID):',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _sheetIdController,
                    decoration: const InputDecoration(
                      hintText: 'Ej. 1mh_cS0wWdEYFhUn0lRergJc6UPVcMKAhymgasAr4e0w',
                      prefixIcon: Icon(Icons.table_chart_outlined),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Puedes pegar el ID o la URL completa de Google Sheets.',
                    style: TextStyle(fontSize: 11, color: theme.hintColor),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          onPressed: _isTestingSheet ? null : _saveSpreadsheetId,
                          icon: _isTestingSheet
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.save_rounded, size: 16),
                          label: const Text('Guardar Hoja'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: _openSpreadsheetInDrive,
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('Abrir en Drive'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Catálogo de Ajustadores Activos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('3. Catálogo de Ajustadores (${ajustadores.length})'),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _isSyncingAjustadores ? null : _syncAjustadoresWithSheets,
                    icon: _isSyncingAjustadores
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('Sincronizar', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _showAddAjustadorDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Agregar', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            child: ajustadores.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.people_outline, size: 40, color: Colors.grey),
                          const SizedBox(height: 8),
                          const Text('No hay ajustadores registrados.'),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _showAddAjustadorDialog,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Agregar Ajustador'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (int i = 0; i < ajustadores.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 64),
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: ajustadores[i].activo
                                ? AppColors.primaryLight.withValues(alpha: 0.15)
                                : Colors.grey.shade200,
                            child: Text(
                              ajustadores[i].nombre.isNotEmpty ? ajustadores[i].nombre[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: ajustadores[i].activo ? AppColors.primaryLight : Colors.grey,
                              ),
                            ),
                          ),
                          title: Text(
                            ajustadores[i].nombre,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: ajustadores[i].activo ? null : theme.disabledColor,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Icon(Icons.phone_iphone_rounded, size: 12, color: theme.hintColor),
                              const SizedBox(width: 4),
                              Text(
                                ajustadores[i].telefonoWhatsApp,
                                style: TextStyle(fontSize: 12, color: theme.hintColor),
                              ),
                              if (!ajustadores[i].activo) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Inactivo', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Editar',
                                onPressed: () => _showEditAjustadorDialog(ajustadores[i]),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.statusCancelado),
                                tooltip: 'Eliminar',
                                onPressed: () => _confirmDeleteAjustador(ajustadores[i]),
                              ),
                              Switch(
                                value: ajustadores[i].activo,
                                activeThumbColor: AppColors.statusConcluido,
                                onChanged: (_) {
                                  final sheetsService = ref.read(googleSheetsServiceProvider);
                                  final spreadsheetId = LocalStorageService.getSpreadsheetId();
                                  ref.read(ajustadoresProvider.notifier).toggleActivo(
                                        ajustadores[i].id,
                                        sheetsService: sheetsService,
                                        spreadsheetId: spreadsheetId,
                                      );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // 4. Catálogo de Aseguradoras
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('4. Catálogo de Aseguradoras (${aseguradoras.length})'),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _isSyncingAseguradoras ? null : _syncAseguradorasWithSheets,
                    icon: _isSyncingAseguradoras
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('Sincronizar', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _showAddAseguradoraDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Agregar', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            child: aseguradoras.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.business_outlined, size: 40, color: Colors.grey),
                          const SizedBox(height: 8),
                          const Text('No hay aseguradoras registradas.'),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _showAddAseguradoraDialog,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Agregar Aseguradora'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (int i = 0; i < aseguradoras.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 64),
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                            child: Text(
                              aseguradoras[i].nombre.isNotEmpty ? aseguradoras[i].nombre[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryLight,
                              ),
                            ),
                          ),
                          title: Text(
                            aseguradoras[i].nombre,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Row(
                            children: [
                              if (aseguradoras[i].prefijoHabitual.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    aseguradoras[i].prefijoHabitual,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryLight,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (aseguradoras[i].telefonoCabina.isNotEmpty) ...[
                                Icon(Icons.phone_outlined, size: 12, color: theme.hintColor),
                                const SizedBox(width: 4),
                                Text(
                                  aseguradoras[i].telefonoCabina,
                                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                                ),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Editar',
                                onPressed: () => _showEditAseguradoraDialog(aseguradoras[i]),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.statusCancelado),
                                tooltip: 'Eliminar',
                                onPressed: () => _confirmDeleteAseguradora(aseguradoras[i]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // 5. Tema y Apariencia
          _buildSectionHeader('5. Preferencias'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            child: SwitchListTile(
              secondary: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: AppColors.accent,
              ),
              title: const Text('Modo Oscuro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Optimizado para turnos nocturnos y ahorro de batería.'),
              value: isDark,
              onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
            ),
          ),
          const SizedBox(height: 24),

          // Información de Versión
          Center(
            child: Column(
              children: [
                const Text(
                  '${AppConstants.appName} v${AppConstants.appVersion}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'Despacho de Ajustadores Asociados AACH\nArquitectura Offline-First con Google Workspace',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: theme.hintColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryLight,
        ),
      ),
    );
  }
}
