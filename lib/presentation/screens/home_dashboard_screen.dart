import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../providers/siniestro_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/quick_filter_bar.dart';
import '../widgets/siniestro_card.dart';
import '../widgets/sync_indicator_badge.dart';
import 'asignacion_rapida_screen.dart';
import 'ajustes_screen.dart';
import 'metricas_corte_screen.dart';

/// Pantalla Principal con Tablero Operativo y Navegación
class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _TableroOperativoView(),
          AsignacionRapidaScreen(),
          MetricasCorteScreen(),
          AjustesScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          setState(() {
            _currentIndex = idx;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Tablero',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline_rounded),
            selectedIcon: Icon(Icons.add_circle_rounded),
            label: 'Asignar',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Corte',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}

/// Vista del Tablero Operativo de Siniestros
class _TableroOperativoView extends ConsumerWidget {
  const _TableroOperativoView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final siniestros = ref.watch(filteredSiniestrosProvider);
    final allSiniestros = ref.watch(siniestroListProvider);
    final theme = Theme.of(context);

    // Contadores rápidos para la barra superior
    final countAsignados = allSiniestros.where((s) => s.estatus.name == 'asignado').length;
    final countAtencion = allSiniestros.where((s) => s.estatus.name == 'enAtencion').length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Asignacion AACH',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              '${DateFormatter.formatDate(DateTime.now())} • $countAsignados asignados • $countAtencion en atención',
              style: TextStyle(fontSize: 11, color: theme.hintColor),
            ),
          ],
        ),
        actions: [
          const SyncIndicatorBadge(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Sincronizar ahora',
            onPressed: () {
              ref.read(syncManagerProvider).processQueue();
              ref.read(siniestroListProvider.notifier).loadSiniestros();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(siniestroListProvider.notifier).loadSiniestros();
          await ref.read(syncManagerProvider).processQueue();
        },
        child: Column(
          children: [
            const QuickFilterBar(),
            const SizedBox(height: 4),
            Expanded(
              child: siniestros.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.assignment_turned_in_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No hay siniestros en este criterio',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Usa la pestaña "Asignar" para capturar uno nuevo con mensaje de cabina.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.hintColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: siniestros.length,
                      padding: const EdgeInsets.only(bottom: 24, top: 4),
                      itemBuilder: (context, index) {
                        final item = siniestros[index];
                        return SiniestroCard(siniestro: item);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AsignacionRapidaScreen(isStandaloneScreen: true),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.bolt_rounded),
        label: const Text('Asignar'),
      ),
    );
  }
}
