import 'package:geolocator/geolocator.dart';

/// Resultado estructurado de consulta de ubicación GPS
class LocationResult {
  final double latitude;
  final double longitude;
  final String mapsUrl;
  final String displayText;

  LocationResult({
    required this.latitude,
    required this.longitude,
    required this.mapsUrl,
    required this.displayText,
  });
}

/// Servicio para obtención de ubicación GPS y generación de coordenadas
class LocationService {
  /// Obtiene la posición GPS actual del dispositivo
  static Future<LocationResult?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Los servicios de ubicación (GPS) están desactivados.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Los permisos de ubicación fueron denegados.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Los permisos de ubicación están denegados permanentemente en los ajustes del sistema.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );

    final mapsUrl =
        'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
    final displayText =
        'GPS: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';

    return LocationResult(
      latitude: position.latitude,
      longitude: position.longitude,
      mapsUrl: mapsUrl,
      displayText: displayText,
    );
  }
}
