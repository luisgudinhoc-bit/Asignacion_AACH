import 'package:flutter_test/flutter_test.dart';
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
  });
}
