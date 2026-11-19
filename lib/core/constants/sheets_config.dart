/// Estructura de pestañas y encabezados para Google Sheets API
class SheetsConfig {
  static const String tabSiniestros = 'SINIESTROS';
  static const String tabAjustadores = 'AJUSTADORES';
  static const String tabCatalogo = 'CATALOGO_ASEGURADORAS';

  /// Encabezados de la hoja maestra de Siniestros (Columnas A a K de la hoja operativa AACH)
  static const List<String> siniestrosHeaders = [
    'FECHA',          // Col A
    'AJUSTADOR',      // Col B
    'ASEGURADORA',    // Col C
    'REPORTE',        // Col D
    'UBICACIÓN SIN.', // Col E
    'VEHICULO',       // Col F
    'ATENCION',       // Col G (para cabina / liquidación)
    'CASETAS',        // Col H (gastos)
    'OTROS',          // Col I (gastos adicionales)
    'KILOMETRAJE',    // Col J (kilometraje recorrido)
    'TOTAL',          // Col K (total liquidado)
  ];

  /// Encabezados de la pestaña de Ajustadores
  static const List<String> ajustadoresHeaders = [
    'ID_AJUSTADOR',
    'NOMBRE',
    'TELEFONO_WHATSAPP',
    'ACTIVO',
    'FOLIOS_ATENDIDOS_MES',
  ];

  /// Encabezados de la pestaña de Catálogo de Aseguradoras
  static const List<String> catalogoHeaders = [
    'NOMBRE_ASEGURADORA',
    'PREFIJO_HABITUAL',
    'TELEFONO_CABINA_EMERGENCIA',
  ];
}
