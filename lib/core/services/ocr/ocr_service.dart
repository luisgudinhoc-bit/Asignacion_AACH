import 'package:image_picker/image_picker.dart';
import 'ocr_service_web.dart'
    if (dart.library.io) 'ocr_service_mobile.dart';

/// Servicio unificado de reconocimiento óptico de caracteres (OCR)
/// Utiliza Google ML Kit en Android (100% On-Device, 0 tokens)
/// y un adaptador seguro en Web.
class OcrService {
  static final ImagePicker _picker = ImagePicker();

  /// Abre la galería para seleccionar una captura de pantalla de WhatsApp
  static Future<String?> extractTextFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null) return null;
    return OcrServicePlatform.recognizeTextFromImage(image);
  }

  /// Abre la cámara del dispositivo para tomar foto de un documento o volante
  static Future<String?> extractTextFromCamera() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (image == null) return null;
    return OcrServicePlatform.recognizeTextFromImage(image);
  }

  /// Procesa un archivo de imagen ya seleccionado
  static Future<String> processImageFile(XFile imageFile) async {
    return OcrServicePlatform.recognizeTextFromImage(imageFile);
  }
}
