import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/datasources/local_storage_service.dart';
import '../../data/sync/sync_queue_manager.dart';
import '../providers/auth_provider.dart';
import '../providers/sync_provider.dart';

/// Pantalla detallada para inspección y control de la cola de sincronización offline
class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncManager = ref.watch(syncManagerProvider);
    final authState = ref.watch(authProvider);
    final spreadsheetId = LocalStorageService.getSpreadsheetId();
    final queueItems = LocalStorageService.getSyncQueue();

    Color statusColor;
    String statusTitle;
    String statusDesc;

    switch (syncManager.state) {
      case SyncState.synced:
        statusColor = AppColors.statusConcluido;
        statusTitle = 'Base de Datos Sincronizada';
        statusDesc = 'Todos los siniestros locales coinciden con Google Sheets.';
        break;
      case SyncState.pendingOffline:
        statusColor = AppColors.statusAsignado;
        statusTitle = '${syncManager.pendingCount} Registros Pendientes';
        statusDesc = 'Operaciones guardadas localmente esperando conexión para enviarse a Sheets.';
        break;
      case SyncState.syncing:
        statusColor = AppColors.statusEnAtencion;
        statusTitle = 'Sincronizando con Google Sheets...';
        statusDesc = 'Transmitiendo registros a la hoja maestra.';
        break;
      case SyncState.authRequired:
        statusColor = AppColors.statusCancelado;
        statusTitle = 'Vinculación Pendiente';
        statusDesc = 'Requiere inicio de sesión con Google o ID de hoja de cálculo en Ajustes.';
        break;
      case SyncState.error:
        statusColor = AppColors.statusCancelado;
        statusTitle = 'Error de Sincronización';
        statusDesc = syncManager.lastErrorMessage ?? 'No se pudo comunicar con Google Sheets.';
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado de Sincronización'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Tarjeta de Estado Principal
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: statusColor,
                      radius: 16,
                      child: const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        statusTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(statusDesc, style: const TextStyle(fontSize: 13)),
                const Divider(height: 20),
                Text(
                  'Última sincronización exitosa: ${syncManager.lastSyncTime != null ? DateFormatter.formatFull(syncManager.lastSyncTime!) : "Aún no ejecutada"}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Información de Cuenta y Hoja
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
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.account_circle_outlined, color: AppColors.primaryLight),
                    title: const Text('Cuenta Google', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(
                      authState.user?.email ?? 'No autenticado',
                      style: TextStyle(color: authState.user != null ? Colors.green : Colors.red),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.table_chart_outlined, color: AppColors.secondary),
                    title: const Text('ID de Google Sheets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(
                      spreadsheetId != null && spreadsheetId.isNotEmpty
                          ? spreadsheetId
                          : 'No configurado en Ajustes',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: spreadsheetId != null && spreadsheetId.isNotEmpty ? null : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Acciones de Sincronización
          ElevatedButton.icon(
            onPressed: syncManager.isSyncing
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Procesando cola de sincronización...')),
                    );
                    syncManager.processQueue();
                  },
            icon: syncManager.isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync_rounded),
            label: const Text('Sincronizar Cola Pendiente Ahora'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: syncManager.isSyncing ? null : () => syncManager.pullFromRemote(),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Descargar Registros desde Google Sheets'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
          const SizedBox(height: 20),

          // Elementos en Cola
          Text(
            'Elementos en Cola (${queueItems.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),

          if (queueItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: const Text('Cola vacía. Todos los registros están sincronizados.', style: TextStyle(color: Colors.grey)),
            )
          else
            ...queueItems.map((item) {
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.borderLight),
                ),
                child: ListTile(
                  title: Text(
                    'Acción: ${item.action.name.toUpperCase()} • Siniestro: ${item.payload['folio'] ?? item.siniestroId}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text(
                    'Encolado: ${DateFormatter.formatFull(item.timestamp)}\nReintentos: ${item.retryCount} ${item.errorMessage != null ? "• Error: ${item.errorMessage}" : ""}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    onPressed: () async {
                      await LocalStorageService.removeSyncItem(item.id);
                      syncManager.processQueue();
                    },
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
