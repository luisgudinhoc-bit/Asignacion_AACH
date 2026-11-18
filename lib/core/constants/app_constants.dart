/// Constantes globales de la aplicación Asignación AACH
class AppConstants {
  static const String appName = 'Asignación AACH';
  static const String appVersion = '1.0.0';
  static const String defaultSpreadsheetTitle = 'CONTROL_OPERATIVO_AACH_2026';

  // Hive Boxes
  static const String siniestrosBox = 'siniestros_box_v1';
  static const String ajustadoresBox = 'ajustadores_box_v1';
  static const String syncQueueBox = 'sync_queue_box_v1';
  static const String appSettingsBox = 'app_settings_box_v1';

  // Catálogo oficial de Aseguradoras del Despacho AACH
  static const List<String> defaultAseguradoras = [
    'Inbursa',
    'Mapfre',
    'Crabi',
    'SPT Seguros',
    'Otra Compañía',
  ];

  // Tipos de Eventos / Siniestros solicitados para despacho
  static const List<String> tiposEvento = [
    'Choque',
    'Robo',
    'Cristal',
    'Diverso',
    'Otro',
  ];

  // Tipos de Cierre para siniestros Concluidos
  static const List<String> tiposCierre = [
    'Con Convenio',
    'Sin Convenio',
    'Volante de Admisión',
    'Deducible Cobrado',
    'Solo Asistencia',
    'Rechazado en Cabina',
    'Pase Médico',
  ];

  // Prefijos y formatos telefónicos
  static const String defaultCountryCode = '521'; // México WhatsApp directo
}
