import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/local_storage_service.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/screens/home_dashboard_screen.dart';

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

/// Widget raíz de la aplicación móvil Asignación AACH
class AsignacionAACHApp extends ConsumerWidget {
  const AsignacionAACHApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const HomeDashboardScreen(),
    );
  }
}
