import '../../core/utils/string_extensions.dart';
import 'arco_norte_service.dart';

/// Resultado estructurado del análisis de un mensaje de cabina o reenvíos de chat
class ParsedCabinaMessage {
  final String? folio;
  final String? aseguradora;
  final String? ajustador;
  final String? asegurado;
  final String? telefonoAsegurado;
  final String? vehiculo;
  final String? colorVehiculo;
  final String? placas;
  final String? poliza;
  final String? ubicacion;
  final String? municipio;
  final String? estado;
  final String? referencias;
  final String? linkMaps;
  final String? tipoEvento;
  final String? detalleEvento;
  final String? horaReporte;
  final String? horaAsignacion;
  final String? observaciones;
  final String rawText;

  const ParsedCabinaMessage({
    this.folio,
    this.aseguradora,
    this.ajustador,
    this.asegurado,
    this.telefonoAsegurado,
    this.vehiculo,
    this.colorVehiculo,
    this.placas,
    this.poliza,
    this.ubicacion,
    this.municipio,
    this.estado,
    this.referencias,
    this.linkMaps,
    this.tipoEvento,
    this.detalleEvento,
    this.horaReporte,
    this.horaAsignacion,
    this.observaciones,
    required this.rawText,
  });

  bool get hasContent =>
      (folio != null && folio!.isNotEmpty) ||
      (aseguradora != null && aseguradora!.isNotEmpty) ||
      (ajustador != null && ajustador!.isNotEmpty) ||
      (asegurado != null && asegurado!.isNotEmpty) ||
      (telefonoAsegurado != null && telefonoAsegurado!.isNotEmpty) ||
      (vehiculo != null && vehiculo!.isNotEmpty) ||
      (municipio != null && municipio!.isNotEmpty) ||
      (linkMaps != null && linkMaps!.isNotEmpty) ||
      (referencias != null && referencias!.isNotEmpty);
}

/// Servicio inteligente de extracción text-first tolerante a mensajes formales de cabina
/// y mensajes fragmentados/reenviados típicos de chats operativos de WhatsApp en México
class WhatsAppParserService {
  /// Analiza texto pegado desde WhatsApp (formal o fragmentado)
  static ParsedCabinaMessage parse(String rawText) {
    if (rawText.trim().isEmpty) {
      return const ParsedCabinaMessage(rawText: '');
    }

    // Extracción de horas operativas Inbursa / Cabina antes de limpieza (ej: "22:30 22:32")
    String? horaReporte;
    String? horaAsignacion;
    final inbursaHoursMatch = RegExp(r'\b(\d{1,2}:\d{2})\s+(\d{1,2}:\d{2})\b').firstMatch(rawText);
    if (inbursaHoursMatch != null) {
      horaReporte = inbursaHoursMatch.group(1);
      horaAsignacion = inbursaHoursMatch.group(2);
    }

    // Etapa 1: Limpieza profunda de ruido de capturas y chat de WhatsApp
    final cleanedText = _cleanOcrNoise(rawText);

    // Reconstruir enlaces Maps o coordenadas GPS crudas (20.650354,-98.649149)
    final linkMaps = _extractMapsUrl(cleanedText) ?? _extractMapsUrl(rawText);

    // 1. Folio estructurado o sin etiqueta (6-8 dígitos, 305XXXX, 705XXXX)
    final folio = _extractFolio(cleanedText);
    final aseguradora = _extractAseguradora(cleanedText, folio);
    final ajustador = _extractAjustador(cleanedText);

    // 2. Teléfono suelto de 10 dígitos sin etiqueta
    final telefono = _extractTelefono(cleanedText, knownFolio: folio);
    final placas = _extractPlacas(cleanedText);

    // 3. Terceros involucrados (ej: "3o Audi A1", "3o kia gris")
    final vehiculosTerceros = _extractVehiculosTerceros(cleanedText);

    // 4. Extracción de vehículo, color y soporte para nombres en la misma línea ("Mazda negro Alberto Gutierrez")
    final vehiculoInfo = _extractVehiculoYColor(cleanedText, placas);
    final vehiculo = vehiculoInfo['vehiculo'];
    final color = vehiculoInfo['color'];
    final sameLineName = vehiculoInfo['sameLineName'];

    final eventoInfo = _extractTipoEvento(cleanedText);
    final tipoEvento = eventoInfo['tipo'];
    final detalleEvento = eventoInfo['detalle'];

    // 5. Nombre del asegurado (prioriza línea propia o nombre en misma línea del vehículo)
    final asegurado = _extractAsegurado(cleanedText, ajustador, sameLineName);
    final poliza = _extractPoliza(cleanedText);
    final referencias = _extractReferencias(cleanedText);
    final ubicacion = _extractUbicacion(cleanedText);

    // Integración de observaciones con Terceros, Cabinero y horas Inbursa
    var observaciones = _extractObservaciones(cleanedText);
    if (vehiculosTerceros.isNotEmpty) {
      final terStr = vehiculosTerceros.join(' • ');
      observaciones = observaciones != null && observaciones.isNotEmpty
          ? '$terStr • $observaciones'
          : terStr;
    }
    if (horaReporte != null && horaAsignacion != null) {
      final horasStr = 'Reporte cabina: $horaReporte hrs | Asignación: $horaAsignacion hrs';
      observaciones = observaciones != null && observaciones.isNotEmpty
          ? '$observaciones • $horasStr'
          : horasStr;
    }
    if (cleanedText.toLowerCase().contains('cabinero:')) {
      final cabMatch = RegExp(r'cabinero\s*[:\-]\s*([^\n\r]+)', caseSensitive: false).firstMatch(cleanedText);
      if (cabMatch != null) {
        final cabNombre = cabMatch.group(1)?.trim();
        if (cabNombre != null && cabNombre.isNotEmpty) {
          final cabStr = 'Cabinero: $cabNombre';
          if (observaciones == null || !observaciones.contains(cabStr)) {
            observaciones = observaciones != null && observaciones.isNotEmpty
                ? '$cabStr • $observaciones'
                : cabStr;
          }
        }
      }
    }

    // Deducir Municipio y Estado a partir de referencias o ubicación
    final locGeo = _deduceMunicipioEstado(ubicacion ?? referencias ?? '');

    // Detección especializada para Autopista Arco Norte por Kilometraje
    final arcoMatch = ArcoNorteService.findKmInText('$rawText ${referencias ?? ""} ${ubicacion ?? ""}');
    final municipioFinal = locGeo['municipio'] ?? arcoMatch?.localidad;
    final estadoFinal = locGeo['estado'] ?? arcoMatch?.estado;

    final referenciasFinal = referencias ??
        (arcoMatch != null
            ? 'Autopista Arco Norte Km ${arcoMatch.kilometro.toStringAsFixed(0)} (${arcoMatch.tramoDescripcion}) CP ${arcoMatch.codigoPostal}'
            : null);

    return ParsedCabinaMessage(
      folio: folio,
      aseguradora: aseguradora,
      ajustador: ajustador,
      asegurado: asegurado,
      telefonoAsegurado: telefono,
      vehiculo: vehiculo,
      colorVehiculo: color,
      placas: placas,
      poliza: poliza,
      ubicacion: ubicacion,
      municipio: municipioFinal,
      estado: estadoFinal,
      referencias: referenciasFinal,
      linkMaps: linkMaps,
      tipoEvento: tipoEvento,
      detalleEvento: detalleEvento,
      horaReporte: horaReporte,
      horaAsignacion: horaAsignacion,
      observaciones: observaciones,
      rawText: rawText,
    );
  }

