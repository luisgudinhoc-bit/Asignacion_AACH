/// Modelo de Aseguradora y datos de cabina
class AseguradoraModel {
  final String nombre;
  final String prefijoHabitual;
  final String telefonoCabina;

  const AseguradoraModel({
    required this.nombre,
    required this.prefijoHabitual,
    required this.telefonoCabina,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'prefijoHabitual': prefijoHabitual,
      'telefonoCabina': telefonoCabina,
    };
  }

  factory AseguradoraModel.fromMap(Map<dynamic, dynamic> map) {
    return AseguradoraModel(
      nombre: map['nombre'] as String? ?? '',
      prefijoHabitual: map['prefijoHabitual'] as String? ?? '',
      telefonoCabina: map['telefonoCabina'] as String? ?? '',
    );
  }

  List<dynamic> toSheetsRow() {
    return [
      nombre,
      prefijoHabitual,
      telefonoCabina,
    ];
  }

  factory AseguradoraModel.fromSheetsRow(List<dynamic> row) {
    String getCol(int index) => index < row.length ? row[index].toString().trim() : '';
    return AseguradoraModel(
      nombre: getCol(0),
      prefijoHabitual: getCol(1),
      telefonoCabina: getCol(2),
    );
  }

  static List<AseguradoraModel> get defaultList => const [
        AseguradoraModel(
          nombre: 'Quálitas',
          prefijoHabitual: '04',
          telefonoCabina: '800 800 2880',
        ),
        AseguradoraModel(
          nombre: 'GNP Seguros',
          prefijoHabitual: 'GNP',
          telefonoCabina: '55 5227 9000',
        ),
        AseguradoraModel(
          nombre: 'Inbursa',
          prefijoHabitual: 'INB',
          telefonoCabina: '800 909 0000',
        ),
        AseguradoraModel(
          nombre: 'AXA Seguros',
          prefijoHabitual: 'AXA',
          telefonoCabina: '800 900 1292',
        ),
        AseguradoraModel(
          nombre: 'HDI Seguros',
          prefijoHabitual: 'HDI',
          telefonoCabina: '800 019 6000',
        ),
        AseguradoraModel(
          nombre: 'Chubb Seguros',
          prefijoHabitual: 'CHB',
          telefonoCabina: '800 223 2001',
        ),
        AseguradoraModel(
          nombre: 'Mapfre',
          prefijoHabitual: 'MPF',
          telefonoCabina: '800 849 8585',
        ),
      ];
}
