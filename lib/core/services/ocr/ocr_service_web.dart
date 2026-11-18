import 'package:image_picker/image_picker.dart';

/// Implementación web del servicio OCR.
/// Permite probar la funcionalidad en el navegador sin dependencias nativas de Android.
class OcrServicePlatform {
  static Future<String> recognizeTextFromImage(XFile imageFile) async {
    // Simulación operativa para navegador web basada en los mensajes reales del despacho
    return '''
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
  }
}
