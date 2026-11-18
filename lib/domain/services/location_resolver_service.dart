import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Datos estructurados de ubicación resueltos a partir de coordenadas o Google Maps
class ResolvedLocation {
  final double? latitude;
  final double? longitude;
  final String? calle;
  final String? municipio;
  final String? estado;
  final String? direccionCompleta;

  const ResolvedLocation({
    this.latitude,
    this.longitude,
    this.calle,
    this.municipio,
    this.estado,
    this.direccionCompleta,
  });

  bool get hasLocation =>
      (municipio != null && municipio!.isNotEmpty) ||
      (estado != null && estado!.isNotEmpty) ||
      (calle != null && calle!.isNotEmpty);
}

/// Servicio inteligente de resolución de enlaces de Google Maps a Municipio, Estado y Calle.
/// No requiere claves de pago de Google Maps API ni consume tokens de IA.
class LocationResolverService {
  /// Analiza un enlace de Google Maps y resuelve Municipio, Estado y Referencias
  static Future<ResolvedLocation?> resolveFromMapsUrl(String rawUrl) async {
    final cleanUrl = rawUrl.trim();
    if (cleanUrl.isEmpty || !cleanUrl.contains('maps')) return null;

    try {
      // 1. Extraer coordenadas directamente si ya vienen en el enlace
      var coords = _extractCoordsFromText(cleanUrl);

      // 2. Si es un enlace corto (maps.app.goo.gl o goo.gl/maps), resolver redirección HTTP
      if (coords == null && (cleanUrl.contains('maps.app.goo.gl') || cleanUrl.contains('goo.gl/maps'))) {
        coords = await _resolveRedirectCoords(cleanUrl);
      }

      // 3. Si se obtuvieron coordenadas, realizar Geocodificación Inversa gratuita
      if (coords != null) {
        final address = await _reverseGeocode(coords['lat']!, coords['lng']!);
        if (address != null && address.hasLocation) {
          return address;
        }
      }

      // 4. Si no se pudieron obtener coordenadas numéricas, deducir de nombres en la URL
      return _deduceFromUrlSlug(cleanUrl);
    } catch (e) {
      debugPrint('Aviso al resolver enlace de Maps: $e');
      return null;
    }
  }

  /// Extrae coordenadas latitud y longitud de patrones estándar de URLs de Google Maps
  static Map<String, double>? _extractCoordsFromText(String text) {
    if (text.isEmpty) return null;

    // Patrón 1: /search/20.111754,+-98.775108 o /search/20.111754,-98.775108
    final searchMatch = RegExp(r'\/search\/(-?\d{1,2}\.\d{3,})(?:%2C|,|\+|\s)+(-?\d{1,3}\.\d{3,})', caseSensitive: false).firstMatch(text);
    if (searchMatch != null) {
      final lat = double.tryParse(searchMatch.group(1)!);
      final lng = double.tryParse(searchMatch.group(2)!);
      if (lat != null && lng != null && _isValidCoord(lat, lng)) {
        return {'lat': lat, 'lng': lng};
      }
    }

    // Patrón 2: @19.4326,-99.1332 o /@20.0534444,-98.7417778
    final atMatch = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(text);
    if (atMatch != null) {
      final lat = double.tryParse(atMatch.group(1)!);
      final lng = double.tryParse(atMatch.group(2)!);
      if (lat != null && lng != null && _isValidCoord(lat, lng)) {
        return {'lat': lat, 'lng': lng};
      }
    }

    // Patrón 3: ?q=19.4326,-99.1332 o &query=19.4326,-99.1332 o ?ll=19.4326,-99.1332 o center=19.4326%2C-99.1332
    final queryMatch = RegExp(r'[?&](?:q|query|ll|center)=(-?\d+\.\d+)(?:%2C|,|\+|\s)+(-?\d+\.\d+)').firstMatch(text);
    if (queryMatch != null) {
      final lat = double.tryParse(queryMatch.group(1)!);
      final lng = double.tryParse(queryMatch.group(2)!);
      if (lat != null && lng != null && _isValidCoord(lat, lng)) {
        return {'lat': lat, 'lng': lng};
      }
    }

    // Patrón 4: /place/...
    final placeMatch = RegExp(r'place\/[^\/]*\/(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(text) ??
        RegExp(r'place\/(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(text);
    if (placeMatch != null) {
      final lat = double.tryParse(placeMatch.group(1)!);
      final lng = double.tryParse(placeMatch.group(2)!);
      if (lat != null && lng != null && _isValidCoord(lat, lng)) {
        return {'lat': lat, 'lng': lng};
      }
    }

    // Patrón 5: Coordenadas numéricas sueltas típicas de México (latitud 14..33, longitud -86..-118)
    final looseMatch = RegExp(r'\b(1[4-9]\.\d{4,}|2[0-9]\.\d{4,}|3[0-2]\.\d{4,})\s*[, ]\s*(-9[0-9]\.\d{4,}|-10[0-9]\.\d{4,}|-11[0-8]\.\d{4,})\b').firstMatch(text);
    if (looseMatch != null) {
      final lat = double.tryParse(looseMatch.group(1)!);
      final lng = double.tryParse(looseMatch.group(2)!);
      if (lat != null && lng != null && _isValidCoord(lat, lng)) {
        return {'lat': lat, 'lng': lng};
      }
    }

    return null;
  }

  static bool _isValidCoord(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  /// Resuelve la URL destino de un enlace acortado para descubrir sus coordenadas
  static Future<Map<String, double>?> _resolveRedirectCoords(String shortUrl) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(shortUrl))..followRedirects = true;
      request.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      final response = await client.send(request);

      final finalUrl = response.headers['location'] ?? response.request?.url.toString() ?? '';
      var coords = _extractCoordsFromText(finalUrl);
      if (coords != null) {
        client.close();
        return coords;
      }

      final body = await response.stream.bytesToString();
      client.close();
      return _extractCoordsFromText(body);
    } catch (_) {
      return null;
    }
  }

