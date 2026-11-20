import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/constants/sheets_config.dart';
import '../../domain/models/ajustador_model.dart';
import '../../domain/models/aseguradora_model.dart';
import '../../domain/models/siniestro_model.dart';
import 'local_storage_service.dart';

/// Cliente HTTP autenticado con cabeceras Bearer dinámicas de Google Sign-In
class _AuthenticatedClient extends http.BaseClient {
  final GoogleSignInAccount _account;
  final http.Client _client = http.Client();

  _AuthenticatedClient(this._account);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // 1. Obtener headers frescos en cada petición para evitar tokens expirados
    Map<String, String> headers = {};
    try {
      headers = await _account.authHeaders;
    } catch (e) {
      debugPrint('Aviso obteniendo authHeaders: $e');
    }

    // 2. Si authHeaders no incluye Authorization o está vacía, forzar desde authentication
    if (!headers.containsKey('Authorization') || headers['Authorization'] == null || headers['Authorization']!.isEmpty) {
      try {
        final auth = await _account.authentication;
        if (auth.accessToken != null && auth.accessToken!.isNotEmpty) {
          headers = {
            ...headers,
            'Authorization': 'Bearer ${auth.accessToken}',
          };
        }
      } catch (e) {
        debugPrint('Aviso obteniendo authentication.accessToken: $e');
      }
    }

    request.headers.addAll(headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

/// Servicio integral para comunicación directa con Google Sheets API v4
class GoogleSheetsService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? AppConstants.googleOAuthWebClientId : null,
    scopes: [
      sheets.SheetsApi.spreadsheetsScope,
      'email',
      'profile',
    ],
  );

  GoogleSignInAccount? _currentUser;
  sheets.SheetsApi? _sheetsApi;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null && _sheetsApi != null;

  /// Inicia sesión interactiva con Google OAuth 2.0
  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        _currentUser = account;

        // En Android/Web, verificar y solicitar el scope explícito de Google Sheets si falta
        try {
          final hasScope = await _googleSignIn.canAccessScopes([sheets.SheetsApi.spreadsheetsScope]);
          if (!hasScope) {
            debugPrint('Solicitando scope de Google Sheets...');
            await _googleSignIn.requestScopes([sheets.SheetsApi.spreadsheetsScope]);
          }
        } catch (e) {
          debugPrint('Aviso al solicitar scopes de Sheets: $e');
        }

