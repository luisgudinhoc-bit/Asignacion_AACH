import 'package:uuid/uuid.dart';

/// Estatus operativos de un siniestro
enum SiniestroEstatus {
  asignado('Asignado', 'asignado'),
  enAtencion('En Atención', 'en_atencion'),
  concluido('Concluido', 'concluido'),
  cancelado('Cancelado', 'cancelado');

  final String displayName;
  final String key;

  const SiniestroEstatus(this.displayName, this.key);

  static SiniestroEstatus fromString(String? value) {
    if (value == null) return SiniestroEstatus.asignado;
    final lower = value.trim().toLowerCase();
    if (lower.contains('atenci') || lower.contains('arribo') || lower == 'en_atencion') {
      return SiniestroEstatus.enAtencion;
    }
    if (lower.contains('concluido') || lower.contains('cerrado') || lower.contains('terminado')) {
      return SiniestroEstatus.concluido;
    }
    if (lower.contains('cancelado') || lower.contains('falso')) {
      return SiniestroEstatus.cancelado;
    }
    return SiniestroEstatus.asignado;
  }
}

/// Modelo de Siniestro Vial para Asignación AACH
class SiniestroModel {
  final String id;
  final String folio;
  final String aseguradora;
  final String ajustador;
  final SiniestroEstatus estatus;
  final String tipoEvento;
  final String ubicacion;
  final String linkMaps;
  final String asegurado;
  final String telefonoAsegurado;
  final String vehiculo;
  final String colorVehiculo;
  final String placas;
  final String poliza;
  final DateTime fechaAsignacion;
  final DateTime? fechaArribo;
  final DateTime? fechaConclusion;
  final String? tipoCierre;
  final String observaciones;
  final bool sincronizado;
  final DateTime ultimaActualizacion;
  final int? rowNumberSheets;

  SiniestroModel({
    String? id,
    required this.folio,
    required this.aseguradora,
    required this.ajustador,
    this.estatus = SiniestroEstatus.asignado,
    this.tipoEvento = 'Choque',
    this.ubicacion = '',
    this.linkMaps = '',
    this.asegurado = '',
    this.telefonoAsegurado = '',
    this.vehiculo = '',
    this.colorVehiculo = '',
    this.placas = '',
    this.poliza = '',
    DateTime? fechaAsignacion,
    this.fechaArribo,
    this.fechaConclusion,
    this.tipoCierre,
    this.observaciones = '',
    this.sincronizado = false,
    DateTime? ultimaActualizacion,
    this.rowNumberSheets,
  })  : id = id ?? const Uuid().v4(),
        fechaAsignacion = fechaAsignacion ?? DateTime.now(),
        ultimaActualizacion = ultimaActualizacion ?? DateTime.now();

  /// Copia el modelo con modificaciones
  SiniestroModel copyWith({
    String? id,
    String? folio,
    String? aseguradora,
    String? ajustador,
    SiniestroEstatus? estatus,
    String? tipoEvento,
    String? ubicacion,
    String? linkMaps,
    String? asegurado,
    String? telefonoAsegurado,
    String? vehiculo,
    String? colorVehiculo,
    String? placas,
    String? poliza,
    DateTime? fechaAsignacion,
    DateTime? fechaArribo,
    DateTime? fechaConclusion,
    String? tipoCierre,
    String? observaciones,
    bool? sincronizado,
    DateTime? ultimaActualizacion,
    int? rowNumberSheets,
  }) {
    return SiniestroModel(
      id: id ?? this.id,
      folio: folio ?? this.folio,
      aseguradora: aseguradora ?? this.aseguradora,
      ajustador: ajustador ?? this.ajustador,
      estatus: estatus ?? this.estatus,
      tipoEvento: tipoEvento ?? this.tipoEvento,
      ubicacion: ubicacion ?? this.ubicacion,
      linkMaps: linkMaps ?? this.linkMaps,
      asegurado: asegurado ?? this.asegurado,
      telefonoAsegurado: telefonoAsegurado ?? this.telefonoAsegurado,
      vehiculo: vehiculo ?? this.vehiculo,
      colorVehiculo: colorVehiculo ?? this.colorVehiculo,
      placas: placas ?? this.placas,
      poliza: poliza ?? this.poliza,
      fechaAsignacion: fechaAsignacion ?? this.fechaAsignacion,
      fechaArribo: fechaArribo ?? this.fechaArribo,
      fechaConclusion: fechaConclusion ?? this.fechaConclusion,
      tipoCierre: tipoCierre ?? this.tipoCierre,
      observaciones: observaciones ?? this.observaciones,
      sincronizado: sincronizado ?? this.sincronizado,
      ultimaActualizacion: ultimaActualizacion ?? DateTime.now(),
      rowNumberSheets: rowNumberSheets ?? this.rowNumberSheets,
    );
  }

