import '../../core/constants/app_constants.dart';
import '../../core/utils/string_extensions.dart';

/// Resultado estructurado del análisis de un mensaje de cabina
class ParsedCabinaMessage {
  final String? folio;
  final String? aseguradora;
  final String? asegurado;
  final String? telefonoAsegurado;
  final String? vehiculo;
  final String? colorVehiculo;
  final String? placas;
  final String? poliza;
  final String? ubicacion;
  final String? linkMaps;
  final String? tipoEvento;
  final String? observaciones;
  final String rawText;

  const ParsedCabinaMessage({
    this.folio,
    this.aseguradora,
    this.asegurado,
    this.telefonoAsegurado,
    this.vehiculo,
    this.colorVehiculo,
    this.placas,
    this.poliza,
    this.ubicacion,
    this.linkMaps,
    this.tipoEvento,
    this.observaciones,
    required this.rawText,
  });

  bool get hasContent =>
      (folio != null && folio!.isNotEmpty) ||
      (aseguradora != null && aseguradora!.isNotEmpty) ||
      (asegurado != null && asegurado!.isNotEmpty) ||
      (placas != null && placas!.isNotEmpty) ||
      (ubicacion != null && ubicacion!.isNotEmpty);

  @override
  String toString() {
    return 'ParsedCabinaMessage(folio: $folio, cia: $aseguradora, asegurado: $asegurado, tel: $telefonoAsegurado, auto: $vehiculo, color: $colorVehiculo, placas: $placas, poliza: $poliza, maps: $linkMaps)';
  }
}

/// Servicio inteligente de extracción por expresiones regulares para mensajes de cabina de aseguradoras
class WhatsAppParserService {
  /// Analiza el texto completo de un mensaje pegado desde WhatsApp y extrae los campos
  static ParsedCabinaMessage parse(String rawText) {
    if (rawText.trim().isEmpty) {
      return const ParsedCabinaMessage(rawText: '');
    }

    final cleanText = rawText.replaceAll('*', ''); // Remueve negritas de WhatsApp

    final linkMaps = _extractMapsUrl(cleanText);
    final aseguradora = _extractAseguradora(cleanText);
    final folio = _extractFolio(cleanText);
    final telefono = _extractTelefono(cleanText);
    final asegurado = _extractAsegurado(cleanText);
    final placas = _extractPlacas(cleanText);
    final vehiculo = _extractVehiculo(cleanText, placas);
    final color = _extractColor(cleanText);
    final poliza = _extractPoliza(cleanText);
    final ubicacion = _extractUbicacion(cleanText);
    final tipoEvento = _extractTipoEvento(cleanText);
    final observaciones = _extractObservaciones(cleanText);

    return ParsedCabinaMessage(
      folio: folio,
      aseguradora: aseguradora,
      asegurado: asegurado,
      telefonoAsegurado: telefono,
      vehiculo: vehiculo,
      colorVehiculo: color,
      placas: placas,
      poliza: poliza,
      ubicacion: ubicacion,
      linkMaps: linkMaps,
      tipoEvento: tipoEvento,
      observaciones: observaciones,
      rawText: rawText,
    );
  }