  /// Geocodificación Inversa gratuita vía OpenStreetMap Nominatim (0 costo, 0 tokens)
  static Future<ResolvedLocation?> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final res = await http.get(uri, headers: {'User-Agent': 'AsignacionAACH/1.0'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final addr = data['address'] as Map<String, dynamic>?;
        if (addr != null) {
          final calle = (addr['road'] ?? addr['residential'] ?? addr['quarter'] ?? addr['suburb'] ?? addr['neighbourhood'] ?? '') as String;
          final muni = (addr['city'] ?? addr['town'] ?? addr['municipality'] ?? addr['county'] ?? addr['village'] ?? '') as String;
          final estado = _normalizeEstado((addr['state'] ?? '') as String);
          final cp = addr['postcode'] != null ? 'CP ${addr['postcode']}' : null;
          final refFinal = calle.isNotEmpty ? (cp != null ? '$calle, $cp' : calle) : (cp ?? '');

          return ResolvedLocation(
            latitude: lat,
            longitude: lng,
            calle: refFinal.isNotEmpty ? refFinal : null,
            municipio: _normalizeMunicipio(muni),
            estado: estado.isNotEmpty ? estado : null,
            direccionCompleta: data['display_name'] as String?,
          );
        }
      }
    } catch (_) {}

    return ResolvedLocation(latitude: lat, longitude: lng);
  }

  /// Deduce Municipio o Estado a partir de términos en la URL si no hay red
  static ResolvedLocation? _deduceFromUrlSlug(String url) {
    final lower = Uri.decodeFull(url).toLowerCase();
    String? estado;
    String? municipio;

    if (lower.contains('pachuca')) {
      municipio = 'Pachuca';
      estado = 'Hidalgo';
    } else if (lower.contains('sahagun') || lower.contains('sahagún') || lower.contains('tepeapulco')) {
      municipio = 'Tepeapulco (Cd. Sahagún)';
      estado = 'Hidalgo';
    } else if (lower.contains('tizayuca')) {
      municipio = 'Tizayuca';
      estado = 'Hidalgo';
    } else if (lower.contains('tulancingo')) {
      municipio = 'Tulancingo';
      estado = 'Hidalgo';
    } else if (lower.contains('ecatepec')) {
      municipio = 'Ecatepec';
      estado = 'Estado de México';
    } else if (lower.contains('tlalnepantla')) {
      municipio = 'Tlalnepantla';
      estado = 'Estado de México';
    } else if (lower.contains('naucalpan')) {
      municipio = 'Naucalpan';
      estado = 'Estado de México';
    } else if (lower.contains('hidalgo') || lower.contains('hgo')) {
      estado = 'Hidalgo';
    } else if (lower.contains('edomex') || lower.contains('mexico')) {
      estado = 'Estado de México';
    } else if (lower.contains('cdmx')) {
      estado = 'CDMX';
    }

    if (municipio != null || estado != null) {
      return ResolvedLocation(municipio: municipio, estado: estado);
    }
    return null;
  }

  static String _normalizeEstado(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('hidalgo') || lower == 'hgo') return 'Hidalgo';
    if (lower.contains('mexico') || lower.contains('méxico') || lower.contains('mex')) return 'Estado de México';
    if (lower.contains('ciudad de méxico') || lower.contains('cdmx') || lower.contains('distrito federal')) {
      return 'CDMX';
    }
    if (lower.contains('puebla')) return 'Puebla';
    if (lower.contains('querétaro') || lower.contains('queretaro')) return 'Querétaro';
    if (lower.contains('tlaxcala')) return 'Tlaxcala';
    return raw;
  }

  static String _normalizeMunicipio(String raw) {
    if (raw.toLowerCase().contains('pachuca')) return 'Pachuca';
    if (raw.toLowerCase().contains('tepeapulco') || raw.toLowerCase().contains('sahagun')) {
      return 'Tepeapulco (Cd. Sahagún)';
    }
    if (raw.toLowerCase().contains('tizayuca')) return 'Tizayuca';
    if (raw.toLowerCase().contains('tulancingo')) return 'Tulancingo';
    if (raw.toLowerCase().contains('mineral de la reforma')) return 'Mineral de la Reforma';
    return raw;
  }
}
