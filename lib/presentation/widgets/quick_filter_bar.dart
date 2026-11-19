import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/siniestro_model.dart';
import '../providers/siniestro_provider.dart';

/// Barra de filtros rápidos de búsqueda y chips de estatus operativo
class QuickFilterBar extends ConsumerWidget {
  const QuickFilterBar({super.key});

  Widget _buildChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    Color? dotColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textColor = isSelected
        ? Colors.white
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);

    return ChoiceChip(
      avatar: dotColor != null
          ? CircleAvatar(
              backgroundColor: dotColor,
              radius: 5,
            )
          : null,
      label: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          fontSize: 13,
        ),
      ),
      labelStyle: TextStyle(
        color: textColor,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        fontSize: 13,
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      side: BorderSide(
        color: isSelected
            ? AppColors.primary
            : (isDark ? AppColors.borderDark : AppColors.borderLight),
        width: isSelected ? 1.5 : 1.0,
      ),
      onSelected: (_) => onSelected(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(siniestroFilterProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Campo de Búsqueda Rápida
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
          child: TextField(
            onChanged: (query) {
              ref.read(siniestroFilterProvider.notifier).state =
                  filterState.copyWith(searchQuery: query);
            },
            decoration: InputDecoration(
              hintText: 'Buscar folio, asegurado, placa, ajustador...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: filterState.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
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
              _buildChip(
                context: context,
                label: 'Todos',
                isSelected: filterState.status == null,
                onSelected: () {
                  ref.read(siniestroFilterProvider.notifier).state =
                      filterState.copyWith(status: () => null);
                },
              ),
              const SizedBox(width: 8),
              _buildChip(
                context: context,
                label: 'Asignados',
                dotColor: AppColors.statusAsignado,
                isSelected: filterState.status == SiniestroEstatus.asignado,
                onSelected: () {
                  ref.read(siniestroFilterProvider.notifier).state = filterState.copyWith(
                    status: () => filterState.status == SiniestroEstatus.asignado ? null : SiniestroEstatus.asignado,
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildChip(
                context: context,
                label: 'En Atención',
                dotColor: AppColors.statusEnAtencion,
                isSelected: filterState.status == SiniestroEstatus.enAtencion,
                onSelected: () {
                  ref.read(siniestroFilterProvider.notifier).state = filterState.copyWith(
                    status: () => filterState.status == SiniestroEstatus.enAtencion ? null : SiniestroEstatus.enAtencion,
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildChip(
                context: context,
                label: 'Concluidos',
                dotColor: AppColors.statusConcluido,
                isSelected: filterState.status == SiniestroEstatus.concluido,
                onSelected: () {
                  ref.read(siniestroFilterProvider.notifier).state = filterState.copyWith(
                    status: () => filterState.status == SiniestroEstatus.concluido ? null : SiniestroEstatus.concluido,
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildChip(
                context: context,
                label: 'Cancelados',
                dotColor: AppColors.statusCancelado,
                isSelected: filterState.status == SiniestroEstatus.cancelado,
                onSelected: () {
                  ref.read(siniestroFilterProvider.notifier).state = filterState.copyWith(
                    status: () => filterState.status == SiniestroEstatus.cancelado ? null : SiniestroEstatus.cancelado,
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
