import 'package:flutter_test/flutter_test.dart';
import 'package:asignacion_aach/domain/services/location_resolver_service.dart';
import 'package:asignacion_aach/domain/services/whatsapp_parser_service.dart';

void main() {
  group('WhatsAppParserService Tests', () {
    test('Extrae correctamente mensaje de cabina Quálitas', () {
      const msgQualitas = '''
*CABINA QUALITAS REPORTA*
REPORTE: 0424123456
ASEGURADO: ROBERTO HERNANDEZ DIAZ
TEL: 5541998877
VEHICULO: NISSAN VERSA 2021 COLOR BLANCO
PLACAS: NXZ4433
UBICACION: AV INSURGENTES SUR 1602 COL CREDITO CONSTRUCTOR CDMX
MAPS: https://maps.app.goo.gl/abcdef12345
POLIZA: 123456789
CABINA SOLICITA ARRIBO INMEDIATO
''';

      final parsed = WhatsAppParserService.parse(msgQualitas);

      expect(parsed.folio, '0424123456');
      expect(parsed.aseguradora, 'Quálitas');
      expect(parsed.asegurado, contains('Roberto Hernandez'));
      expect(parsed.telefonoAsegurado, '5541998877');
      expect(parsed.placas, 'NXZ4433');
      expect(parsed.linkMaps, 'https://maps.app.goo.gl/abcdef12345');
    });

    test('Extrae correctamente mensaje de cabina Inbursa', () {
      const msgInbursa = '''
INBURSA CABINA CENTRAL
Siniestro: INB-99887766
Reportante: Maria Lopez
Contacto: 55-1234-5678
Auto: CHEVROLET AVEO ROJO
Placas: 789-ABC
Lugar: Periferico Sur 4000
Google Maps: https://goo.gl/maps/xyz987
Observaciones: Choque por alcance
''';

      final parsed = WhatsAppParserService.parse(msgInbursa);

      expect(parsed.folio, 'INB-99887766');
      expect(parsed.aseguradora, 'Inbursa');
      expect(parsed.asegurado, contains('Maria Lopez'));
      expect(parsed.placas, '789-ABC');
      expect(parsed.tipoEvento, 'Choque');
    });

    test('Extrae correctamente mensaje de cabina GNP', () {
      const msgGNP = '''
ASIGNACION GNP SEGUROS
Folio: GNP2024-554433
Cliente: JORGE MARTINEZ
Celular: 5598765432
Unidad: VW Jetta Plata
Placas: PWA-12-34
Direccion: CALLE 5 DE MAYO # 45 COL CENTRO
Maps: https://www.google.com/maps?q=19.4326,-99.1332
Poliza: 009876543
''';

      final parsed = WhatsAppParserService.parse(msgGNP);

      expect(parsed.folio, 'GNP2024-554433');
      expect(parsed.aseguradora, 'GNP Seguros');
      expect(parsed.asegurado, contains('Jorge Martinez'));
      expect(parsed.telefonoAsegurado, '5598765432');
      expect(parsed.placas, 'PWA-12-34');
    });

    test('Extrae correctamente mensaje fragmentado y reenviado de chat de despacho', () {
      const msgChat = '''
Alejandro Chavez
Reenviado
3059238
8:04 p. m.
Alejandro Chavez
Reenviado
19:08 19;10
8:04 p. m.
Alejandro Chavez
Reenviado
Daniel Rojas
8:04 p. m.
Vas @Sergio Sanchez
8:04 p. m.
Vete por la mexico pachuca
8:04 p. m.
La pachuca sahagun esta cerrada
8:04 p. m.
Alejandro Chavez
Reenviado
maps.app.goo.gl
https://maps.app.goo.gl/EGbX4taZmYpqBXS98
maps.app.goo.gl
https://maps.app.goo.gl/EGbX4taZmYpqBXS98
8:09 p. m.
Porfa @Andres Gudiño
8:09 p. m.
''';

      final parsed = WhatsAppParserService.parse(msgChat);

      expect(parsed.folio, '3059238');
      expect(parsed.asegurado, 'Daniel Rojas');
      expect(parsed.linkMaps, 'https://maps.app.goo.gl/EGbX4taZmYpqBXS98');
      expect(parsed.ajustador, anyOf('Sergio Sanchez', 'Andres Gudiño'));
      expect(parsed.referencias, contains('mexico pachuca'));
      expect(parsed.municipio, 'Pachuca');
      expect(parsed.estado, 'Hidalgo');
    });
  });

  group('LocationResolverService Tests', () {
    test('Deduce municipio y estado desde URL de Maps', () async {
      const url = 'https://www.google.com/maps/place/Pachuca+de+Soto,+Hgo./@20.1011,-98.7591';
      final resolved = await LocationResolverService.resolveFromMapsUrl(url);

      expect(resolved, isNotNull);
      expect(resolved?.municipio, 'Pachuca');
      expect(resolved?.estado, 'Hidalgo');
    });

    test('Deduce municipio Sahagun y estado Hidalgo desde slug', () async {
      const url = 'https://maps.google.com/?q=Tepeapulco+Cd+Sahagun+Hidalgo';
      final resolved = await LocationResolverService.resolveFromMapsUrl(url);

      expect(resolved, isNotNull);
      expect(resolved?.municipio, contains('Sahagún'));
      expect(resolved?.estado, 'Hidalgo');
    });
  });
}
