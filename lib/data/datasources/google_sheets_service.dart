import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import '../../core/constants/sheets_config.dart';
import '../../domain/models/ajustador_model.dart';
import '../../domain/models/aseguradora_model.dart';
import '../../domain/models/siniestro_model.dart';
import 'local_storage_service.dart';

/// Cliente HTTP autenticado con cabeceras Bearer de Google Sign-In
class _AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _AuthenticatedClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
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
        final authHeaders = await account.authHeaders;
        final authClient = _AuthenticatedClient(authHeaders);
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
        final authHeaders = await account.authHeaders;
        final authClient = _AuthenticatedClient(authHeaders);
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

      if (requests.isNotEmpty) {
        await _sheetsApi!.spreadsheets.batchUpdate(
          sheets.BatchUpdateSpreadsheetRequest(requests: requests),
          spreadsheetId,
        );
      }

      // Escribir encabezados si no existen
      await _writeHeadersIfEmpty(
        spreadsheetId,
        '${SheetsConfig.tabSiniestros}!A1:U1',
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

  /// Agrega un nuevo siniestro a la pestaña SINIESTROS
  Future<int?> appendSiniestro(String spreadsheetId, SiniestroModel siniestro) async {
    _assertAuthenticated();
    final valueRange = sheets.ValueRange(
      values: [siniestro.toSheetsRow()],
    );

    final response = await _sheetsApi!.spreadsheets.values.append(
      valueRange,
      spreadsheetId,
      '${SheetsConfig.tabSiniestros}!A:U',
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
    );

    // Extraer número de fila actualizado (ej: "SINIESTROS!A15:U15" -> 15)
    final updatedRange = response.updates?.updatedRange;
    if (updatedRange != null) {
      final match = RegExp(r'!A(\d+):').firstMatch(updatedRange);
      if (match != null) {
        return int.tryParse(match.group(1)!);
      }
    }
    return null;
  }

  /// Actualiza un siniestro existente en la hoja
  Future<void> updateSiniestro(String spreadsheetId, SiniestroModel siniestro) async {
    _assertAuthenticated();

    // 1. Si ya se conoce el número de fila, actualizar directamente
    if (siniestro.rowNumberSheets != null && siniestro.rowNumberSheets! > 1) {
      final range = '${SheetsConfig.tabSiniestros}!A${siniestro.rowNumberSheets}:U${siniestro.rowNumberSheets}';
      final valueRange = sheets.ValueRange(
        range: range,
        values: [siniestro.toSheetsRow()],
      );
      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        spreadsheetId,
        range,
        valueInputOption: 'USER_ENTERED',
      );
      return;
    }

    // 2. Si no se conoce la fila, buscar por ID o por Folio en la columna A y B
    final idRange = await _sheetsApi!.spreadsheets.values.get(
      spreadsheetId,
      '${SheetsConfig.tabSiniestros}!A:B',
    );

    int targetRow = -1;
    if (idRange.values != null) {
      for (int i = 0; i < idRange.values!.length; i++) {
        final row = idRange.values![i];
        final idCol = row.isNotEmpty ? row[0].toString() : '';
        final folioCol = row.length > 1 ? row[1].toString() : '';

        if (idCol == siniestro.id || (siniestro.folio.isNotEmpty && folioCol == siniestro.folio)) {
          targetRow = i + 1; // 1-based index
          break;
        }
      }
    }

    if (targetRow > 1) {
      final range = '${SheetsConfig.tabSiniestros}!A$targetRow:U$targetRow';
      final valueRange = sheets.ValueRange(
        range: range,
        values: [siniestro.toSheetsRow()],
      );
      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        spreadsheetId,
        range,
        valueInputOption: 'USER_ENTERED',
      );
    } else {
      // Si no fue encontrado, anexarlo como nueva fila
      await appendSiniestro(spreadsheetId, siniestro);
    }
  }

  /// Lee todos los siniestros registrados en Google Sheets
  Future<List<SiniestroModel>> fetchSiniestros(String spreadsheetId) async {
    _assertAuthenticated();
    final response = await _sheetsApi!.spreadsheets.values.get(
      spreadsheetId,
      '${SheetsConfig.tabSiniestros}!A2:U',
    );

    final list = <SiniestroModel>[];
    if (response.values != null) {
      for (int i = 0; i < response.values!.length; i++) {
        final row = response.values![i];
        if (row.isNotEmpty) {
          final rowNumber = i + 2; // +2 por encabezado y 1-based index
          list.add(SiniestroModel.fromSheetsRow(row, rowNumber: rowNumber));
        }
      }
    }
    return list;
  }
}
