/// Extensiones útiles para manipulación de cadenas de texto en el despacho
extension StringExtensions on String {
  /// Normaliza un número telefónico para WhatsApp en México (+521XXXXXXXXXX)
  String toMexicanWhatsAppPhone() {
    final digits = replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';

    // Si ya tiene código de país 521 y 10 dígitos (total 13 dígitos)
    if (digits.startsWith('521') && digits.length >= 13) {
      return digits;
    }
    // Si inicia con 52 y tiene 12 dígitos, insertar el 1 móvil de México si necesario
    if (digits.startsWith('52') && digits.length == 12) {
      return '521${digits.substring(2)}';
    }
    // Si son los 10 dígitos estándar de México
    if (digits.length == 10) {
      return '521$digits';
    }

    return digits;
  }

  /// Capitaliza la primera letra de cada palabra
  String capitalizeWords() {
    if (trim().isEmpty) return this;
    return split(' ')
        .map((str) => str.isNotEmpty
            ? '${str[0].toUpperCase()}${str.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }

  /// Limpia espacios extra y saltos repetidos
  String cleanWhitespace() {
    return trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
