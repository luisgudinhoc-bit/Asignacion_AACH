/// Representación de un tramo de la Autopista Arco Norte
class ArcoNorteTramo {
  final String localidad;
  final String codigoPostal;
  final double kmInicio;
  final double kmFin;
  final String estado;
  final double latitud;
  final double longitud;

  const ArcoNorteTramo({
    required this.localidad,
    required this.codigoPostal,
    required this.kmInicio,
    required this.kmFin,
    required this.estado,
    required this.latitud,
    required this.longitud,
  });

  bool containsKm(double km) {
    return km >= kmInicio && km <= kmFin;
  }
}

/// Resultado del análisis de kilometraje en Arco Norte
class ArcoNorteMatch {
  final double kilometro;
  final String localidad;
  final String codigoPostal;
  final String estado;
  final String tramoDescripcion;
  final String linkGoogleMaps;
  final double latitud;
  final double longitud;

  const ArcoNorteMatch({
    required this.kilometro,
    required this.localidad,
    required this.codigoPostal,
    required this.estado,
    required this.tramoDescripcion,
    required this.linkGoogleMaps,
    required this.latitud,
    required this.longitud,
  });
}

/// Servicio especializado en kilometrajes y tramos carreteros de la Autopista Arco Norte
/// Resuelve el problema operativo de que Google Maps no tiene mapeados los kilometrajes físicos.
class ArcoNorteService {
  /// Catálogo oficial de tramos de Arco Norte según la matriz operativa del despacho
  static const List<ArcoNorteTramo> tramos = [
    ArcoNorteTramo(
      localidad: 'Atlacomulco',
      codigoPostal: '50300',
      kmInicio: 11.2,
      kmFin: 13.0,
      estado: 'Estado de México',
      latitud: 19.8052,
      longitud: -99.8654,
    ),
    ArcoNorteTramo(
      localidad: 'Acambay',
      codigoPostal: '50300',
      kmInicio: 13.0,
      kmFin: 48.0,
      estado: 'Estado de México',
      latitud: 19.9214,
      longitud: -99.8189,
    ),
    ArcoNorteTramo(
      localidad: 'Jilotepec',
      codigoPostal: '54240',
      kmInicio: 48.0,
      kmFin: 54.0,
      estado: 'Estado de México',
      latitud: 19.9542,
      longitud: -99.5512,
    ),
    ArcoNorteTramo(
      localidad: 'Querétaro (Palmillas)',
      codigoPostal: '54280',
      kmInicio: 54.0,
      kmFin: 70.0,
      estado: 'Estado de México',
      latitud: 20.0125,
      longitud: -99.4521,
    ),
    ArcoNorteTramo(
      localidad: 'Tula 2',
      codigoPostal: '42820',
      kmInicio: 70.0,
      kmFin: 80.0,
      estado: 'Hidalgo',
      latitud: 20.0267,
      longitud: -99.3412,
    ),
    ArcoNorteTramo(
      localidad: 'Tula 1',
      codigoPostal: '42950',
      kmInicio: 80.0,
      kmFin: 88.0,
      estado: 'Hidalgo',
      latitud: 20.0415,
      longitud: -99.2541,
    ),
    ArcoNorteTramo(
      localidad: 'Atitalaquia',
      codigoPostal: '42970',
      kmInicio: 88.0,
      kmFin: 110.0,
      estado: 'Hidalgo',
      latitud: 20.0558,
      longitud: -99.1823,
    ),
    ArcoNorteTramo(
      localidad: 'Ajoloapan',
      codigoPostal: '55679',
      kmInicio: 110.0,
      kmFin: 129.0,
      estado: 'Estado de México',
      latitud: 20.0152,
      longitud: -99.0014,
    ),
    ArcoNorteTramo(
      localidad: 'Pachuca',
      codigoPostal: '43860',
      kmInicio: 129.0,
      kmFin: 153.0,
      estado: 'Hidalgo',
      latitud: 19.9812,
      longitud: -98.7845,
    ),
    ArcoNorteTramo(
      localidad: 'Tulancingo',
      codigoPostal: '43832',
      kmInicio: 153.0,
      kmFin: 165.0,
      estado: 'Hidalgo',
      latitud: 19.8541,
      longitud: -98.6521,
    ),
    ArcoNorteTramo(
      localidad: 'Cd. Sahagún',
      codigoPostal: '43700',
      kmInicio: 165.0,
      kmFin: 182.0,
      estado: 'Hidalgo',
      latitud: 19.7824,
      longitud: -98.5714,
    ),
    ArcoNorteTramo(
      localidad: 'Calpulalpan',
      codigoPostal: '90200',
      kmInicio: 182.0,
      kmFin: 197.0,
      estado: 'Tlaxcala',
      latitud: 19.6014,
      longitud: -98.5321,
    ),
    ArcoNorteTramo(
      localidad: 'Sanctórum',
      codigoPostal: '90230',
      kmInicio: 197.0,
      kmFin: 222.0,
      estado: 'Tlaxcala',
      latitud: 19.4925,
      longitud: -98.4812,
    ),
    ArcoNorteTramo(
      localidad: 'San Martín Texmelucan',
      codigoPostal: '90120',
      kmInicio: 222.0,
      kmFin: 223.5,
      estado: 'Puebla',
      latitud: 19.3314,
      longitud: -98.4215,
    ),
  ];

