import 'package:intl/intl.dart';

/// Utilidades de formateo de fechas y tiempos operativos
class DateFormatter {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _fullDateTimeFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

  static String formatDate(DateTime dateTime) => _dateFormat.format(dateTime);

  static String formatTime(DateTime dateTime) => _timeFormat.format(dateTime);

  static String formatFull(DateTime dateTime) => _fullDateTimeFormat.format(dateTime);

  /// Retorna una cadena amigable que indica el tiempo transcurrido desde la asignación
  /// Ejemplo: "Hace 15 min", "Hace 2h 10m", "Hace 1 día"
  static String timeElapsed(DateTime fromTime, {DateTime? toTime}) {
    final target = toTime ?? DateTime.now();
    final difference = target.difference(fromTime);

    if (difference.isNegative) {
      return 'Ahora mismo';
    }

    if (difference.inSeconds < 60) {
      return 'Hace ${difference.inSeconds} s';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      final minutes = difference.inMinutes % 60;
      if (minutes == 0) {
        return 'Hace ${difference.inHours} h';
      }
      return 'Hace ${difference.inHours}h ${minutes}m';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else {
      return 'Hace ${difference.inDays} días';
    }
  }

  /// Indica si el tiempo transcurrido excede un umbral operativo crítico
  static bool isTimeAlert(DateTime fromTime, int thresholdMinutes) {
    final difference = DateTime.now().difference(fromTime);
    return difference.inMinutes >= thresholdMinutes;
  }
}
