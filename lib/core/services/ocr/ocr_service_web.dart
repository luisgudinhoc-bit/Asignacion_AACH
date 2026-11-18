import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Adaptador Web para el servicio OCR.
/// El reconocimiento óptico por hardware corre en el chip del teléfono Android (Google ML Kit).
/// En el entorno web de computadora se guía al usuario para pegar el mensaje de texto de WhatsApp.
class OcrServicePlatform {
  static Future<String> recognizeTextFromImage(XFile imageFile) async {
    debugPrint('OCR nativo disponible en Android APK.');
    return '';
  }
}
