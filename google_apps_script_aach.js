/**
 * ======================================================================================
 * WEBHOOK DE SINCRONIZACIÓN EN TIEMPO REAL - ASIGNACIÓN AACH & MAGG RECEPTOR
 * ======================================================================================
 * Hoja de Cálculo: CONTROL_OPERATIVO_AACH_2026
 * Spreadsheet ID: 1mh_cS0wWdEYFhUn0lRergJc6UPVcMKAhymgasAr4e0w
 * 
 * INSTRUCCIONES DE INSTALACIÓN (En 1 minuto):
 * 1. Abre tu hoja "CONTROL_OPERATIVO_AACH_2026" en Google Sheets.
 * 2. En el menú superior ve a: Extensiones ➔ Apps Script.
 * 3. Borra el código que aparezca y pega este archivo completo.
 * 4. Haz clic en "Implementar" (botón azul arriba a la derecha) ➔ "Nueva implementación".
 * 5. Selecciona tipo: "Aplicación web" (icono de engrane).
 *    - Descripción: Webhook Asignacion AACH
 *    - Ejecutar como: "Yo (tu correo)"
 *    - Quién tiene acceso: "Cualquiera" (Anyone)
 * 6. Haz clic en "Implementar", autoriza los permisos y COPIA la "URL de la aplicación web".
 * 7. Pega esa URL en la app MAGG Receptor o en Asignación AACH.
 * ======================================================================================
 */

function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      return ContentService.createTextOutput(JSON.stringify({
        status: "error",
        message: "Sin contenido recibido"
      })).setMimeType(ContentService.MimeType.JSON);
    }

    const payload = JSON.parse(e.postData.contents);
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    let sheet = ss.getSheetByName("SINIESTROS");
    if (!sheet) {
      sheet = ss.getSheets()[0]; // Primera hoja por defecto si tiene otro nombre
    }

    const action = payload.action;
    const folio = (payload.folio || "").toString().trim();

    if (!folio && action !== "test") {
      return ContentService.createTextOutput(JSON.stringify({
        status: "error",
        message: "Folio no proporcionado"
      })).setMimeType(ContentService.MimeType.JSON);
    }

    // Asegurar encabezados L1:O1 si están vacíos
    const headers = sheet.getRange(1, 1, 1, 15).getValues()[0];
    if (!headers[11] || headers[11].toString().trim() === "") sheet.getRange(1, 12).setValue("ESTATUS");
    if (!headers[12] || headers[12].toString().trim() === "") sheet.getRange(1, 13).setValue("FECHA ARRIBO");
    if (!headers[13] || headers[13].toString().trim() === "") sheet.getRange(1, 14).setValue("FECHA CONCLUSION");
    if (!headers[14] || headers[14].toString().trim() === "") sheet.getRange(1, 15).setValue("TIPO CIERRE");

    if (action === "test") {
      return ContentService.createTextOutput(JSON.stringify({
        status: "success",
        message: "Conexión exitosa con CONTROL_OPERATIVO_AACH_2026",
        timestamp: new Date().toISOString()
      })).setMimeType(ContentService.MimeType.JSON);
    }

    // Buscar fila por Folio / Reporte en Columna D (Columna 4)
    const data = sheet.getDataRange().getValues();
    let targetRow = -1;
    const cleanFolio = folio.toLowerCase();

    for (let i = 1; i < data.length; i++) {
      const rep = (data[i][3] || "").toString().trim().toLowerCase();
      if (rep === cleanFolio || (cleanFolio.length >= 5 && rep.includes(cleanFolio))) {
        targetRow = i + 1; // 1-based index de Google Sheets
        break;
      }
    }

    const tz = Session.getScriptTimeZone() || "America/Mexico_City";
    const ahora = Utilities.formatDate(new Date(), tz, "dd/MM/yyyy HH:mm:ss");

    // 1. MARCAR ARRIBO
    if (action === "marcar_arribo") {
      const fechaArribo = payload.fechaArribo || ahora;
      if (targetRow > 0) {
        // Col L (12): ESTATUS, Col M (13): FECHA ARRIBO
        sheet.getRange(targetRow, 12).setValue("En Atención");
        sheet.getRange(targetRow, 13).setValue(fechaArribo);
        return ContentService.createTextOutput(JSON.stringify({
          status: "success",
          action: "arribo_registrado",
          folio: folio,
          fila: targetRow,
          fechaArribo: fechaArribo
        })).setMimeType(ContentService.MimeType.JSON);
      } else {
        return ContentService.createTextOutput(JSON.stringify({
          status: "not_found",
          message: "Folio no encontrado en columna REPORTE: " + folio
        })).setMimeType(ContentService.MimeType.JSON);
      }
    }

    // 2. CONCLUIR SINIESTRO
    if (action === "concluir_siniestro") {
      const fechaConclusion = payload.fechaConclusion || ahora;
      const tipoCierre = payload.tipoCierre || "Concluido";
      if (targetRow > 0) {
        // Col L (12): ESTATUS, Col N (14): FECHA CONCLUSION, Col O (15): TIPO CIERRE
        sheet.getRange(targetRow, 12).setValue("Concluido");
        sheet.getRange(targetRow, 14).setValue(fechaConclusion);
        sheet.getRange(targetRow, 15).setValue(tipoCierre);
        return ContentService.createTextOutput(JSON.stringify({
          status: "success",
          action: "conclusion_registrada",
          folio: folio,
          fila: targetRow,
          fechaConclusion: fechaConclusion,
          tipoCierre: tipoCierre
        })).setMimeType(ContentService.MimeType.JSON);
      } else {
        return ContentService.createTextOutput(JSON.stringify({
          status: "not_found",
          message: "Folio no encontrado en columna REPORTE: " + folio
        })).setMimeType(ContentService.MimeType.JSON);
      }
    }

    return ContentService.createTextOutput(JSON.stringify({
      status: "error",
      message: "Acción no reconocida: " + action
    })).setMimeType(ContentService.MimeType.JSON);

  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({
      status: "error",
      message: err.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

function doGet(e) {
  return ContentService.createTextOutput(JSON.stringify({
    status: "online",
    servicio: "Webhook Asignación AACH",
    hoja: "CONTROL_OPERATIVO_AACH_2026",
    timestamp: new Date().toISOString()
  })).setMimeType(ContentService.MimeType.JSON);
}
