import 'package:uuid/uuid.dart';

/// Tipo de acción requerida en la cola de sincronización con Google Sheets
enum SyncAction {
  create,
  update,
  delete,
}

/// Elemento de la cola de sincronización offline-first
class SyncItemModel {
  final String id;
  final String siniestroId;
  final SyncAction action;
  final DateTime timestamp;
  final int retryCount;
  final Map<String, dynamic> payload;
  final String? errorMessage;

  SyncItemModel({
    String? id,
    required this.siniestroId,
    required this.action,
    DateTime? timestamp,
    this.retryCount = 0,
    required this.payload,
    this.errorMessage,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  SyncItemModel copyWith({
    String? id,
    String? siniestroId,
    SyncAction? action,
    DateTime? timestamp,
    int? retryCount,
    Map<String, dynamic>? payload,
    String? errorMessage,
  }) {
    return SyncItemModel(
      id: id ?? this.id,
      siniestroId: siniestroId ?? this.siniestroId,
      action: action ?? this.action,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
      payload: payload ?? this.payload,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'siniestroId': siniestroId,
      'action': action.name,
      'timestamp': timestamp.toIso8601String(),
      'retryCount': retryCount,
      'payload': payload,
      'errorMessage': errorMessage,
    };
  }

  factory SyncItemModel.fromMap(Map<dynamic, dynamic> map) {
    return SyncItemModel(
      id: map['id'] as String? ?? const Uuid().v4(),
      siniestroId: map['siniestroId'] as String? ?? '',
      action: SyncAction.values.firstWhere(
        (a) => a.name == map['action'],
        orElse: () => SyncAction.create,
      ),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      retryCount: map['retryCount'] as int? ?? 0,
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? {}),
      errorMessage: map['errorMessage'] as String?,
    );
  }
}
