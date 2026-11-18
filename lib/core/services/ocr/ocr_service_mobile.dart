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

      // Recorrer TextBlock y TextLine ordenados por coordenada vertical ('boundingBox.top')
      // para respetar estrictamente el orden de lectura de arriba hacia abajo en capturas de chat
      final allLines = <TextLine>[];
      for (final block in recognizedText.blocks) {
        allLines.addAll(block.lines);
      }

      if (allLines.isEmpty) {
        return recognizedText.text;
      }

      // Ordenar por 'top' ascendente; si dos líneas están en la misma franja horizontal (<= 10px), ordenar por 'left'
      allLines.sort((a, b) {
        final diffTop = a.boundingBox.top - b.boundingBox.top;
        if (diffTop.abs() > 10) {
          return diffTop.compareTo(0);
        }
        return a.boundingBox.left.compareTo(b.boundingBox.left);
      });

      return allLines.map((line) => line.text).join('\n');
    } finally {
      await textRecognizer.close();
    }
  }
}
