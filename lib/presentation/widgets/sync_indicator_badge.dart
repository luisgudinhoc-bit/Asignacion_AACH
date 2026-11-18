import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/sync/sync_queue_manager.dart';
import '../providers/sync_provider.dart';
import '../screens/sync_status_screen.dart';

/// Indicador visual interactivo de estado de sincronización para el AppBar
class SyncIndicatorBadge extends ConsumerWidget {
  const SyncIndicatorBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncStateProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider);

    Color badgeColor;
    IconData icon;
    String label;

    switch (state) {
      case SyncState.synced:
        badgeColor = AppColors.statusConcluido;
        icon = Icons.cloud_done_rounded;
        label = 'Al día';
        break;
      case SyncState.pendingOffline:
        badgeColor = AppColors.statusAsignado;
        icon = Icons.cloud_queue_rounded;
        label = '$pendingCount offline';
        break;
      case SyncState.syncing:
        badgeColor = AppColors.statusEnAtencion;
        icon = Icons.sync_rounded;
        label = 'Subiendo...';
        break;
      case SyncState.authRequired:
      case SyncState.error:
        badgeColor = AppColors.statusCancelado;
        icon = Icons.cloud_off_rounded;
        label = 'Sin vincular';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SyncStatusScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state == SyncState.syncing)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                  ),
                )
              else
                Icon(icon, size: 16, color: badgeColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
