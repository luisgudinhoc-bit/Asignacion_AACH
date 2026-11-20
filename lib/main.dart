import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/licensing_service.dart';
import 'data/datasources/local_storage_service.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/screens/home_dashboard_screen.dart';
import 'presentation/screens/licencia_bloqueo_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fijar orientación vertical recomendada para operación ágil con una mano
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Inicialización de la base de datos local Hive (Offline-First)
  await LocalStorageService.init();

  runApp(
    const ProviderScope(
      child: AsignacionAACHApp(),
    ),
  );
}

/// Widget raíz de la aplicación móvil Asignación AACH con control estricto de acceso por hardware
class AsignacionAACHApp extends ConsumerStatefulWidget {
  const AsignacionAACHApp({super.key});

  @override
  ConsumerState<AsignacionAACHApp> createState() => _AsignacionAACHAppState();
}

class _AsignacionAACHAppState extends ConsumerState<AsignacionAACHApp> with WidgetsBindingObserver {
  final LicensingService _licensingService = LicensingService();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  EstadoLicencia? _estadoLicencia;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _validarLicenciaInicial();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _revalidarLicenciaEnSegundoPlano();
    }
  }

  /// Valida en vivo con Google Sheets al abrir la app
  Future<void> _validarLicenciaInicial() async {
    final estado = await _licensingService.verificarLicencia(forzarRefresco: true);
    if (mounted) {
      setState(() {
        _estadoLicencia = estado;
        _cargando = false;
      });
    }
  }

  /// Revalida en vivo cada vez que el usuario vuelve a poner la app en pantalla
  Future<void> _revalidarLicenciaEnSegundoPlano() async {
    final estado = await _licensingService.verificarLicencia(forzarRefresco: true);
    if (!mounted) return;

    if (!estado.autorizada && _estadoLicencia?.autorizada == true) {
      // Dispositivo fue bloqueado o removido en Google Sheets mientras la app estaba en uso
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      setState(() {
        _estadoLicencia = estado;
      });
    } else if (estado.autorizada && _estadoLicencia?.autorizada != true) {
      // Dispositivo fue activado en Google Sheets
      setState(() {
        _estadoLicencia = estado;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: _cargando
          ? const Scaffold(
              backgroundColor: Color(0xFF0F172A),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primaryLight),
                    SizedBox(height: 16),
                    Text(
                      'Verificando licencia de dispositivo...',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          : (_estadoLicencia?.autorizada == true
              ? const HomeDashboardScreen()
              : LicenciaBloqueoScreen(
                  estado: _estadoLicencia!,
                  onLicenciaAprobada: (nuevoEstado) {
                    setState(() {
                      _estadoLicencia = nuevoEstado;
                    });
                  },
                )),
    );
  }
}
