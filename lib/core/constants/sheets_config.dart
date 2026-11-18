/// Estructura de pestañas y encabezados para Google Sheets API
class SheetsConfig {
  static const String tabSiniestros = 'SINIESTROS';
  static const String tabAjustadores = 'AJUSTADORES';
  static const String tabCatalogo = 'CATALOGO_ASEGURADORAS';

  static const List<String> siniestrosHeaders = [
    'ID_SISTEMA',
    'FOLIO_SINIESTRO',
    'ASEGURADORA',
    'AJUSTADOR',
    'ESTATUS',
    'TIPO_EVENTO',
    'UBICACION',
    'LINK_MAPS',
    'NOMBRE_ASEGURADO',
    'TELEFONO_ASEGURADO',
    'VEHICULO_MARCA_SUBMARCA',
    'COLOR_VEHICULO',
    'PLACAS',
    'POLIZA',
    'FECHA_ASIGNACION',
    'HORA_ASIGNACION',
    'FECHA_ARRIBO',
    'FECHA_CONCLUSION',
    'TIPO_CIERRE',
    'OBSERVACIONES',
    'ULTIMA_ACTUALIZACION',
  ];

  static const List<String> ajustadoresHeaders = [
    'ID_AJUSTADOR',
    'NOMBRE',
    'TELEFONO_WHATSAPP',
    'ACTIVO',
    'FOLIOS_ATENDIDOS_MES',
  ];

  static const List<String> catalogoHeaders = [
    'NOMBRE_ASEGURADORA',
    'PREFIJO_HABITUAL',
    'TELEFONO_CABINA_EMERGENCIA',
  ];
}
