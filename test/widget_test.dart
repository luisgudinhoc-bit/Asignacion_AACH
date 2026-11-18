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
      expect(parsed.ajustador, 'Andres Gudiño', reason: 'Debe tomar la última instrucción de asignación');
      expect(parsed.referencias, contains('mexico pachuca'));
      expect(parsed.municipio, 'Pachuca');
      expect(parsed.estado, 'Hidalgo');
    });

    test('Limpia ruido OCR severo con timestamps al final de línea y enlaces rotos', () {
      const ocrRawChat = '''
8:09
Despacho de ajustes...
Alejandro Chavez
Reenviado
3059238 8:04 p. m.
Alejandro Chavez
Reenviado
19:08 19:10 8:04 p. m.
Alejandro Chavez
Reenviado
Daniel Rojas 8:04 p. m.
Vas @Sergio Sanchez 8:04 p. m.
Vete por la mexico pachuca 8:04 p. m.
La pachuca sahagun esta cerrada 8:04 p. m.
Alejandro Chavez
Reenviado
maps.app.goo.gl
https://maps.app.goo.gl
/EGbX4taZmYpqBXS98 8:09 p. m.
Porfa @Andres Gudiño 8:09 p. m.
Alejandro Chavez
Porfa @Andres Gudiño
Voy 8:09 p. m.
''';

      final parsed = WhatsAppParserService.parse(ocrRawChat);

      expect(parsed.folio, '3059238', reason: 'Debe limpiar "8:04 p. m." pegado al folio');
      expect(parsed.asegurado, 'Daniel Rojas', reason: 'No debe confundirse con Alejandro Chavez y debe limpiar el timestamp');
      expect(parsed.ajustador, 'Andres Gudiño');
      expect(parsed.linkMaps, 'https://maps.app.goo.gl/EGbX4taZmYpqBXS98', reason: 'Debe reconstruir enlace partido por OCR y limpiar timestamp');
      expect(parsed.referencias, contains('mexico pachuca'));
    });

    test('Extrae mensaje operativo real de Inbursa con horas de reporte y asignación, submarca y semoviente', () {
      const msgInbursa = '''
Km 164 +200 dir Atlacomulco
Versa bco
Esteban Pérez
Semoviente
3059330
22:30 22:32
''';

      final parsed = WhatsAppParserService.parse(msgInbursa);

      expect(parsed.folio, '3059330');
      expect(parsed.aseguradora, 'Inbursa', reason: 'Debe deducir Inbursa por formato de folio iniciado en 305');
      expect(parsed.vehiculo, 'Versa', reason: 'Debe detectar la submarca Versa');
      expect(parsed.colorVehiculo, 'Blanco', reason: 'Debe traducir bco a Blanco');
      expect(parsed.asegurado, 'Esteban Pérez');
      expect(parsed.tipoEvento, 'Diverso', reason: 'Semoviente es evento Diverso');
      expect(parsed.detalleEvento, 'Semoviente');
      expect(parsed.horaReporte, '22:30');
      expect(parsed.horaAsignacion, '22:32');
      expect(parsed.observaciones, contains('22:30'));
      expect(parsed.observaciones, contains('22:32'));
      expect(parsed.municipio, 'Tulancingo');
      expect(parsed.estado, 'Hidalgo');
      expect(parsed.linkMaps, isNull, reason: 'No debe inventar enlaces de Maps si el texto no traía uno');
    });

    test('1. Folio estructurado No. Reporte y deducir Inbursa por prefijo 705XXXX', () {
      const msgCabina = '''
No. Reporte: 7051234
Asegurado: Gabriel Morales
Choque
''';
      final parsed = WhatsAppParserService.parse(msgCabina);
      expect(parsed.folio, '7051234');
      expect(parsed.aseguradora, 'Inbursa');
      expect(parsed.asegurado, 'Gabriel Morales');
      expect(parsed.tipoEvento, 'Choque');
    });

    test('2. Extrae teléfono suelto de 10 dígitos sin etiqueta', () {
      const msgConTel = '''
Versa bco
5512345678
Pedro Martinez
3059999
''';
      final parsed = WhatsAppParserService.parse(msgConTel);
      expect(parsed.telefonoAsegurado, '5512345678');
      expect(parsed.folio, '3059999');
      expect(parsed.vehiculo, 'Versa');
      expect(parsed.colorVehiculo, 'Blanco');
      expect(parsed.asegurado, 'Pedro Martinez');
    });

    test('3. Convierte coordenadas GPS crudas a enlace válido de Google Maps', () {
      const msgGps = '''
20.650354,-98.649149
Frontier naranja
3058888
''';
      final parsed = WhatsAppParserService.parse(msgGps);
      expect(parsed.linkMaps, 'https://www.google.com/maps?q=20.650354,-98.649149');
      expect(parsed.vehiculo, 'Frontier');
      expect(parsed.colorVehiculo, 'Naranja');
      expect(parsed.folio, '3058888');
    });

    test('4. Vehículo y nombre en misma línea, submarcas directas y vehículo tercero 3o', () {
      const msgMismaLinea = '''
Mazda negro Alberto Gutierrez
3o Audi A1
3057777
Semoviente
''';
      final parsed = WhatsAppParserService.parse(msgMismaLinea);
      expect(parsed.vehiculo, 'Mazda');
      expect(parsed.colorVehiculo, 'Negro');
      expect(parsed.asegurado, 'Alberto Gutierrez');
      expect(parsed.observaciones, contains('3o Audi A1'));
      expect(parsed.tipoEvento, 'Diverso');
      expect(parsed.detalleEvento, 'Semoviente');
      expect(parsed.folio, '3057777');
    });

    test('4b. Submarcas Groove bco y Tiigo bco con vehículo tercero 3o kia gris', () {
      const msgSubmarcas = '''
Groove bco
3o kia gris
Carlos Slim
3056666
''';
      final parsed = WhatsAppParserService.parse(msgSubmarcas);
      expect(parsed.vehiculo, 'Groove');
      expect(parsed.colorVehiculo, 'Blanco');
      expect(parsed.asegurado, 'Carlos Slim');
      expect(parsed.observaciones, contains('3o kia gris'));
      expect(parsed.folio, '3056666');
    });

    test('5. Mención de asignación con Te formó este luis', () {
      const msgAsignacion = '''
Te formó este luis
3059238
Versa bco
''';
      final parsed = WhatsAppParserService.parse(msgAsignacion);
      expect(parsed.ajustador, 'Luis');
      expect(parsed.folio, '3059238');
      expect(parsed.vehiculo, 'Versa');
    });

    test('Extrae formato Crabi con Cabinero y enlace de Maps con coordenadas', () {
      const msgCrabi = '''
📋 Siniestro #CRA-2026015921
📍 https://www.google.com/maps?q=19.69520652863495,-98.56009687301638
👤 Cabinero: Luis Roberto

¿Pueden atender este siniestro?
El administrador puede postular un ajustador 👇
''';

      final parsed = WhatsAppParserService.parse(msgCrabi);

      expect(parsed.folio, 'CRA-2026015921');
      expect(parsed.aseguradora, 'Crabi', reason: 'Debe deducir Crabi por prefijo CRA-');
      expect(parsed.linkMaps, 'https://www.google.com/maps?q=19.69520652863495,-98.56009687301638');
      expect(parsed.observaciones, contains('Cabinero: Luis Roberto'));
    });

    test('Extrae mensaje que contiene únicamente un link de Maps', () {
      const msgMaps = 'https://maps.app.goo.gl/EGbX4taZmYpqBXS98';
      final parsed = WhatsAppParserService.parse(msgMaps);

      expect(parsed.linkMaps, 'https://maps.app.goo.gl/EGbX4taZmYpqBXS98');
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