  /// Limpieza de ruido de capturas de chat (timestamps, reenvíos, cabeceras)
  static String _cleanOcrNoise(String rawText) {
    if (rawText.trim().isEmpty) return '';

    var text = rawText.replaceAll('*', '');

    // Reconstruir URLs de Google Maps partidas en dos líneas
    text = text.replaceAll(
      RegExp(r'(https?:\/\/(?:maps\.app\.goo\.gl|goo\.gl\/maps))\/?\s*[\r\n]+\s*\/?([A-Za-z0-9_\-]+)', caseSensitive: false),
      r'$1/$2',
    );

    final rawLines = text.split(RegExp(r'[\r\n]+'));
    final cleanedLines = <String>[];

    // Frecuencia de líneas para detectar remitentes de reenvíos repetidos (ej: "Alejandro Chavez")
    final lineFrequencies = <String, int>{};
    for (final l in rawLines) {
      final t = l.trim();
      if (t.isNotEmpty) {
        lineFrequencies[t] = (lineFrequencies[t] ?? 0) + 1;
      }
    }

    for (var line in rawLines) {
      var trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // 1. Eliminar timestamps pegados al final de cualquier línea
      // Ej: "3059238 8:04 p. m." -> "3059238", "Daniel Rojas 8:04 p. m." -> "Daniel Rojas"
      trimmed = trimmed.replaceAll(
        RegExp(r'\s+\d{1,2}:\d{2}(?::\d{2})?\s*(?:[ap]\.?\s*m\.?|hrs?|hr)?$', caseSensitive: false),
        '',
      ).trim();

      if (trimmed.isEmpty) continue;

      // 2. Descartar líneas iguales a "Reenviado", "Forwarded", "Mensaje reenviado"
      if (RegExp(r'^(?:»?\s*reenviado|forwarded|mensaje reenviado)$', caseSensitive: false).hasMatch(trimmed)) {
        continue;
      }

      // 3. Descartar "maps.app.goo.gl" suelto cuando no tiene https:// ni la ruta del pin
      if (RegExp(r'^maps\.app\.goo\.gl$', caseSensitive: false).hasMatch(trimmed)) {
        continue;
      }

      // 4. Descartar timestamps aislados (ej: "8:04 p. m.", "19:08", "8:09", "19:08 19:10")
      if (RegExp(r'^\d{1,2}:\d{2}(?::\d{2})?(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?(?:\s*[ap]\.?\s*m\.?|\s*hrs?)?$', caseSensitive: false).hasMatch(trimmed)) {
        continue;
      }

      // 5. Descartar cabeceras típicas de grupos de WhatsApp
      final lower = trimmed.toLowerCase();
      if (lower.startsWith('despacho de ajustes') ||
          lower.contains('alejandro, armando, sergio') ||
          lower == 'hoy' ||
          lower == 'ayer') {
        continue;
      }

      // 6. Descartar remitentes de reenvíos que aparecen repetidos solo como cabecera
      if ((lineFrequencies[trimmed] ?? 0) > 1 &&
          RegExp(r'^[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+(?:\s+[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+){1,2}$').hasMatch(trimmed)) {
        continue;
      }

      cleanedLines.add(trimmed);
    }

    return cleanedLines.join('\n');
  }