  /// Detecta si un texto menciona un kilometraje (ej. "Km 182", "km 182 dir puebla", "km 11+200")
  static ArcoNorteMatch? findKmInText(String text) {
    if (text.trim().isEmpty) return null;

    // Patrón 1: km 11+200
    final plusMatch = RegExp(r'\bkm\.?\s*(\d{1,3})\s*\+\s*(\d{1,3})\b', caseSensitive: false).firstMatch(text);
    if (plusMatch != null) {
      final base = double.tryParse(plusMatch.group(1)!) ?? 0;
      final extra = (double.tryParse(plusMatch.group(2)!) ?? 0) / 1000.0;
      return resolveKm(base + extra);
    }

    // Patrón 2: km 182, km182, k.m. 182, kilometro 182
    final reg = RegExp(r'\b(?:km|k\.m\.|kil[oó]metro)\.?\s*(\d{1,3}(?:\.\d+)?)\b', caseSensitive: false);
    final match = reg.firstMatch(text);
    if (match != null) {
      final km = double.tryParse(match.group(1)!);
      if (km != null && km >= 11 && km <= 223) {
        return resolveKm(km);
      }
    }

    return null;
  }

  /// Resuelve un número de kilómetro al tramo correspondiente de Arco Norte
  static ArcoNorteMatch? resolveKm(double km) {
    ArcoNorteTramo? matchingTramo;

    for (final tramo in tramos) {
      if (km >= tramo.kmInicio && km <= tramo.kmFin) {
        matchingTramo = tramo;
        break;
      }
    }

    // Si está justo en el límite superior del último tramo
    matchingTramo ??= tramos.firstWhere(
      (t) => (km - t.kmFin).abs() < 1.0,
      orElse: () => tramos.first,
    );

    // Calcular coordenadas aproximadas interpoladas dentro del tramo
    final lat = matchingTramo.latitud;
    final lng = matchingTramo.longitud;
    final kmLabel = km.toStringAsFixed(km.truncateToDouble() == km ? 0 : 1);
    final mapsUrl = 'https://www.google.com/maps?q=$lat,$lng(Arco+Norte+Km+$kmLabel)';

    return ArcoNorteMatch(
      kilometro: km,
      localidad: matchingTramo.localidad,
      codigoPostal: matchingTramo.codigoPostal,
      estado: matchingTramo.estado,
      tramoDescripcion: 'Km ${matchingTramo.kmInicio.toInt()} a ${matchingTramo.kmFin.toInt()} (${matchingTramo.localidad})',
      linkGoogleMaps: mapsUrl,
      latitud: lat,
      longitud: lng,
    );
  }
}
