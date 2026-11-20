/// Estructura de pestañas y encabezados para Google Sheets API
class SheetsConfig {
  static const String tabSiniestros = 'SINIESTROS';
  static const String tabAjustadores = 'AJUSTADORES';
  static const String tabCatalogo = 'CATALOGO_ASEGURADORAS';
  static const String tabHistorialCortes = 'HISTORIAL_CORTES';

  /// Encabezados de la hoja maestra de Siniestros (Columnas A a O de la hoja operativa AACH)
  static const List<String> siniestrosHeaders = [
    'FECHA',            // Col A (0)
    'AJUSTADOR',        // Col B (1)
    'ASEGURADORA',      // Col C (2)
    'REPORTE',          // Col D (3)
    'UBICACIÓN SIN.',   // Col E (4)
    'VEHICULO',         // Col F (5)
    'ATENCION',         // Col G (6) (para cabina / liquidación)
    'CASETAS',          // Col H (7) (gastos)
    'OTROS',            // Col I (8) (gastos adicionales)
    'KILOMETRAJE',      // Col J (9) (kilometraje recorrido)
    'TOTAL',            // Col K (10) (total liquidado)
    'ESTATUS',          // Col L (11) (Asignado / En Atención / Concluido)
    'FECHA ARRIBO',     // Col M (12)
    'FECHA CONCLUSION', // Col N (13)
    'TIPO CIERRE',      // Col O (14)
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

  /// Encabezados de la pestaña de Historial de Cortes Operativos
  static const List<String> historialCortesHeaders = [
    'FECHA_CORTE',              // Col A: Fecha y hora en que se congeló el corte
    'PERIODO',                  // Col B: Rango evaluado (Hoy, Semana, Quincena, etc.)
    'TOTAL_ASIGNADOS',          // Col C: Total de siniestros
    'TOTAL_CONCLUIDOS',         // Col D: Concluidos con éxito
    'EFECTIVIDAD',              // Col E: % de efectividad
    'SERVICIOS_POR_AJUSTADOR',  // Col F: Desglose por cada ajustador
    'TIEMPO_PROM_ARRIBO',       // Col G: Promedio de llegada
    'DURACION_PROM_ATENCION',   // Col H: Promedio de atención
    'DESGLOSE_CIERRES',         // Col I: Convenios, volantes, etc.
    'OBSERVACIONES',            // Col J: Notas del coordinador
  ];
}