  /// Serialización a Map para almacenamiento local en Hive
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'folio': folio,
      'aseguradora': aseguradora,
      'ajustador': ajustador,
      'estatus': estatus.name,
      'tipoEvento': tipoEvento,
      'ubicacion': ubicacion,
      'linkMaps': linkMaps,
      'asegurado': asegurado,
      'telefonoAsegurado': telefonoAsegurado,
      'vehiculo': vehiculo,
      'colorVehiculo': colorVehiculo,
      'placas': placas,
      'poliza': poliza,
      'fechaAsignacion': fechaAsignacion.toIso8601String(),
      'fechaArribo': fechaArribo?.toIso8601String(),
      'fechaConclusion': fechaConclusion?.toIso8601String(),
      'tipoCierre': tipoCierre,
      'observaciones': observaciones,
      'sincronizado': sincronizado,
      'ultimaActualizacion': ultimaActualizacion.toIso8601String(),
      'rowNumberSheets': rowNumberSheets,
    };
  }

  /// Deserialización desde Map de Hive
  factory SiniestroModel.fromMap(Map<dynamic, dynamic> map) {
    return SiniestroModel(
      id: map['id'] as String? ?? const Uuid().v4(),
      folio: map['folio'] as String? ?? '',
      aseguradora: map['aseguradora'] as String? ?? 'Quálitas',
      ajustador: map['ajustador'] as String? ?? '',
      estatus: SiniestroEstatus.values.firstWhere(
        (e) => e.name == map['estatus'],
        orElse: () => SiniestroEstatus.fromString(map['estatus'] as String?),
      ),
      tipoEvento: map['tipoEvento'] as String? ?? 'Choque',
      ubicacion: map['ubicacion'] as String? ?? '',
      linkMaps: map['linkMaps'] as String? ?? '',
      asegurado: map['asegurado'] as String? ?? '',
      telefonoAsegurado: map['telefonoAsegurado'] as String? ?? '',
      vehiculo: map['vehiculo'] as String? ?? '',
      colorVehiculo: map['colorVehiculo'] as String? ?? '',
      placas: map['placas'] as String? ?? '',
      poliza: map['poliza'] as String? ?? '',
      fechaAsignacion: map['fechaAsignacion'] != null
          ? DateTime.tryParse(map['fechaAsignacion'] as String) ?? DateTime.now()
          : DateTime.now(),
      fechaArribo: map['fechaArribo'] != null
          ? DateTime.tryParse(map['fechaArribo'] as String)
          : null,
      fechaConclusion: map['fechaConclusion'] != null
          ? DateTime.tryParse(map['fechaConclusion'] as String)
          : null,
      tipoCierre: map['tipoCierre'] as String?,
      observaciones: map['observaciones'] as String? ?? '',
      sincronizado: map['sincronizado'] as bool? ?? false,
      ultimaActualizacion: map['ultimaActualizacion'] != null
          ? DateTime.tryParse(map['ultimaActualizacion'] as String) ?? DateTime.now()
          : DateTime.now(),
      rowNumberSheets: map['rowNumberSheets'] as int?,
    );
  }

  /// Convierte el registro a fila para Google Sheets API
  List<dynamic> toSheetsRow() {
    return [
      id,
      folio,
      aseguradora,
      ajustador,
      estatus.displayName,
      tipoEvento,
      ubicacion,
      linkMaps,
      asegurado,
      telefonoAsegurado,
      vehiculo,
      colorVehiculo,
      placas,
      poliza,
      '${fechaAsignacion.day.toString().padLeft(2, '0')}/${fechaAsignacion.month.toString().padLeft(2, '0')}/${fechaAsignacion.year}',
      '${fechaAsignacion.hour.toString().padLeft(2, '0')}:${fechaAsignacion.minute.toString().padLeft(2, '0')}',
      fechaArribo != null ? fechaArribo!.toIso8601String() : '',
      fechaConclusion != null ? fechaConclusion!.toIso8601String() : '',
      tipoCierre ?? '',
      observaciones,
      DateTime.now().toIso8601String(),
    ];
  }

  /// Construye un modelo desde una fila leída de Google Sheets
  factory SiniestroModel.fromSheetsRow(List<dynamic> row, {int? rowNumber}) {
    String getCol(int index) => index < row.length ? row[index].toString().trim() : '';

    return SiniestroModel(
      id: getCol(0).isNotEmpty ? getCol(0) : const Uuid().v4(),
      folio: getCol(1),
      aseguradora: getCol(2).isNotEmpty ? getCol(2) : 'Quálitas',
      ajustador: getCol(3),
      estatus: SiniestroEstatus.fromString(getCol(4)),
      tipoEvento: getCol(5).isNotEmpty ? getCol(5) : 'Choque',
      ubicacion: getCol(6),
      linkMaps: getCol(7),
      asegurado: getCol(8),
      telefonoAsegurado: getCol(9),
      vehiculo: getCol(10),
      colorVehiculo: getCol(11),
      placas: getCol(12),
      poliza: getCol(13),
      fechaArribo: getCol(16).isNotEmpty ? DateTime.tryParse(getCol(16)) : null,
      fechaConclusion: getCol(17).isNotEmpty ? DateTime.tryParse(getCol(17)) : null,
      tipoCierre: getCol(18).isNotEmpty ? getCol(18) : null,
      observaciones: getCol(19),
      sincronizado: true,
      rowNumberSheets: rowNumber,
    );
  }
}
