import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Implementación móvil (Android/iOS) con Google ML Kit Text Recognition.
/// Se ejecuta 100% de manera local en el procesador del dispositivo:
/// CERO tokens, CERO llamadas a la nube, 100% Offline y seguro.
class OcrServicePlatform {
  static Future<String> recognizeTextFromImage(XFile imageFile) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } finally {
      await textRecognizer.close();
    }
  }
}
