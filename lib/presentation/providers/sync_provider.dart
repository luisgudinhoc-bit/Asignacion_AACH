import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/sync/sync_queue_manager.dart';
import 'auth_provider.dart';
import 'siniestro_provider.dart';

final syncManagerProvider = ChangeNotifierProvider<SyncQueueManager>((ref) {
  final sheetsService = ref.watch(googleSheetsServiceProvider);
  final siniestroRepo = ref.watch(siniestroRepositoryProvider);

  return SyncQueueManager(
    sheetsService: sheetsService,
    siniestroRepository: siniestroRepo,
  );
});

final syncStateProvider = Provider<SyncState>((ref) {
  final manager = ref.watch(syncManagerProvider);
  return manager.state;
});

final pendingSyncCountProvider = Provider<int>((ref) {
  final manager = ref.watch(syncManagerProvider);
  return manager.pendingCount;
});
