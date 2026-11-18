import 'package:uuid/uuid.dart';

/// Modelo de Ajustador del Despacho AACH
class AjustadorModel {
  final String id;
  final String nombre;
  final String telefonoWhatsApp;
  final bool activo;
  final int foliosAtendidos;

  AjustadorModel({
    String? id,
    required this.nombre,
    required this.telefonoWhatsApp,
    this.activo = true,
    this.foliosAtendidos = 0,
  }) : id = id ?? const Uuid().v4();

  AjustadorModel copyWith({
    String? id,
    String? nombre,
    String? telefonoWhatsApp,
    bool? activo,
    int? foliosAtendidos,
  }) {
    return AjustadorModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      telefonoWhatsApp: telefonoWhatsApp ?? this.telefonoWhatsApp,
      activo: activo ?? this.activo,
      foliosAtendidos: foliosAtendidos ?? this.foliosAtendidos,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'telefonoWhatsApp': telefonoWhatsApp,
      'activo': activo,
      'foliosAtendidos': foliosAtendidos,
    };
  }

  factory AjustadorModel.fromMap(Map<dynamic, dynamic> map) {
    return AjustadorModel(
      id: map['id'] as String? ?? const Uuid().v4(),
      nombre: map['nombre'] as String? ?? '',
      telefonoWhatsApp: map['telefonoWhatsApp'] as String? ?? '',
      activo: map['activo'] as bool? ?? true,
      foliosAtendidos: map['foliosAtendidos'] as int? ?? 0,
    );
  }

  List<dynamic> toSheetsRow() {
    return [
      id,
      nombre,
      telefonoWhatsApp,
      activo ? 'SI' : 'NO',
      foliosAtendidos,
    ];
  }

  factory AjustadorModel.fromSheetsRow(List<dynamic> row) {
    String getCol(int index) => index < row.length ? row[index].toString().trim() : '';

    return AjustadorModel(
      id: getCol(0).isNotEmpty ? getCol(0) : const Uuid().v4(),
      nombre: getCol(1),
      telefonoWhatsApp: getCol(2),
      activo: getCol(3).toUpperCase() != 'NO',
      foliosAtendidos: int.tryParse(getCol(4)) ?? 0,
    );
  }

  /// Lista predeterminada de ajustadores del despacho AACH
  static List<AjustadorModel> get defaultAjustadores => [
        AjustadorModel(
          nombre: 'Sergio Sanchez',
          telefonoWhatsApp: '5511223344',
          activo: true,
        ),
        AjustadorModel(
          nombre: 'Andres Gudiño',
          telefonoWhatsApp: '5522334455',
          activo: true,
        ),
        AjustadorModel(
          nombre: 'Alejandro Chavez',
          telefonoWhatsApp: '5533445566',
          activo: true,
        ),
        AjustadorModel(
          nombre: 'Armando',
          telefonoWhatsApp: '5544556677',
          activo: true,
        ),
        AjustadorModel(
          nombre: 'Luis',
          telefonoWhatsApp: '5555667788',
          activo: true,
        ),
        AjustadorModel(
          nombre: 'Axel',
          telefonoWhatsApp: '5566778899',
          activo: true,
        ),
        AjustadorModel(
          nombre: 'Ian',
          telefonoWhatsApp: '5577889900',
          activo: true,
        ),
      ];
}
