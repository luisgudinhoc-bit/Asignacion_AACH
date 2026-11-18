import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/siniestro_model.dart';
import '../providers/siniestro_provider.dart';

/// Barra de filtros rápidos de estatus y búsqueda para el tablero operativo
class QuickFilterBar extends ConsumerStatefulWidget {
  const QuickFilterBar({super.key});

  @override
  ConsumerState<QuickFilterBar> createState() => _QuickFilterBarState();
}

class _QuickFilterBarState extends ConsumerState<QuickFilterBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filterState = ref.watch(siniestroFilterProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Campo de Búsqueda Dinámica
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              ref.read(siniestroFilterProvider.notifier).state =
                  filterState.copyWith(searchQuery: val);
            },
            decoration: InputDecoration(
              hintText: 'Buscar folio, asegurado, placa, ajustador...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(siniestroFilterProvider.notifier).state =
                            filterState.copyWith(searchQuery: '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              filled: true,
              fillColor: isDark ? AppColors.surfaceDark : Colors.white,
            ),
          ),
        ),

        // Pestañas / Chips de Filtrado por Estatus
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Todos'),
                selected: filterState.status == null,
                onSelected: (selected) {
                  ref.read(siniestroFilterProvider.notifier).state =
                      filterState.copyWith(status: () => null);
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                avatar: const CircleAvatar(
                  backgroundColor: AppColors.statusAsignado,
                  radius: 5,
                ),
                label: const Text('Asignados'),
                selected: filterState.status == SiniestroEstatus.asignado,
                onSelected: (selected) {
                  ref.read(siniestroFilterProvider.notifier).state = filterState.copyWith(
                    status: () => selected ? SiniestroEstatus.asignado : null,
                  );
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                avatar: const CircleAvatar(
                  backgroundColor: AppColors.statusEnAtencion,
                  radius: 5,
                ),
                label: const Text('En Atención'),
                selected: filterState.status == SiniestroEstatus.enAtencion,
                onSelected: (selected) {
                  ref.read(siniestroFilterProvider.notifier).state = filterState.copyWith(
                    status: () => selected ? SiniestroEstatus.enAtencion : null,
                  );
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                avatar: const CircleAvatar(
                  backgroundColor: AppColors.statusConcluido,
                  radius: 5,
                ),
                label: const Text('Concluidos'),
                selected: filterState.status == SiniestroEstatus.concluido,
                onSelected: (selected) {
                  ref.read(siniestroFilterProvider.notifier).state = filterState.copyWith(
                    status: () => selected ? SiniestroEstatus.concluido : null,
                  );
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                avatar: const CircleAvatar(
                  backgroundColor: AppColors.statusCancelado,
                  radius: 5,
                ),
                label: const Text('Cancelados'),
                selected: filterState.status == SiniestroEstatus.cancelado,
                onSelected: (selected) {
                  ref.read(siniestroFilterProvider.notifier).state = filterState.copyWith(
                    status: () => selected ? SiniestroEstatus.cancelado : null,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