  /// Extrae el Folio o Número de Siniestro (etiquetado o número aislado como "3059238")
  static String? _extractFolio(String text) {
    // 1. Patrones explícitos con etiqueta (incluyendo "No. Reporte: ...", "Siniestro #...")
    final explicitPatterns = [
      RegExp(r'(?:no\.?\s*(?:de\s*)?reporte|num\.?\s*reporte|no\.?\s*siniestro|folio|siniestro|reporte|expediente|orden)\s*[:#\-]?\s*([A-Za-z0-9\-_/]{4,20})', caseSensitive: false),
      RegExp(r'\b((?:INB|MPF|CRB|SPT|QUAL|GNP|AXA|HDI)[A-Za-z0-9\-_]{4,15})\b', caseSensitive: false),
      RegExp(r'\b(CRA-\d{6,14})\b', caseSensitive: false),
    ];

    for (final reg in explicitPatterns) {
      final match = reg.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final val = match.group(1)?.trim();
        if (val != null && val.isNotEmpty && !val.toLowerCase().contains('cabina')) {
          return val.toUpperCase();
        }
      }
    }

    // 2. Líneas aisladas que contienen únicamente un número de 6 a 9 dígitos (ej: "3059238", "3059330", "7051234")
    final lines = text.split(RegExp(r'[\r\n]+'));
    for (final line in lines) {
      final cleanLine = line.trim();
      if (RegExp(r'^\d{6,9}$').hasMatch(cleanLine)) {
        return cleanLine;
      }
    }

    // 3. Fallback: buscar cualquier bloque numérico de 6 a 8 dígitos en el texto
    final numMatch = RegExp(r'\b((?:305|705)\d{3,5}|\d{6,8})\b').firstMatch(text);
    if (numMatch != null) {
      return numMatch.group(1);
    }