        final authClient = _AuthenticatedClient(account);
        _sheetsApi = sheets.SheetsApi(authClient);
        await LocalStorageService.setUserEmail(account.email);
        debugPrint('Google Sign-In exitoso: ${account.email}');
      }
      return account;
    } catch (e) {
      debugPrint('Error en Google Sign-In: $e');
      rethrow;
    }
  }

  /// Intento de inicio de sesión silencioso si ya existen credenciales guardadas
  Future<bool> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        _currentUser = account;
        final authClient = _AuthenticatedClient(account);
        _sheetsApi = sheets.SheetsApi(authClient);
        await LocalStorageService.setUserEmail(account.email);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error en silent sign-in: $e');
      return false;
    }
  }

  /// Cierra sesión de Google
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _sheetsApi = null;
  }

  /// Asegura que el cliente de Sheets esté listo o lanza excepción
  void _assertAuthenticated() {
    if (_sheetsApi == null) {
      throw Exception(
        'No se ha autenticado con una cuenta de Google autorizada. Inicie sesión en Ajustes.',
      );
    }
  }

  /// Inicializa automáticamente las pestañas y encabezados en la hoja de Google Sheets si no existen
  Future<void> ensureSheetTabsAndHeaders(String spreadsheetId) async {
    _assertAuthenticated();

    try {
      final spreadsheet = await _sheetsApi!.spreadsheets.get(spreadsheetId);
      final existingTitles = (spreadsheet.sheets ?? [])
          .map((s) => s.properties?.title ?? '')
          .toList();

      final requests = <sheets.Request>[];

      // Verificar y agregar pestaña SINIESTROS
      if (!existingTitles.contains(SheetsConfig.tabSiniestros)) {
        requests.add(
          sheets.Request(
            addSheet: sheets.AddSheetRequest(
              properties: sheets.SheetProperties(
                title: SheetsConfig.tabSiniestros,
                gridProperties: sheets.GridProperties(
                  frozenRowCount: 1,
                  columnCount: SheetsConfig.siniestrosHeaders.length + 5,
                ),
              ),
            ),
          ),
        );
      }

      // Verificar y agregar pestaña AJUSTADORES
      if (!existingTitles.contains(SheetsConfig.tabAjustadores)) {
        requests.add(
          sheets.Request(
            addSheet: sheets.AddSheetRequest(
              properties: sheets.SheetProperties(
                title: SheetsConfig.tabAjustadores,
                gridProperties: sheets.GridProperties(
                  frozenRowCount: 1,
                  columnCount: SheetsConfig.ajustadoresHeaders.length + 5,
                ),
              ),
            ),
          ),
        );
      }

      // Verificar y agregar pestaña CATALOGO_ASEGURADORAS
      if (!existingTitles.contains(SheetsConfig.tabCatalogo)) {
        requests.add(
          sheets.Request(
            addSheet: sheets.AddSheetRequest(
              properties: sheets.SheetProperties(
                title: SheetsConfig.tabCatalogo,
                gridProperties: sheets.GridProperties(
                  frozenRowCount: 1,
                  columnCount: SheetsConfig.catalogoHeaders.length + 5,
                ),
              ),
            ),
          ),
        );
      }

      // Verificar y agregar pestaña HISTORIAL_CORTES
      if (!existingTitles.contains(SheetsConfig.tabHistorialCortes)) {
        requests.add(
          sheets.Request(
            addSheet: sheets.AddSheetRequest(
              properties: sheets.SheetProperties(
                title: SheetsConfig.tabHistorialCortes,
                gridProperties: sheets.GridProperties(
                  frozenRowCount: 1,
                  columnCount: SheetsConfig.historialCortesHeaders.length + 2,
                ),
              ),
            ),
          ),
        );
      }

      if (requests.isNotEmpty) {
        await _sheetsApi!.spreadsheets.batchUpdate(
          sheets.BatchUpdateSpreadsheetRequest(requests: requests),
          spreadsheetId,
        );
      }

      // Escribir encabezados si no existen
      await _writeHeadersIfEmpty(
        spreadsheetId,
        '${SheetsConfig.tabSiniestros}!A1:K1',
        SheetsConfig.siniestrosHeaders,
      );
      await _writeHeadersIfEmpty(
        spreadsheetId,
        '${SheetsConfig.tabAjustadores}!A1:E1',
        SheetsConfig.ajustadoresHeaders,
      );
      await _writeHeadersIfEmpty(
        spreadsheetId,
        '${SheetsConfig.tabCatalogo}!A1:C1',
        SheetsConfig.catalogoHeaders,
      );
      await _writeHeadersIfEmpty(
        spreadsheetId,
        '${SheetsConfig.tabHistorialCortes}!A1:J1',
        SheetsConfig.historialCortesHeaders,
      );

      // Si la pestaña de catálogo o ajustadores acaba de crearse, insertar valores iniciales
      await _seedDefaultCatalogsIfEmpty(spreadsheetId);
    } catch (e) {
      debugPrint('Error en ensureSheetTabsAndHeaders: $e');
      rethrow;
    }
  }

  Future<void> _writeHeadersIfEmpty(
    String spreadsheetId,
    String range,
    List<String> headers,
  ) async {
    try {
      final valueRange = await _sheetsApi!.spreadsheets.values.get(spreadsheetId, range);
      if (valueRange.values == null || valueRange.values!.isEmpty) {
        final updateData = sheets.ValueRange(
          range: range,
          values: [headers],
        );
        await _sheetsApi!.spreadsheets.values.update(
          updateData,
          spreadsheetId,
          range,
          valueInputOption: 'USER_ENTERED',
        );
      }
    } catch (e) {
      debugPrint('Error escribiendo encabezados en $range: $e');
    }
  }

  Future<void> _seedDefaultCatalogsIfEmpty(String spreadsheetId) async {
    try {
      // Ajustadores
      final ajRange = await _sheetsApi!.spreadsheets.values.get(
        spreadsheetId,
        '${SheetsConfig.tabAjustadores}!A2:E2',
      );
      if (ajRange.values == null || ajRange.values!.isEmpty) {
        final defaultRows =
            AjustadorModel.defaultAjustadores.map((a) => a.toSheetsRow()).toList();
        await _sheetsApi!.spreadsheets.values.append(
          sheets.ValueRange(values: defaultRows),
          spreadsheetId,
          '${SheetsConfig.tabAjustadores}!A:E',
          valueInputOption: 'USER_ENTERED',
        );
      }

      // Catálogo Aseguradoras
      final catRange = await _sheetsApi!.spreadsheets.values.get(
        spreadsheetId,
        '${SheetsConfig.tabCatalogo}!A2:C2',
      );
      if (catRange.values == null || catRange.values!.isEmpty) {
        final defaultRows =
            AseguradoraModel.defaultList.map((a) => a.toSheetsRow()).toList();
        await _sheetsApi!.spreadsheets.values.append(
          sheets.ValueRange(values: defaultRows),
          spreadsheetId,
          '${SheetsConfig.tabCatalogo}!A:C',
          valueInputOption: 'USER_ENTERED',
        );
      }
    } catch (e) {
      debugPrint('Error sembrando catálogos iniciales: $e');
    }
  }

  // ==================== OPERACIONES SINIESTROS (COLUMNAS A A F) ====================

  /// Agrega un nuevo siniestro escribiendo estrictamente en las columnas A a F
  /// Col A: FECHA | Col B: AJUSTADOR | Col C: ASEGURADORA | Col D: REPORTE | Col E: UBICACIÓN SIN. | Col F: VEHICULO
  /// Respeta íntegramente las columnas G:K (ATENCION, CASETAS, OTROS, KILOMETRAJE, TOTAL)
  Future<int?> appendSiniestro(String spreadsheetId, SiniestroModel siniestro) async {
    _assertAuthenticated();

    // 1. Buscar la primera fila disponible donde la Columna D (REPORTE) esté vacía
    // para aprovechar filas pre-configuradas con fórmulas en G:K sin saltar al final
    try {
      final colRange = await _sheetsApi!.spreadsheets.values.get(
        spreadsheetId,
        '${SheetsConfig.tabSiniestros}!D2:D',
      );
      if (colRange.values != null) {
        for (int i = 0; i < colRange.values!.length; i++) {
          final row = colRange.values![i];
          final val = row.isNotEmpty ? row[0].toString().trim() : '';
          if (val.isEmpty) {
            final targetRow = i + 2; // +2 por encabezado y 1-based index
            final updateRange = '${SheetsConfig.tabSiniestros}!A$targetRow:F$targetRow';
            await _sheetsApi!.spreadsheets.values.update(
              sheets.ValueRange(values: [siniestro.toSheetsRowAtoF()]),
              spreadsheetId,
              updateRange,
              valueInputOption: 'USER_ENTERED',
            );
            return targetRow;
          }
        }
      }
    } catch (e) {
      debugPrint('Aviso al buscar fila vacía en SINIESTROS: $e');
    }

    // 2. Si no hay filas vacías preexistentes, anexar como nueva fila
    final valueRange = sheets.ValueRange(
      values: [siniestro.toSheetsRowAtoF()],
    );

    final response = await _sheetsApi!.spreadsheets.values.append(
      valueRange,
      spreadsheetId,
      '${SheetsConfig.tabSiniestros}!A:F',
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
    );

    final updatedRange = response.updates?.updatedRange;
    if (updatedRange != null) {
      final match = RegExp(r'!A(\d+):').firstMatch(updatedRange);
      if (match != null) {
        return int.tryParse(match.group(1)!);
      }
    }
    return null;
  }

  /// Actualiza un siniestro existente en la hoja tocando únicamente las columnas A a F
  Future<void> updateSiniestro(String spreadsheetId, SiniestroModel siniestro) async {
    _assertAuthenticated();

    // 1. Si ya se conoce el número de fila, actualizar únicamente A:F
    if (siniestro.rowNumberSheets != null && siniestro.rowNumberSheets! > 1) {
      final range = '${SheetsConfig.tabSiniestros}!A${siniestro.rowNumberSheets}:F${siniestro.rowNumberSheets}';
      final valueRange = sheets.ValueRange(
        range: range,
        values: [siniestro.toSheetsRowAtoF()],
      );
      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        spreadsheetId,
        range,
        valueInputOption: 'USER_ENTERED',
      );
      return;
    }

    // 2. Si no se conoce la fila, buscar por el Folio de Reporte en Columna D (REPORTE)
    final colDRange = await _sheetsApi!.spreadsheets.values.get(
      spreadsheetId,
      '${SheetsConfig.tabSiniestros}!D2:D',
    );

    int targetRow = -1;
    if (colDRange.values != null && siniestro.folio.isNotEmpty) {
      for (int i = 0; i < colDRange.values!.length; i++) {
        final row = colDRange.values![i];
        final reporteCol = row.isNotEmpty ? row[0].toString().trim() : '';
        if (reporteCol.toLowerCase() == siniestro.folio.trim().toLowerCase()) {
          targetRow = i + 2; // +2 por encabezado y 1-based index
          break;
        }
      }
    }

    if (targetRow > 1) {
      final range = '${SheetsConfig.tabSiniestros}!A$targetRow:F$targetRow';
      final valueRange = sheets.ValueRange(
        range: range,
        values: [siniestro.toSheetsRowAtoF()],
      );
      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        spreadsheetId,
        range,
        valueInputOption: 'USER_ENTERED',
      );
    } else {
      // Si no fue encontrado, anexarlo como nueva fila en A:F
      await appendSiniestro(spreadsheetId, siniestro);
    }
  }

  /// Lee los siniestros registrados en Google Sheets (Columnas A a F)
  Future<List<SiniestroModel>> fetchSiniestros(String spreadsheetId) async {
    _assertAuthenticated();
    final response = await _sheetsApi!.spreadsheets.values.get(
      spreadsheetId,
      '${SheetsConfig.tabSiniestros}!A2:F',
    );

    final list = <SiniestroModel>[];
    if (response.values != null) {
      for (int i = 0; i < response.values!.length; i++) {
        final row = response.values![i];
        if (row.isNotEmpty) {
          final folio = row.length > 3 ? row[3].toString().trim() : '';
          final fecha = row.isNotEmpty ? row[0].toString().trim() : '';
          // Ignorar filas vacías que solo tienen fórmulas en G:K
          if (folio.isNotEmpty || fecha.isNotEmpty) {
            final rowNumber = i + 2;
            list.add(SiniestroModel.fromSheetsRow(row, rowNumber: rowNumber));
          }
        }
      }
    }
    return list;
  }

  // ==================== OPERACIONES AJUSTADORES ====================

  /// Lee la lista completa de ajustadores desde la pestaña AJUSTADORES de Google Sheets
  Future<List<AjustadorModel>> fetchAjustadores(String spreadsheetId) async {
    _assertAuthenticated();
    final response = await _sheetsApi!.spreadsheets.values.get(
      spreadsheetId,
      '${SheetsConfig.tabAjustadores}!A2:E',
    );

    final list = <AjustadorModel>[];
    if (response.values != null) {
      for (final row in response.values!) {
        if (row.isNotEmpty) {
          list.add(AjustadorModel.fromSheetsRow(row));
        }
      }
    }
    return list;
  }

  /// Sincroniza la lista completa de ajustadores con la pestaña AJUSTADORES de Google Sheets
  Future<void> syncAjustadoresToSheets(
    String spreadsheetId,
    List<AjustadorModel> ajustadores,
  ) async {
    _assertAuthenticated();
    final rows = ajustadores.map((a) => a.toSheetsRow()).toList();

    try {
      await _sheetsApi!.spreadsheets.values.clear(
        sheets.ClearValuesRequest(),
        spreadsheetId,
        '${SheetsConfig.tabAjustadores}!A2:E',
      );
    } catch (e) {
      debugPrint('Aviso al limpiar pestaña de ajustadores: $e');
    }

    if (rows.isNotEmpty) {
      final range = '${SheetsConfig.tabAjustadores}!A2:E${rows.length + 1}';
      await _sheetsApi!.spreadsheets.values.update(
        sheets.ValueRange(values: rows),
        spreadsheetId,
        range,
        valueInputOption: 'USER_ENTERED',
      );
    }
  }

  // ==================== OPERACIONES CATÁLOGO DE ASEGURADORAS ====================

  /// Lee la lista completa de aseguradoras desde la pestaña CATALOGO_ASEGURADORAS
  Future<List<AseguradoraModel>> fetchAseguradoras(String spreadsheetId) async {
    _assertAuthenticated();
    final response = await _sheetsApi!.spreadsheets.values.get(
      spreadsheetId,
      '${SheetsConfig.tabCatalogo}!A2:C',
    );

    final list = <AseguradoraModel>[];
    if (response.values != null) {
      for (final row in response.values!) {
        if (row.isNotEmpty) {
          list.add(AseguradoraModel.fromSheetsRow(row));
        }
      }
    }
    return list;
  }

  /// Sincroniza la lista de aseguradoras con la pestaña CATALOGO_ASEGURADORAS
  Future<void> syncAseguradorasToSheets(
    String spreadsheetId,
    List<AseguradoraModel> aseguradoras,
  ) async {
    _assertAuthenticated();
    final rows = aseguradoras.map((a) => a.toSheetsRow()).toList();

    try {
      await _sheetsApi!.spreadsheets.values.clear(
        sheets.ClearValuesRequest(),
        spreadsheetId,
        '${SheetsConfig.tabCatalogo}!A2:C',
      );
    } catch (e) {
      debugPrint('Aviso al limpiar pestaña de aseguradoras: $e');
    }

    if (rows.isNotEmpty) {
      final range = '${SheetsConfig.tabCatalogo}!A2:C${rows.length + 1}';
      await _sheetsApi!.spreadsheets.values.update(
        sheets.ValueRange(values: rows),
        spreadsheetId,
        range,
        valueInputOption: 'USER_ENTERED',
      );
    }
  }

  // ==================== OPERACIONES HISTORIAL DE CORTES ====================

  /// Registra una fila congelada de corte operativo en la pestaña HISTORIAL_CORTES
  Future<int?> appendCorteHistorico(
    String spreadsheetId, {
    required String periodo,
    required int totalAsignados,
    required int totalConcluidos,
    required String efectividad,
    required String serviciosPorAjustador,
    required String tiempoPromArribo,
    required String duracionPromAtencion,
    required String desgloseCierres,
    String observaciones = '',
  }) async {
    _assertAuthenticated();
    await ensureSheetTabsAndHeaders(spreadsheetId);

    final now = DateTime.now();
    final dia = now.day.toString().padLeft(2, '0');
    final mes = now.month.toString().padLeft(2, '0');
    final anio = now.year.toString();
    final hora = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final fechaStr = '$dia/$mes/$anio $hora:$min';

    final row = [
      fechaStr,
      periodo,
      totalAsignados,
      totalConcluidos,
      efectividad,
      serviciosPorAjustador,
      tiempoPromArribo,
      duracionPromAtencion,
      desgloseCierres,
      observaciones,
    ];

    final valueRange = sheets.ValueRange(values: [row]);
    final response = await _sheetsApi!.spreadsheets.values.append(
      valueRange,
      spreadsheetId,
      '${SheetsConfig.tabHistorialCortes}!A:J',
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
    );

    final updatedRange = response.updates?.updatedRange;
    if (updatedRange != null) {
      final match = RegExp(r'!A(\d+):').firstMatch(updatedRange);
      if (match != null) {
        return int.tryParse(match.group(1)!);
      }
    }
    return null;
  }
}
