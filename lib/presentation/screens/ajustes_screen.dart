import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/datasources/local_storage_service.dart';
import '../../domain/services/whatsapp_parser_service.dart';
import '../providers/ajustador_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

/// Pantalla de configuración del sistema, catálogo de ajustadores y vinculación de Sheets
class AjustesScreen extends ConsumerStatefulWidget {
  const AjustesScreen({super.key});

  @override
  ConsumerState<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends ConsumerState<AjustesScreen> {
  final _sheetIdController = TextEditingController();
  final _testParserController = TextEditingController();
  ParsedCabinaMessage? _testParserResult;
  bool _isTestingSheet = false;

  @override
  void initState() {
    super.initState();
    final savedId = LocalStorageService.getSpreadsheetId();
    if (savedId != null) {
      _sheetIdController.text = savedId;
    }
  }

  @override
  void dispose() {
    _sheetIdController.dispose();
    _testParserController.dispose();
    super.dispose();
  }

  Future<void> _saveSpreadsheetId() async {
    final id = _sheetIdController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese un ID de hoja válido.')),
      );
      return;
    }

    setState(() => _isTestingSheet = true);
    await LocalStorageService.setSpreadsheetId(id);

    try {
      final sheetsService = ref.read(googleSheetsServiceProvider);
      if (sheetsService.isSignedIn) {
        await sheetsService.ensureSheetTabsAndHeaders(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Pestañas SINIESTROS y AJUSTADORES verificadas con éxito en Google Sheets.'),
              backgroundColor: AppColors.statusConcluido,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ID guardado. Inicie sesión con Google para verificar la hoja.'),
              backgroundColor: AppColors.statusAsignado,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aviso al verificar hoja: $e'),
            backgroundColor: AppColors.statusCancelado,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTestingSheet = false);
    }
  }

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
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: telCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono WhatsApp (10 dígitos)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (nombreCtrl.text.trim().isNotEmpty && telCtrl.text.trim().isNotEmpty) {
                ref.read(ajustadoresProvider.notifier).addAjustador(
                      nombre: nombreCtrl.text.trim(),
                      telefonoWhatsApp: telCtrl.text.trim(),
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final ajustadores = ref.watch(ajustadoresProvider);
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
                            onPressed: () => ref.read(authProvider.notifier).signIn(),
                            icon: const Icon(Icons.login_rounded, size: 16),
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
                    'ID de la Hoja de Cálculo (Spreadsheet ID):',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _sheetIdController,
                    decoration: const InputDecoration(
                      hintText: '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms',
                      prefixIcon: Icon(Icons.table_chart_outlined),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Obténgalo de la URL de su hoja: https://docs.google.com/spreadsheets/d/<ID>/edit',
                    style: TextStyle(fontSize: 11, color: theme.hintColor),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isTestingSheet ? null : _saveSpreadsheetId,
                      icon: _isTestingSheet
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_rounded, size: 16),
                      label: const Text('Guardar e Inicializar Pestañas'),
                    ),
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
              _buildSectionHeader('3. Catálogo de Ajustadores'),
              TextButton.icon(
                onPressed: _showAddAjustadorDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Agregar'),
              ),
            ],
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            child: Column(
              children: ajustadores.map((aj) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: aj.activo
                        ? AppColors.primaryLight.withValues(alpha: 0.2)
                        : Colors.grey.shade300,
                    child: Text(
                      aj.nombre[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: aj.activo ? AppColors.primaryLight : Colors.grey,
                      ),
                    ),
                  ),
                  title: Text(aj.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('WhatsApp: ${aj.telefonoWhatsApp}'),
                  trailing: Switch(
                    value: aj.activo,
                    activeThumbColor: AppColors.statusConcluido,
                    onChanged: (_) => ref.read(ajustadoresProvider.notifier).toggleActivo(aj.id),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Laboratorio de Pruebas: Parser Inteligente de Cabina
          _buildSectionHeader('4. Laboratorio del Parser WhatsApp'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Pruebe cómo extrae los campos de cualquier mensaje de cabina en tiempo real:',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _testParserController,
                    maxLines: 3,
                    onChanged: (text) {
                      setState(() {
                        _testParserResult = WhatsAppParserService.parse(text);
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Pegue aquí un mensaje de prueba (Quálitas, GNP, Inbursa, etc.)...',
                    ),
                  ),
                  if (_testParserResult != null && _testParserResult!.hasContent) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• Folio: ${_testParserResult?.folio ?? "--"}'),
                          Text('• Aseguradora: ${_testParserResult?.aseguradora ?? "--"}'),
                          Text('• Asegurado: ${_testParserResult?.asegurado ?? "--"}'),
                          Text('• Teléfono: ${_testParserResult?.telefonoAsegurado ?? "--"}'),
                          Text('• Auto / Placas: ${_testParserResult?.vehiculo ?? "--"} [${_testParserResult?.placas ?? "--"}]'),
                          Text('• Color: ${_testParserResult?.colorVehiculo ?? "--"}'),
                          Text('• Ubicación: ${_testParserResult?.ubicacion ?? "--"}'),
                          Text('• Link Maps: ${_testParserResult?.linkMaps ?? "--"}'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
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