  /// Extrae el Folio o Número de Siniestro
  static String? _extractFolio(String text) {
    final patterns = [
      // REPORTE: 123456 / FOLIO: 123456 / SINIESTRO: 123456 / REPORTE CABINA # 123456
      RegExp(
        r'(?:folio|siniestro|reporte|reporte\s+cabina|num(?:ero)?\s+siniestro|expediente|orden)\s*(?:de\s+siniestro)?\s*[:#\-]?\s*([A-Za-z0-9\-_/]{4,20})',
        caseSensitive: false,
      ),
      // Prefijos conocidos como QUAL-123456, GNP-123456, INB-123456, 0424123456
      RegExp(
        r'\b((?:QUAL|GNP|INB|AXA|HDI|CHB|MAP|04)[A-Za-z0-9\-_]{4,15})\b',
        caseSensitive: false,
      ),
    ];

    for (final reg in patterns) {
      final match = reg.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final val = match.group(1)?.trim();
        if (val != null && val.isNotEmpty && !val.toLowerCase().contains('cabina')) {
          return val.toUpperCase();
        }
      }
    }
    return null;
  }

  /// Extrae y normaliza la aseguradora contra el catálogo oficial
  static String? _extractAseguradora(String text) {
    final lower = text.toLowerCase();

    for (final cia in AppConstants.defaultAseguradoras) {
      final ciaKey = cia.toLowerCase().replaceAll(' seguros', '').trim();
      if (lower.contains(ciaKey)) {
        return cia;
      }
    }

    if (lower.contains('qualitas') || lower.contains('quálitas')) return 'Quálitas';
    if (lower.contains('gnp')) return 'GNP Seguros';
    if (lower.contains('inbursa')) return 'Inbursa';
    if (lower.contains('axa')) return 'AXA Seguros';
    if (lower.contains('hdi')) return 'HDI Seguros';
    if (lower.contains('chubb')) return 'Chubb Seguros';
    if (lower.contains('mapfre')) return 'Mapfre';
    if (lower.contains('banorte')) return 'Banorte';
    if (lower.contains('afirme')) return 'Afirme';
    if (lower.contains('atlas')) return 'Atlas';
    if (lower.contains('zurich')) return 'Zurich';

    return null;
  }

  /// Extrae el Nombre del Asegurado / Conductor
  static String? _extractAsegurado(String text) {
    final patterns = [
      RegExp(
        r'(?:asegurado|conductor|cliente|nombre|reportante|contacto)\s*[:\-]\s*([^\n\r,]+)',
        caseSensitive: false,
      ),
    ];

    for (final reg in patterns) {
      final match = reg.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final val = match.group(1)?.trim();
        if (val != null && val.isNotEmpty && val.length > 2) {
          // Filtrar si capturó una etiqueta subsecuente
          final cleanVal = val.split(RegExp(r'\b(tel|cel|auto|vehiculo|placa|ubicacion)\b', caseSensitive: false)).first;
          return cleanVal.trim().capitalizeWords();
        }
      }
    }
    return null;
  }

  /// Extrae el Teléfono del asegurado o contacto
  static String? _extractTelefono(String text) {
    final patterns = [
      RegExp(
        r'(?:tel(?:[eé]fono)?|cel(?:ular)?|contacto|movil|whats(?:app)?)\s*[:\-]?\s*([+0-9\s\-()]{8,20})',
        caseSensitive: false,
      ),
      // Búsqueda de cualquier teléfono móvil mexicano estándar de 10 dígitos
      RegExp(r'\b(55\d{8}|56\d{8}|[1-9]\d{9})\b'),
    ];

    for (final reg in patterns) {
      final match = reg.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final val = match.group(1)?.trim();
        if (val != null) {
          final digits = val.replaceAll(RegExp(r'\D'), '');
          if (digits.length >= 8 && digits.length <= 13) {
            return digits;
          }
        }
      }
    }
    return null;
  }

  /// Extrae el link de Google Maps
  static String? _extractMapsUrl(String text) {
    final reg = RegExp(
      r'(https?:\/\/(?:maps\.app\.goo\.gl|goo\.gl\/maps|www\.google\.com\/maps|maps\.google\.com)[^\s\n\r]+)',
      caseSensitive: false,
    );
    final match = reg.firstMatch(text);
    return match?.group(1)?.trim();
  }

  /// Extrae placas del vehículo
  static String? _extractPlacas(String text) {
    final patterns = [
      RegExp(
        r'(?:placa[s]?|matr[ií]cula)\s*[:\-]?\s*([A-Za-z0-9\-]{4,10})',
        caseSensitive: false,
      ),
      // Formato típico de placas en México (ej: NXZ-44-33, 789-ABC, PWA-12-34)
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

  /// Extrae Marca, Submarca o Modelo del Vehículo
  static String? _extractVehiculo(String text, String? placasKnown) {
    final patterns = [
      RegExp(
        r'(?:veh[ií]culo|auto|unidad|coche)\s*[:\-]\s*([^\n\r]+)',
        caseSensitive: false,
      ),
    ];

    for (final reg in patterns) {
      final match = reg.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        var val = match.group(1)?.trim() ?? '';
        // Limpiar si capturó placas o color pegados
        if (placasKnown != null && placasKnown.isNotEmpty) {
          val = val.replaceAll(placasKnown, '');
        }
        val = val.split(RegExp(r'\b(placa[s]?|color|ubi|poliza)\b', caseSensitive: false)).first;
        if (val.trim().isNotEmpty) {
          return val.trim().capitalizeWords();
        }
      }
    }

    // Buscar marcas de autos frecuentes en México
    final marcas = [
      'Nissan', 'Chevrolet', 'Volkswagen', 'VW', 'Toyota', 'Honda', 'Ford',
      'Mazda', 'Kia', 'Hyundai', 'Seat', 'Renault', 'Suzuki', 'BMW', 'Audi', 'Mercedes'
    ];
    for (final m in marcas) {
      final reg = RegExp('\\b($m\\s+[A-Za-z0-9]+(?:\\s+\\d{4})?)', caseSensitive: false);
      final match = reg.firstMatch(text);
      if (match != null) {
        return match.group(1)?.trim().capitalizeWords();
      }
    }

    return null;
  }

  /// Extrae el Color del vehículo
  static String? _extractColor(String text) {
    final pattern = RegExp(
      r'(?:color)\s*[:\-]?\s*([A-Za-zÁÉÍÓÚáéíóú]+)',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)?.trim().capitalizeWords();
    }

    final colores = [
      'Blanco', 'Negro', 'Gris', 'Plata', 'Rojo', 'Azul', 'Vino', 'Arena',
      'Verde', 'Amarillo', 'Naranja', 'Cafe'
    ];
    for (final col in colores) {
      if (RegExp('\\b$col\\b', caseSensitive: false).hasMatch(text)) {
        return col;
      }
    }
    return null;
  }

  /// Extrae Número de Póliza
  static String? _extractPoliza(String text) {
    final pattern = RegExp(
      r'(?:p[oó]liza)\s*[:\-]?\s*([A-Za-z0-9\-]{5,20})',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(text);
    return match?.group(1)?.trim();
  }

  /// Extrae Ubicación o Referencia Textual
  static String? _extractUbicacion(String text) {
    final patterns = [
      RegExp(
        r'(?:ubicaci[oó]n|lugar|direcci[oó]n|sitio)\s*[:\-]\s*([^\n\r]+)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:calle|av(?:enida)?|perif[eé]rico|calzada|autopista|carretera)\s+[^\n\r]+',
        caseSensitive: false,
      ),
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

  /// Extrae Tipo de Evento
  static String? _extractTipoEvento(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('choque') || lower.contains('colision') || lower.contains('alcance')) {
      return 'Choque';
    }
    if (lower.contains('robo') || lower.contains('asalto')) {
      return 'Robo';
    }
    if (lower.contains('cristal') || lower.contains('parabrisas')) {
      return 'Cristal';
    }
    if (lower.contains('asistencia') || lower.contains('grua') || lower.contains('grúa') || lower.contains('ponchadura') || lower.contains('gasolina') || lower.contains('bateria')) {
      return 'Asistencia Vial';
    }
    if (lower.contains('terceros') || lower.contains('daño a tercero')) {
      return 'Daños a Terceros';
    }
    return null;
  }

  /// Extrae Referencias u Observaciones adicionales
  static String? _extractObservaciones(String text) {
    final patterns = [
      RegExp(
        r'(?:observaciones|notas?|referencia|ref|comentario)\s*[:\-]\s*([^\n\r]+)',
        caseSensitive: false,
      ),
    ];

    for (final reg in patterns) {
      final match = reg.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        return match.group(1)?.trim();
      }
    }
    return null;
  }
}