    return null;
  }

  /// Extrae la Aseguradora normalizada (reconoce prefijos 305XXXX y 705XXXX como Inbursa)
  static String? _extractAseguradora(String text, [String? folio]) {
    final lower = text.toLowerCase();

    if (lower.contains('inbursa')) return 'Inbursa';
    if (lower.contains('mapfre')) return 'Mapfre';
    if (lower.contains('crabi') || lower.contains('cra-') || lower.contains('#cra-')) return 'Crabi';
    if (lower.contains('spt')) return 'SPT Seguros';
    if (lower.contains('otra') || lower.contains('otro')) return 'Otra Compañía';

    // Compatibilidad adicional
    if (lower.contains('qualitas') || lower.contains('quálitas')) return 'Quálitas';
    if (lower.contains('gnp')) return 'GNP Seguros';
    if (lower.contains('axa')) return 'AXA Seguros';
    if (lower.contains('hdi')) return 'HDI Seguros';
    if (lower.contains('chubb')) return 'Chubb Seguros';

    // Deducir por folio si no viene el nombre explícito
    if (folio != null) {
      if (folio.startsWith('CRA-') || folio.startsWith('CRB')) return 'Crabi';
      // Folios típicos de Inbursa de 6 a 8 dígitos con prefijos 305, 705 o iniciando con 30
      if (RegExp(r'^(?:305|705)\d{3,5}$').hasMatch(folio) || RegExp(r'^(?:30|70)\d{5}$').hasMatch(folio)) {
        return 'Inbursa';
      }
    }

    return null;
  }

  /// Extrae menciones de ajustadores en el chat (ej: "@Sergio Sanchez", "Vas @Sergio Sanchez", "Te formó este luis...")
  static String? _extractAjustador(String text) {
    final adjustersPool = [
      'Sergio Sanchez',
      'Sergio',
      'Andres Gudiño',
      'Andres Gudino',
      'Andres',
      'Alejandro Chavez',
      'Alejandro',
      'Armando',
      'Luis',
      'Axel',
      'Ian',
    ];

    final candidates = <String>[];

    // 1. Mención con @ (ej: "@Sergio Sanchez", "Vas @Sergio Sanchez", "Porfa @Andres Gudiño")
    final mentionMatches = RegExp(
      r'@([A-Za-zÁÉÍÓÚáéíóúñÑ]+(?:\s+[A-Za-zÁÉÍÓÚáéíóúñÑ]+)?)',
    ).allMatches(text);
    for (final m in mentionMatches) {
      final mentioned = m.group(1)?.trim();
      if (mentioned != null && mentioned.isNotEmpty) {
        String matched = mentioned;
        for (final aj in adjustersPool) {
          if (mentioned.toLowerCase() == aj.toLowerCase() ||
              mentioned.toLowerCase().contains(aj.toLowerCase()) ||
              aj.toLowerCase().contains(mentioned.toLowerCase())) {
            matched = aj;
            break;
          }
        }
        candidates.add(matched);
      }
    }

    // 2. Frases operativas de turno / asignación en grupos de despacho
    // Ej: "Te formó este luis", "Te formo este luis", "Te tocó este luis", "Vas sergio", "Porfa andres", "Formó a luis"
    final dispatchPatterns = [
      RegExp(r'(?:te\s+form[oó]\s+este|te\s+toc[oó]\s+este|te\s+mand[eé]\s+este)\s+@?([A-Za-zÁÉÍÓÚáéíóúñÑ]+(?:\s+[A-Za-zÁÉÍÓÚáéíóúñÑ]+)?)', caseSensitive: false),
      RegExp(r'(?:vas|porfa|atiende|le\s+toca\s+a|form[oó]\s+a|formo\s+a|asigna\s+a)\s+@?([A-Za-zÁÉÍÓÚáéíóúñÑ]+(?:\s+[A-Za-zÁÉÍÓÚáéíóúñÑ]+)?)', caseSensitive: false),
    ];
    for (final reg in dispatchPatterns) {
      final matches = reg.allMatches(text);
      for (final m in matches) {
        final val = m.group(1)?.trim();
        if (val != null && val.isNotEmpty) {
          final lower = val.toLowerCase();
          if (!['este', 'por', 'la', 'carretera', 'autopista', 'siniestro', 'reporte', 'choque', 'favor', 'favor de'].contains(lower)) {
            String matched = val;
            for (final aj in adjustersPool) {
              if (lower == aj.toLowerCase() ||
                  lower.contains(aj.toLowerCase()) ||
                  aj.toLowerCase().contains(lower)) {
                matched = aj;
                break;
              }
            }
            candidates.add(matched);
          }
        }
      }
    }

    if (candidates.isEmpty) return null;
    // Si hay reasignación en el mismo hilo, la última mención es la asignación final
    return candidates.last.capitalizeWords();
  }

  /// Extrae el Teléfono de contacto (con etiqueta o suelto de 10 dígitos sin etiqueta)
  static String? _extractTelefono(String text, {String? knownFolio}) {
    // 1. Patrón con etiqueta explícita (Tel, Cel, WhatsApp, etc.)
    final labeled = RegExp(
      r'(?:tel(?:[eé]fono)?|cel(?:ular)?|contacto|whats(?:app)?)\s*[:\-]?\s*([+0-9\s\-()]{8,20})',
      caseSensitive: false,
    ).firstMatch(text);
    if (labeled != null) {
      final digits = labeled.group(1)?.replaceAll(RegExp(r'\D'), '');
      if (digits != null && digits.length >= 10) {
        return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
      }
    }

    // 2. Líneas aisladas o números sueltos de 10 dígitos (formato estándar móvil/fijo en México)
    final looseMatches = RegExp(r'(?<![\d.])([2-9]\d{9})(?![\d.])').allMatches(text);
    for (final m in looseMatches) {
      final num = m.group(1);
      if (num != null && num != knownFolio) {
        return num;
      }
    }

    // 3. Formato con espacios o guiones (ej. 55 1234 5678 o 55-1234-5678)
    final formattedMatches = RegExp(r'(?<![\d.])([2-9]\d{1,2}[-\s]\d{3,4}[-\s]\d{4})(?![\d.])').allMatches(text);
    for (final m in formattedMatches) {
      final raw = m.group(1);
      if (raw != null) {
        final digits = raw.replaceAll(RegExp(r'\D'), '');
        if (digits.length == 10 && digits != knownFolio) {
          return digits;
        }
      }
    }

    return null;
  }

  /// Extrae el link de Google Maps o convierte coordenadas GPS crudas a link válido
  static String? _extractMapsUrl(String text) {
    // 1. URL completa en una sola línea
    final reg = RegExp(
      r'(https?:\/\/(?:maps\.app\.goo\.gl|goo\.gl\/maps|www\.google\.com\/maps|maps\.google\.com)[^\s\n\r]+)',
      caseSensitive: false,
    );
    final match = reg.firstMatch(text);
    if (match != null) {
      return match.group(1)?.trim();
    }

    // 2. Fallback: URL dividida en dos líneas en capturas OCR
    final splitReg = RegExp(
      r'(https?:\/\/(?:maps\.app\.goo\.gl|goo\.gl\/maps))\/?\s*[\r\n]+\s*\/?([A-Za-z0-9_\-]+)',
      caseSensitive: false,
    );
    final splitMatch = splitReg.firstMatch(text);
    if (splitMatch != null) {
      final base = splitMatch.group(1)?.trim();
      final slug = splitMatch.group(2)?.trim();
      if (base != null && slug != null) {
        return '$base/$slug';
      }
    }

    // 3. Coordenadas GPS crudas (ej: 20.650354,-98.649149 o 19.69520652863495,-98.56009687301638)
    final coordsReg = RegExp(
      r'(?<![\d.])([-+]?\d{1,2}\.\d{4,16})\s*,\s*([-+]?\d{1,3}\.\d{4,16})(?![\d.])',
    );
    final coordsMatch = coordsReg.firstMatch(text);
    if (coordsMatch != null) {
      final lat = coordsMatch.group(1)?.trim();
      final lng = coordsMatch.group(2)?.trim();
      if (lat != null && lng != null) {
        return 'https://www.google.com/maps?q=$lat,$lng';
      }
    }

    return null;
  }

  /// Detecta y extrae vehículos terceros (ej: "3o Audi A1", "3o kia gris", "3ro Versa")
  static List<String> _extractVehiculosTerceros(String text) {
    final results = <String>[];
    final lines = text.split(RegExp(r'[\r\n]+'));
    for (final line in lines) {
      final clean = line.trim();
      if (clean.isEmpty) continue;
      final match = RegExp(
        r'^(?:3[o°roª]|3er|tercero)\s*[:\-]?\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(clean);
      if (match != null && match.groupCount >= 1) {
        final val = match.group(1)?.trim();
        if (val != null && val.isNotEmpty) {
          results.add('3o $val');
        }
      }
    }
    return results;
  }

  /// Catálogo ampliado de submarcas y marcas populares en siniestros en México
  static const List<String> _submarcasMexicanas = [
    // Submarcas específicas
    'Groove', 'Tiigo', 'Tiggo', 'Frontier', 'Audi A1', 'Audi A3', 'Audi A4',
    'Versa', 'Aveo', 'Sentra', 'Vento', 'Jetta', 'March', 'Spark', 'Beat',
    'Rio', 'Forte', 'Onix', 'Swift', 'Hilux', 'NP300', 'Dmax', 'Ranger',
    'Trax', 'Kicks', 'CR-V', 'CRV', 'HR-V', 'HRV', 'RAV4', 'Seltos',
    'Ibiza', 'Toledo', 'Taos', 'Tiguan', 'Corolla', 'Yaris', 'Civic',
    'Lobo', 'Chevy', 'Tsuru', 'Pointer', 'Fit', 'Gol', 'Figo', 'Attitude',
    'Altima', 'Camry', 'Prius', 'Tracker', 'Suburban', 'Tahoe', 'Cavalier',
    'Ram', 'Stratus', 'Neon', 'Corsa', 'Astra', 'Tiida', 'X-Trail', 'Xtrail',
    'Creta', 'Tucson', 'Sportage', 'Sorento', 'Soul', 'K3', 'CX-3', 'CX-5', 'CX-30',
    'Mazda 2', 'Mazda 3', 'Urvan', 'Hiace', 'Transit', 'Saveiro', 'Tornado',
    'Captiva', 'Kwid', 'Duster', 'Stepway', 'Sandero', 'Oroch', 'Omoda',
    'MG5', 'MG GT', 'ZS', 'Raize', 'Avanza',
    // Marcas generales cuando se mencionan solas o seguidas de color
    'Nissan', 'Chevrolet', 'Volkswagen', 'VW', 'Toyota', 'Honda', 'Ford',
    'Mazda', 'Kia', 'Hyundai', 'Seat', 'Renault', 'Suzuki', 'Audi', 'BMW',
    'Mercedes', 'Chirey', 'MG', 'BYD', 'Geely',
  ];

  /// Diccionario de equivalencias de colores y abreviaturas comunes en cabina
  static const Map<String, String> _coloresAbreviados = {
    'bco': 'Blanco',
    'blco': 'Blanco',
    'blanco': 'Blanco',
    'white': 'Blanco',
    'neg': 'Negro',
    'ngro': 'Negro',
    'negro': 'Negro',
    'black': 'Negro',
    'grs': 'Gris',
    'gris': 'Gris',
    'gray': 'Gris',
    'grey': 'Gris',
    'oxford': 'Gris Oxford',
    'plta': 'Plata',
    'pte': 'Plata',
    'plata': 'Plata',
    'silver': 'Plata',
    'rjo': 'Rojo',
    'rojo': 'Rojo',
    'red': 'Rojo',
    'guinda': 'Rojo Guinda',
    'azl': 'Azul',
    'azul': 'Azul',
    'blue': 'Azul',
    'marino': 'Azul Marino',
    'vino': 'Vino',
    'tinto': 'Vino',
    'dorado': 'Dorado',
    'oro': 'Dorado',
    'gold': 'Dorado',
    'arena': 'Arena',
    'beige': 'Arena',
    'café': 'Café',
    'cafe': 'Café',
    'verde': 'Verde',
    'amarillo': 'Amarillo',
    'naranja': 'Naranja',
  };

  /// Extrae conjuntamente Marca/Submarca, Color y detecta nombres en la misma línea ("Mazda negro Alberto Gutierrez")
  static Map<String, String?> _extractVehiculoYColor(String text, String? placasKnown) {
    String? vehiculo;
    String? color;
    String? sameLineName;

    // 1. Revisión explícita con etiqueta
    final explicitVeh = RegExp(r'(?:veh[ií]culo|auto|unidad|coche)\s*[:\-]\s*([^\n\r]+)', caseSensitive: false);
    final matchVeh = explicitVeh.firstMatch(text);
    if (matchVeh != null && matchVeh.groupCount >= 1) {
      var val = matchVeh.group(1)?.trim() ?? '';
      if (placasKnown != null && placasKnown.isNotEmpty) val = val.replaceAll(placasKnown, '');
      val = val.split(RegExp(r'\b(placa[s]?|color|ubi|poliza)\b', caseSensitive: false)).first;
      if (val.trim().isNotEmpty) {
        vehiculo = val.trim().capitalizeWords();
      }
    }

    final explicitCol = RegExp(r'(?:color)\s*[:\-]?\s*([A-Za-zÁÉÍÓÚáéíóú]+)', caseSensitive: false);
    final matchCol = explicitCol.firstMatch(text);
    if (matchCol != null && matchCol.groupCount >= 1) {
      final rawCol = matchCol.group(1)?.trim().toLowerCase() ?? '';
      color = _coloresAbreviados[rawCol] ?? rawCol.capitalizeWords();
    }

    // 2. Búsqueda línea por línea (ej: "Versa bco", "Groove bco", "Mazda negro Alberto Gutierrez")
    final lines = text.split(RegExp(r'[\r\n]+'));
    for (final line in lines) {
      final cleanLine = line.trim();
      if (cleanLine.isEmpty) continue;

      // Omitir líneas de terceros para no confundir con el vehículo asegurado
      if (RegExp(r'^(?:3[o°roª]|3er|tercero)\b', caseSensitive: false).hasMatch(cleanLine)) {
        continue;
      }

      final lower = cleanLine.toLowerCase();

      for (final sub in _submarcasMexicanas) {
        final subPattern = RegExp('\\b${RegExp.escape(sub.toLowerCase())}\\b', caseSensitive: false);
        if (subPattern.hasMatch(lower)) {
          vehiculo ??= sub;

          // Extraer año si viene junto (ej: "Versa 2021")
          final yearMatch = RegExp(r'\b(20\d{2}|19\d{2})\b').firstMatch(cleanLine);
          if (yearMatch != null) {
            vehiculo = '$vehiculo ${yearMatch.group(1)}';
          }

          // Extraer color de la misma línea (ej: "bco", "neg", "rojo", "naranja")
          String? detectedColorKey;
          if (color == null) {
            for (final entry in _coloresAbreviados.entries) {
              if (RegExp('\\b${RegExp.escape(entry.key)}\\b').hasMatch(lower)) {
                color = entry.value;
                detectedColorKey = entry.key;
                break;
              }
            }
          }

          // Extraer nombre de persona en la misma línea (ej: "Mazda negro Alberto Gutierrez")
          var remainder = cleanLine;
          remainder = remainder.replaceAll(subPattern, '');
          if (detectedColorKey != null) {
            remainder = remainder.replaceAll(RegExp('\\b$detectedColorKey\\b', caseSensitive: false), '');
          }
          if (yearMatch != null) {
            remainder = remainder.replaceAll(yearMatch.group(0)!, '');
          }
          remainder = remainder.replaceAll(RegExp(r'[,.\-_:;]'), ' ').cleanWhitespace();

          // Verificar si lo que queda parece un nombre propio (2 a 4 palabras, solo letras)
          if (remainder.isNotEmpty) {
            final words = remainder.split(RegExp(r'\s+'));
            if (words.length >= 2 && words.length <= 4) {
              final allLetters = words.every((w) => RegExp(r'^[A-Za-zÁÉÍÓÚáéíóúñÑüÜ]+$').hasMatch(w));
              final lowerRem = remainder.toLowerCase();
              final notNoise = !['choque', 'robo', 'cristal', 'semoviente', 'inbursa', 'dir', 'pachuca', 'hidalgo'].any((k) => lowerRem.contains(k));
              if (allLetters && notNoise) {
                sameLineName = remainder.capitalizeWords();
              }
            }
          }
          break;
        }
      }
      if (vehiculo != null) break;
    }

    // 3. Si el color aún no se encuentra, buscar en todo el texto
    if (color == null) {
      final lowerFull = text.toLowerCase();
      for (final entry in _coloresAbreviados.entries) {
        if (RegExp('\\b${RegExp.escape(entry.key)}\\b').hasMatch(lowerFull)) {
          color = entry.value;
          break;
        }
      }
    }

    return {
      'vehiculo': vehiculo,
      'color': color,
      'sameLineName': sameLineName,
    };
  }

  /// Extrae el Nombre del Asegurado / Reportante
  static String? _extractAsegurado(String text, String? knownAjustador, String? sameLineName) {
    // 1. Patrón con etiqueta explícita (Asegurado, Conductor, Cliente, Reportante)
    final explicitPattern = RegExp(
      r'(?:asegurado|conductor|cliente|nombre|reportante|contacto)\s*[:\-]\s*([^\n\r,]+)',
      caseSensitive: false,
    );
    final match = explicitPattern.firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      final val = match.group(1)?.trim();
      if (val != null && val.isNotEmpty && val.length > 2) {
        final cleanVal = val.split(RegExp(r'\b(tel|cel|auto|vehiculo|placa|ubicacion)\b', caseSensitive: false)).first;
        return cleanVal.trim().capitalizeWords();
      }
    }

    // 2. Si venía en la misma línea del vehículo (ej: "Mazda negro Alberto Gutierrez")
    if (sameLineName != null && sameLineName.isNotEmpty) {
      return sameLineName;
    }

    // 3. Líneas aisladas que contienen nombres de persona (ej: "Esteban Pérez", "Daniel Rojas")
    final lines = text.split(RegExp(r'[\r\n]+'));
    final candidates = <String>[];

    final staffNames = [
      'alejandro chavez',
      'alejandro',
      'armando',
      'sergio sanchez',
      'sergio',
      'andres gudiño',
      'andres gudino',
      'andres',
      'luis',
      'axel',
      'ian',
      'luis roberto',
    ];

    final excludeTokens = [
      'inbursa', 'mapfre', 'crabi', 'seguros', 'qualitas', 'quálitas',
      'pachuca', 'sahagun', 'sahagún', 'tulancingo', 'atlacomulco',
      'despacho', 'cabina', 'cabinero', 'vas ', 'porfa', 'voy', 'semoviente',
      'choque', 'robo', 'cristal', 'diverso', 'asistencia', 'siniestro',
      'folio', 'reporte', 'atender', 'postular', 'administrador',
      'versa', 'aveo', 'jetta', 'march', 'vento', 'sentra', 'nissan',
      'chevrolet', 'volkswagen', 'toyota', 'ford', 'honda', 'bco', 'blanco',
      'negro', 'rojo', 'azul', 'gris', 'plata', 'naranja', 'dir ', 'autopista',
      'arco norte', '3o', '3ro', '3er', 'tercero', 'te formó', 'te formo', 'te tocó',
    ];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('http') || RegExp(r'\d').hasMatch(trimmed) || trimmed.startsWith('@')) {
        continue;
      }
      if (knownAjustador != null && trimmed.toLowerCase().contains(knownAjustador.toLowerCase())) {
        continue;
      }

      final lower = trimmed.toLowerCase();
      if (excludeTokens.any((w) => lower.contains(w))) {
        continue;
      }

      final isStaff = staffNames.any((s) => lower == s || lower.startsWith('$s '));
      if (isStaff) {
        continue;
      }

      // Validar formato de nombre propio (2 a 4 palabras compuestas únicamente de letras)
      final words = trimmed.split(RegExp(r'\s+'));
      if (words.length >= 2 && words.length <= 4) {
        final allLetters = words.every((w) => RegExp(r'^[A-Za-zÁÉÍÓÚáéíóúñÑüÜ]+$').hasMatch(w));
        if (allLetters) {
          candidates.add(trimmed.capitalizeWords());
        }
      }
    }

    if (candidates.isEmpty) return null;
    return candidates.last;
  }

  /// Extrae placas del vehículo
  static String? _extractPlacas(String text) {
    final patterns = [
      RegExp(r'(?:placa[s]?|matr[ií]cula)\s*[:\-]?\s*([A-Za-z0-9\-]{4,10})', caseSensitive: false),
      RegExp(r'\b([A-Z]{3}-?\d{2}-?\d{2}|[A-Z]{3}-?\d{4}|\d{3}-?[A-Z]{3}|[A-Z]{3}-?\d{3}-[A-Z])\b'),
    ];

    for (final reg in patterns) {
      final match = reg.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final val = match.group(1)?.trim();
        if (val != null && val.isNotEmpty) {
          return val.toUpperCase();
        }
      }
    }
    return null;
  }

  /// Extrae Póliza
  static String? _extractPoliza(String text) {
    final pattern = RegExp(r'(?:p[oó]liza)\s*[:\-]?\s*([A-Za-z0-9\-]{5,20})', caseSensitive: false);
    final match = pattern.firstMatch(text);
    return match?.group(1)?.trim();
  }

  /// Extrae Referencias viales directas (ej: "Vete por la mexico pachuca", "La pachuca sahagun esta cerrada")
  static String? _extractReferencias(String text) {
    final refPatterns = [
      RegExp(r'(?:vete por|toma|carretera|autopista|cerrada|frente a|esquina|cerca de)\s+[^\n\r]+', caseSensitive: false),
      RegExp(r'(?:referencia|ref)\s*[:\-]\s*([^\n\r]+)', caseSensitive: false),
    ];

    final found = <String>[];
    for (final reg in refPatterns) {
      final matches = reg.allMatches(text);
      for (final m in matches) {
        final val = (m.groupCount >= 1 ? m.group(1) : m.group(0))?.trim();
        if (val != null && val.isNotEmpty && !val.startsWith('http')) {
          final lower = val.toLowerCase();
          if (lower.contains('colonia c.p') || lower.contains('colonia cp') || lower == 'esquina') {
            continue;
          }
          found.add(val.cleanWhitespace());
        }
      }
    }

    if (found.isNotEmpty) {
      return found.join(' • ');
    }
    return null;
  }

  /// Extrae Ubicación textual general
  static String? _extractUbicacion(String text) {
    final patterns = [
      RegExp(r'(?:ubicaci[oó]n|lugar|direcci[oó]n|sitio)\s*[:\-]\s*([^\n\r]+)', caseSensitive: false),
      RegExp(r'(?:calle|av(?:enida)?|perif[eé]rico|calzada|autopista|carretera)\s+[^\n\r]+', caseSensitive: false),
    ];

    for (final reg in patterns) {
      final match = reg.firstMatch(text);
      if (match != null) {
        final val = (match.groupCount >= 1 ? match.group(1) : match.group(0))?.trim();
        if (val != null && val.isNotEmpty && !val.startsWith('http')) {
          return val.cleanWhitespace();
        }
      }
    }
    return null;
  }

  /// Deduce Municipio y Estado si se mencionan en el texto o referencias
  static Map<String, String?> _deduceMunicipioEstado(String text) {
    final lower = text.toLowerCase();
    String? estado;
    String? municipio;

    if (lower.contains('pachuca') || lower.contains('sahagun') || lower.contains('hidalgo') || lower.contains('tulancingo') || lower.contains('tizayuca')) {
      estado = 'Hidalgo';
      if (lower.contains('pachuca')) municipio = 'Pachuca';
      if (lower.contains('sahagun')) municipio = 'Tepeapulco (Cd. Sahagún)';
      if (lower.contains('tizayuca')) municipio = 'Tizayuca';
      if (lower.contains('tulancingo')) municipio = 'Tulancingo';
    } else if (lower.contains('edomex') || lower.contains('méxico') || lower.contains('mexico') || lower.contains('tlalnepantla') || lower.contains('ecatepec') || lower.contains('naucalpan')) {
      estado = 'Estado de México';
      if (lower.contains('tlalnepantla')) municipio = 'Tlalnepantla';
      if (lower.contains('ecatepec')) municipio = 'Ecatepec';
      if (lower.contains('naucalpan')) municipio = 'Naucalpan';
    } else if (lower.contains('cdmx') || lower.contains('insurgentes') || lower.contains('periferico') || lower.contains('reforma')) {
      estado = 'CDMX';
    }

    return {'municipio': municipio, 'estado': estado};
  }

  /// Extrae Tipo de Evento (Choque, Robo, Cristal, Diverso, Otro) y detalle específico (ej: Semoviente)
  static Map<String, String> _extractTipoEvento(String text) {
    final lower = text.toLowerCase();

    // Eventos Diversos en Carretera / Autopista (Semoviente, animales, baches, desastres)
    if (lower.contains('semoviente') ||
        lower.contains('animal') ||
        lower.contains('vaca') ||
        lower.contains('caballo') ||
        lower.contains('perro') ||
        lower.contains('bache') ||
        lower.contains('arbol') ||
        lower.contains('árbol') ||
        lower.contains('derrape') ||
        lower.contains('piedra') ||
        lower.contains('inundaci') ||
        lower.contains('vandalismo') ||
        lower.contains('granizo') ||
        lower.contains('rayo') ||
        lower.contains('asistencia') ||
        lower.contains('grua') ||
        lower.contains('grúa') ||
        lower.contains('bateria') ||
        lower.contains('gasolina')) {
      String detalle = 'Diverso';
      if (lower.contains('semoviente')) {
        detalle = 'Semoviente';
      } else if (lower.contains('animal') || lower.contains('vaca') || lower.contains('caballo')) {
        detalle = 'Impacto Semoviente';
      } else if (lower.contains('bache')) {
        detalle = 'Caída en Bache';
      } else if (lower.contains('arbol') || lower.contains('árbol')) {
        detalle = 'Caída de Árbol';
      } else if (lower.contains('derrape')) {
        detalle = 'Derrape';
      } else if (lower.contains('asistencia') || lower.contains('grua') || lower.contains('grúa')) {
        detalle = 'Asistencia Vial';
      }
      return {'tipo': 'Diverso', 'detalle': detalle};
    }

    if (lower.contains('choque') ||
        lower.contains('colision') ||
        lower.contains('colisión') ||
        lower.contains('alcance') ||
        lower.contains('volcadura') ||
        lower.contains('impacto')) {
      return {'tipo': 'Choque', 'detalle': 'Choque'};
    }

    if (lower.contains('robo') || lower.contains('asalto') || lower.contains('despojo')) {
      return {'tipo': 'Robo', 'detalle': 'Robo'};
    }

    if (lower.contains('cristal') ||
        lower.contains('parabrisas') ||
        lower.contains('medallon') ||
        lower.contains('medallón') ||
        lower.contains('vidrio')) {
      return {'tipo': 'Cristal', 'detalle': 'Cristal'};
    }

    return {'tipo': 'Choque', 'detalle': ''};
  }

  /// Extrae Observaciones adicionales
  static String? _extractObservaciones(String text) {
    final pattern = RegExp(r'(?:observaciones|notas?|comentario)\s*[:\-]\s*([^\n\r]+)', caseSensitive: false);
    final match = pattern.firstMatch(text);
    return match?.group(1)?.trim();
  }
}
