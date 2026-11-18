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
      (vehiculo != null && vehiculo!.isNotEmpty) ||
      (municipio != null && municipio!.isNotEmpty) ||
      (linkMaps != null && linkMaps!.isNotEmpty) ||
      (referencias != null && referencias!.isNotEmpty);
}

/// Servicio inteligente de extracción tolerante a mensajes formales de cabina
/// y mensajes fragmentados/reenviados típicos de chats operativos de WhatsApp
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

    // Reconstruir enlaces Maps del texto limpio o del original (SOLO si realmente existen en el texto)
    final linkMaps = _extractMapsUrl(cleanedText) ?? _extractMapsUrl(rawText);
    final folio = _extractFolio(cleanedText);
    final aseguradora = _extractAseguradora(cleanedText, folio);
    final ajustador = _extractAjustador(cleanedText);
    final telefono = _extractTelefono(cleanedText);
    final placas = _extractPlacas(cleanedText);
    
    // Extracción de vehículo y color soportando submarcas populares y abreviaturas ("Versa bco")
    final vehiculoColor = _extractVehiculoYColor(cleanedText, placas);
    final vehiculo = vehiculoColor['vehiculo'];
    final color = vehiculoColor['color'];

    final eventoInfo = _extractTipoEvento(cleanedText);
    final tipoEvento = eventoInfo['tipo'];
    final detalleEvento = eventoInfo['detalle'];

    final asegurado = _extractAsegurado(cleanedText, ajustador);
    final poliza = _extractPoliza(cleanedText);
    final referencias = _extractReferencias(cleanedText);
    final ubicacion = _extractUbicacion(cleanedText);

    // Integración de observaciones con Cabinero y horas Inbursa
    var observaciones = _extractObservaciones(cleanedText);
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

    // IMPORTANTE: NO inventar enlace de Google Maps si el mensaje original no traía uno
    final linkMapsFinal = linkMaps;

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
      linkMaps: linkMapsFinal,
      tipoEvento: tipoEvento,
      detalleEvento: detalleEvento,
      horaReporte: horaReporte,
      horaAsignacion: horaAsignacion,
      observaciones: observaciones,
      rawText: rawText,
    );
  }

  /// Limpieza especializada de ruido OCR (timestamps, reenvíos, metadatos de chat)
  static String _cleanOcrNoise(String rawText) {
    if (rawText.trim().isEmpty) return '';

    var text = rawText.replaceAll('*', '');

    // Reconstruir URLs de Google Maps partidas en dos líneas por el OCR
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
    // 1. Patrones explícitos con etiqueta
    final explicitPatterns = [
      RegExp(r'(?:folio|siniestro|reporte|expediente|orden)\s*[:#\-]?\s*([A-Za-z0-9\-_/]{4,20})', caseSensitive: false),
      RegExp(r'\b((?:INB|MPF|CRB|SPT|QUAL|GNP|AXA|HDI)[A-Za-z0-9\-_]{4,15})\b', caseSensitive: false),
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

    // 2. Líneas aisladas que contienen únicamente un número de 6 a 9 dígitos (ej: "3059238")
    final lines = text.split(RegExp(r'[\r\n]+'));
    for (final line in lines) {
      final cleanLine = line.trim();
      if (RegExp(r'^\d{6,9}$').hasMatch(cleanLine)) {
        return cleanLine;
      }
    }

    // 3. Fallback: buscar cualquier bloque numérico de 6 a 8 dígitos en el texto
    final numMatch = RegExp(r'\b(\d{6,8})\b').firstMatch(text);
    if (numMatch != null) {
      return numMatch.group(1);
    }

    return null;
  }

  /// Extrae la Aseguradora normalizada
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
      // Folios típicos de Inbursa de 7 dígitos que inician con 30 (ej. 3059330, 3059238, 3059329)
      if (RegExp(r'^30\d{5}$').hasMatch(folio)) return 'Inbursa';
    }

    return null;
  }

  /// Extrae menciones de ajustadores en el chat (ej: "Vas @Sergio Sanchez", "@Andres Gudiño")
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

    // Buscar mención explícita con arroba: @Nombre
    final mentionMatch = RegExp(r'@([A-Za-zÁÉÍÓÚáéíóúñÑ]+(?:\s+[A-Za-zÁÉÍÓÚáéíóúñÑ]+)?)').firstMatch(text);
    if (mentionMatch != null) {
      final mentioned = mentionMatch.group(1)?.trim();
      if (mentioned != null && mentioned.isNotEmpty) {
        for (final aj in adjustersPool) {
          if (mentioned.toLowerCase().contains(aj.toLowerCase()) || aj.toLowerCase().contains(mentioned.toLowerCase())) {
            return aj;
          }
        }
        return mentioned;
      }
    }

    // Buscar nombres de ajustadores conocidos precedidos por palabras clave
    for (final aj in adjustersPool) {
      final reg = RegExp('(?:vas|porfa|atiende|asigna|le toca a)\\s+@?(${RegExp.escape(aj)})', caseSensitive: false);
      final match = reg.firstMatch(text);
      if (match != null) {
        return aj;
      }
    }

    return null;
  }

  /// Extrae el Nombre del Asegurado / Reportante
  static String? _extractAsegurado(String text, String? knownAjustador) {
    // 1. Patrón con etiqueta explícita (incluyendo Cabinero)
    final explicitPattern = RegExp(
      r'(?:asegurado|conductor|cliente|nombre|reportante|contacto|cabinero)\s*[:\-]\s*([^\n\r,]+)',
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

    // 2. Líneas aisladas que contienen nombres de persona (ej: "Esteban Pérez", "Daniel Rojas")
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
      'despacho', 'cabina', 'vas ', 'porfa', 'voy', 'semoviente',
      'choque', 'robo', 'cristal', 'diverso', 'asistencia', 'siniestro',
      'folio', 'reporte', 'atender', 'postular', 'administrador',
      'versa', 'aveo', 'jetta', 'march', 'vento', 'sentra', 'nissan',
      'chevrolet', 'volkswagen', 'toyota', 'ford', 'honda', 'bco', 'blanco',
      'negro', 'rojo', 'azul', 'gris', 'plata', 'dir ', 'autopista', 'arco norte',
    ];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Descartar si es un enlace, si tiene números, o si es mención con @ o emoji
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

  /// Extrae el Teléfono de contacto
  static String? _extractTelefono(String text) {
    final patterns = [
      RegExp(r'(?:tel(?:[eé]fono)?|cel(?:ular)?|contacto|whats(?:app)?)\s*[:\-]?\s*([+0-9\s\-()]{8,20})', caseSensitive: false),
      RegExp(r'\b(55\d{8}|56\d{8}|77\d{8}|[1-9]\d{9})\b'),
    ];

    for (final reg in patterns) {
      final match = reg.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final val = match.group(1)?.trim();
        if (val != null) {
          final digits = val.replaceAll(RegExp(r'\D'), '');
          if (digits.length == 10) {
            return digits;
          }
        }
      }
    }
    return null;
  }

  /// Extrae el link de Google Maps (completo o reconstruido de líneas separadas)
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

    return null;
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

  /// Catálogo de submarcas más comunes en siniestros en México
  static const List<String> _submarcasMexicanas = [
    'Versa', 'Aveo', 'Sentra', 'Vento', 'Jetta', 'March', 'Spark', 'Beat',
    'Rio', 'Forte', 'Onix', 'Swift', 'Hilux', 'NP300', 'Dmax', 'Ranger',
    'Trax', 'Kicks', 'CR-V', 'CRV', 'HR-V', 'HRV', 'RAV4', 'Seltos',
    'Ibiza', 'Toledo', 'Taos', 'Tiguan', 'Corolla', 'Yaris', 'Civic',
    'Lobo', 'Chevy', 'Tsuru', 'Pointer', 'Fit', 'Gol', 'Figo', 'Attitude',
    'Frontier', 'Altima', 'Camry', 'Prius', 'Tracker', 'Suburban', 'Tahoe',
    'Ram', 'Stratus', 'Neon', 'Corsa', 'Astra', 'Tiida', 'X-Trail', 'Xtrail',
    'Creta', 'Tucson', 'Sportage', 'Sorento', 'CX-3', 'CX-5', 'CX-30',
    'Mazda 2', 'Mazda 3', 'Urvan', 'Hiace', 'Transit', 'Saveiro', 'Tornado',
    'Captiva', 'Groove', 'Kwid', 'Duster', 'Stepway', 'Sandero', 'Oroch',
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

  /// Extrae conjuntamente Marca / Submarca y Color del vehículo tolerando "Versa bco", abreviaturas y modelos sin marca
  static Map<String, String?> _extractVehiculoYColor(String text, String? placasKnown) {
    String? vehiculo;
    String? color;

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

    // 2. Búsqueda línea por línea (ej: "Versa bco", "Jetta negro", "Aveo gris 2020")
    final lines = text.split(RegExp(r'[\r\n]+'));
    for (final line in lines) {
      final cleanLine = line.trim();
      if (cleanLine.isEmpty) continue;
      final lower = cleanLine.toLowerCase();

      // Verificar si la línea contiene alguna de las submarcas mexicanas
      for (final sub in _submarcasMexicanas) {
        if (RegExp('\\b${RegExp.escape(sub.toLowerCase())}\\b').hasMatch(lower)) {
          vehiculo ??= sub;

          // Extraer año si viene junto (ej: "Versa 2021")
          final yearMatch = RegExp(r'\b(20\d{2}|19\d{2})\b').firstMatch(cleanLine);
          if (yearMatch != null) {
            vehiculo = '$vehiculo ${yearMatch.group(1)}';
          }

          // Extraer color de la misma línea (ej: "bco", "neg", "rojo")
          if (color == null) {
            for (final entry in _coloresAbreviados.entries) {
              if (RegExp('\\b${RegExp.escape(entry.key)}\\b').hasMatch(lower)) {
                color = entry.value;
                break;
              }
            }
          }
          break;
        }
      }
      if (vehiculo != null) break;
    }

    // 3. Fallback marcas globales clásicas ("Nissan Versa", "Toyota Corolla", "BMW")
    if (vehiculo == null) {
      final marcas = [
        'Nissan', 'Chevrolet', 'Volkswagen', 'VW', 'Toyota', 'Honda', 'Ford',
        'Mazda', 'Kia', 'Hyundai', 'Seat', 'Renault', 'Suzuki', 'BMW', 'Mercedes'
      ];
      for (final m in marcas) {
        final reg = RegExp('\\b($m(?:\\s+[A-Za-z0-9]+)?(?:\\s+\\d{4})?)', caseSensitive: false);
        final mMatch = reg.firstMatch(text);
        if (mMatch != null) {
          vehiculo = mMatch.group(1)?.trim().capitalizeWords();
          break;
        }
      }
    }

    // 4. Si el color aún no se encuentra, buscar en todo el texto
    if (color == null) {
      final lowerFull = text.toLowerCase();
      for (final entry in _coloresAbreviados.entries) {
        if (RegExp('\\b${RegExp.escape(entry.key)}\\b').hasMatch(lowerFull)) {
          color = entry.value;
          break;
        }
      }
    }

    return {'vehiculo': vehiculo, 'color': color};
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
          // Descartar encabezados de tablas impresas de cabina (ej: "Esquina colonia C.P")
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
