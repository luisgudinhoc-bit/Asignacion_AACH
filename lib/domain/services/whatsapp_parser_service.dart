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
    this.observaciones,
    required this.rawText,
  });

  bool get hasContent =>
      (folio != null && folio!.isNotEmpty) ||
      (aseguradora != null && aseguradora!.isNotEmpty) ||
      (ajustador != null && ajustador!.isNotEmpty) ||
      (asegurado != null && asegurado!.isNotEmpty) ||
      (placas != null && placas!.isNotEmpty) ||
      (ubicacion != null && ubicacion!.isNotEmpty) ||
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

    // Etapa 1: Limpieza profunda de ruido de capturas OCR y chat de WhatsApp
    final cleanedText = _cleanOcrNoise(rawText);

    // Reconstruir enlaces Maps del texto limpio o del original
    final linkMaps = _extractMapsUrl(cleanedText) ?? _extractMapsUrl(rawText);
    final aseguradora = _extractAseguradora(cleanedText);
    final folio = _extractFolio(cleanedText);
    final ajustador = _extractAjustador(cleanedText);
    final telefono = _extractTelefono(cleanedText);
    final asegurado = _extractAsegurado(cleanedText, ajustador);
    final placas = _extractPlacas(cleanedText);
    final vehiculo = _extractVehiculo(cleanedText, placas);
    final color = _extractColor(cleanedText);
    final poliza = _extractPoliza(cleanedText);
    final tipoEvento = _extractTipoEvento(cleanedText);
    final referencias = _extractReferencias(cleanedText);
    final ubicacion = _extractUbicacion(cleanedText);
    final observaciones = _extractObservaciones(cleanedText);

    // Deducir Municipio y Estado a partir de referencias o ubicación
    final locGeo = _deduceMunicipioEstado(ubicacion ?? referencias ?? '');

    // Detección especializada para Autopista Arco Norte por Kilometraje
    final arcoMatch = ArcoNorteService.findKmInText('$rawText ${referencias ?? ""} ${ubicacion ?? ""}');
    final municipioFinal = locGeo['municipio'] ?? arcoMatch?.localidad;
    final estadoFinal = locGeo['estado'] ?? arcoMatch?.estado;
    final linkMapsFinal = linkMaps ?? arcoMatch?.linkGoogleMaps;
    final referenciasFinal = referencias ?? (arcoMatch != null ? 'Autopista Arco Norte Km ${arcoMatch.kilometro.toStringAsFixed(0)} (${arcoMatch.tramoDescripcion}) CP ${arcoMatch.codigoPostal}' : null);

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
  static String? _extractAseguradora(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('inbursa')) return 'Inbursa';
    if (lower.contains('mapfre')) return 'Mapfre';
    if (lower.contains('crabi')) return 'Crabi';
    if (lower.contains('spt')) return 'SPT Seguros';
    if (lower.contains('otra') || lower.contains('otro')) return 'Otra Compañía';

    // Compatibilidad adicional
    if (lower.contains('qualitas') || lower.contains('quálitas')) return 'Quálitas';
    if (lower.contains('gnp')) return 'GNP Seguros';
    if (lower.contains('axa')) return 'AXA Seguros';
    if (lower.contains('hdi')) return 'HDI Seguros';
    if (lower.contains('chubb')) return 'Chubb Seguros';

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
    // 1. Patrón con etiqueta explícita
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

    // 2. Líneas aisladas que contienen nombres de persona (ej: "Daniel Rojas")
    final lines = text.split(RegExp(r'[\r\n]+'));
    final candidates = <String>[];

    // Personal operativo y coordinadores que no deben confundirse con el asegurado
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
    ];

    for (final line in lines) {
      final trimmed = line.trim();
      // Descartar si es un enlace, si tiene números, o si es mención con @
      if (trimmed.startsWith('http') || RegExp(r'\d').hasMatch(trimmed) || trimmed.startsWith('@')) {
        continue;
      }
      if (knownAjustador != null && trimmed.toLowerCase().contains(knownAjustador.toLowerCase())) {
        continue;
      }

      final lower = trimmed.toLowerCase();
      if (lower.contains('inbursa') ||
          lower.contains('mapfre') ||
          lower.contains('crabi') ||
          lower.contains('seguros') ||
          lower.contains('qualitas') ||
          lower.contains('quálitas') ||
          lower.contains('pachuca') ||
          lower.contains('sahagun') ||
          lower.contains('sahagún') ||
          lower.contains('despacho') ||
          lower.contains('cabina') ||
          lower.startsWith('vas ') ||
          lower.startsWith('porfa') ||
          lower == 'voy') {
        continue;
      }

      // Descartar si coincide con el staff del despacho
      final isStaff = staffNames.any((s) => lower == s || lower.startsWith('$s '));
      if (isStaff) {
        continue;
      }

      // Validar formato de nombre propio (2 a 4 palabras capitalizadas, ej: "Daniel Rojas")
      if (RegExp(r'^[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+(?:\s+[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+){1,3}$').hasMatch(trimmed)) {
        candidates.add(trimmed.capitalizeWords());
      }
    }

    if (candidates.isEmpty) return null;

    // Si hay más de un candidato, preferir el que esté más abajo en el chat
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

  /// Extrae Marca, Submarca o Modelo
  static String? _extractVehiculo(String text, String? placasKnown) {
    final explicitPattern = RegExp(r'(?:veh[ií]culo|auto|unidad|coche)\s*[:\-]\s*([^\n\r]+)', caseSensitive: false);
    final match = explicitPattern.firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      var val = match.group(1)?.trim() ?? '';
      if (placasKnown != null && placasKnown.isNotEmpty) {
        val = val.replaceAll(placasKnown, '');
      }
      val = val.split(RegExp(r'\b(placa[s]?|color|ubi|poliza)\b', caseSensitive: false)).first;
      if (val.trim().isNotEmpty) {
        return val.trim().capitalizeWords();
      }
    }

    final marcas = [
      'Nissan', 'Chevrolet', 'Volkswagen', 'VW', 'Toyota', 'Honda', 'Ford',
      'Mazda', 'Kia', 'Hyundai', 'Seat', 'Renault', 'Suzuki', 'BMW'
    ];
    for (final m in marcas) {
      final reg = RegExp('\\b($m\\s+[A-Za-z0-9]+(?:\\s+\\d{4})?)', caseSensitive: false);
      final mMatch = reg.firstMatch(text);
      if (mMatch != null) {
        return mMatch.group(1)?.trim().capitalizeWords();
      }
    }
    return null;
  }

  /// Extrae el Color
  static String? _extractColor(String text) {
    final pattern = RegExp(r'(?:color)\s*[:\-]?\s*([A-Za-zÁÉÍÓÚáéíóú]+)', caseSensitive: false);
    final match = pattern.firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)?.trim().capitalizeWords();
    }
    final colores = ['Blanco', 'Negro', 'Gris', 'Plata', 'Rojo', 'Azul', 'Vino', 'Arena', 'Verde'];
    for (final col in colores) {
      if (RegExp('\\b$col\\b', caseSensitive: false).hasMatch(text)) {
        return col;
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

  /// Extrae Tipo de Evento
  static String? _extractTipoEvento(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('choque') || lower.contains('colision') || lower.contains('alcance')) return 'Choque';
    if (lower.contains('robo')) return 'Robo';
    if (lower.contains('cristal')) return 'Cristal';
    if (lower.contains('asistencia') || lower.contains('grua') || lower.contains('grúa') || lower.contains('bateria') || lower.contains('gasolina')) return 'Asistencia Vial';
    if (lower.contains('tercero')) return 'Daños a Terceros';
    return null;
  }

  /// Extrae Observaciones adicionales
  static String? _extractObservaciones(String text) {
    final pattern = RegExp(r'(?:observaciones|notas?|comentario)\s*[:\-]\s*([^\n\r]+)', caseSensitive: false);
    final match = pattern.firstMatch(text);
    return match?.group(1)?.trim();
  }
}
