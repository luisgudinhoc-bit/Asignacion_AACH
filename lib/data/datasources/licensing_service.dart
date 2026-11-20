import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'local_storage_service.dart';

/// Modelo de estado de autorización y control de acceso por hardware
class EstadoLicencia {
  final bool autorizada;
  final String deviceId;
  final String nombreDispositivo;
  final String titular;
  final String estado; // ACTIVO, BLOQUEADO, VENCIDO, SIN LICENCIA, SIN CONEXIÓN
  final String tipoLicencia; // Administrador, Despacho Operativo, Demo
  final String fechaVencimiento;
  final String contactoAdmin;
  final String telefonoAdmin;
  final String motivoBloqueo;

  const EstadoLicencia({
    required this.autorizada,
    required this.deviceId,
    required this.nombreDispositivo,
    this.titular = 'Usuario No Registrado',
    this.estado = 'SIN LICENCIA',
    this.tipoLicencia = 'Asignacion AACH',
    this.fechaVencimiento = 'Pendiente',
    this.contactoAdmin = 'Luis Gudiño',
    this.telefonoAdmin = '+52 477 377 1473',
    this.motivoBloqueo = '',
  });

  /// Mensaje precargado para solicitud de activación inmediata por WhatsApp
  String get mensajeWhatsAppRenovacion {
    return 'Hola Luis, te comparto mi Código de Dispositivo para la activación de Asignacion AACH:\n\n'
        '• Código: $deviceId\n'
        '• Dispositivo: $nombreDispositivo\n'
        '• Usuario: $titular';
  }
}

/// Servicio singleton para control de acceso estricto por placa/hardware ID
class LicensingService {
  static final LicensingService _instance = LicensingService._internal();
  factory LicensingService() => _instance;
  LicensingService._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // Hoja central de control de licencias de Luis Gudiño - Pestaña exclusiva para Despacho AACH
  static const String urlGoogleSheetCsv =
      'https://docs.google.com/spreadsheets/d/11iwmA57GhfX--GZCY9ZGOSjN8Ah2Syhpu44LZii8NSs/gviz/tq?tqx=out:csv&sheet=Licencias%20AACH';

  static const String urlGoogleSheetCsvFallback =
      'https://docs.google.com/spreadsheets/d/11iwmA57GhfX--GZCY9ZGOSjN8Ah2Syhpu44LZii8NSs/export?format=csv&gid=1743757425';

  String? _cachedDeviceId;
  String? _cachedDeviceName;
  EstadoLicencia? _cachedEstado;

  EstadoLicencia? get estadoActual => _cachedEstado;

  static const MethodChannel _nativeChannel = MethodChannel('com.aach/hardware');

  /// Archivo donde se fija y persiste la identidad única de hardware
  Future<File?> _obtenerArchivoDeviceIdPersistente() async {
    if (kIsWeb) return null;
    try {
      final docs = await getApplicationDocumentsDirectory();
      return File('${docs.path}/hardware_identity.txt');
    } catch (_) {
      return null;
    }
  }

  /// Archivo de token de licencia local offline
  Future<File?> _obtenerArchivoTokenLocal() async {
    if (kIsWeb) return null;
    try {
      final docs = await getApplicationDocumentsDirectory();
      return File('${docs.path}/licencia_activa.json');
    } catch (_) {
      return null;
    }
  }

  /// Consulta el ANDROID_ID nativo de la placa base
  Future<String?> _obtenerAndroidIdNativo() async {
    if (kIsWeb) return null;
    try {
      if (Platform.isAndroid) {
        final id = await _nativeChannel.invokeMethod<String>('getHardwareId');
        if (id != null && id.trim().isNotEmpty) {
          return id.trim().toUpperCase();
        }
      }
    } catch (_) {}
    return null;
  }

  /// Obtiene la huella digital única (Hardware Fingerprint) de este teléfono o navegador
  Future<String> obtenerDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    // 0. Si estamos en Web, usar identidad persistente de LocalStorage
    if (kIsWeb) {
      String? webId = LocalStorageService.getString('hardware_web_device_id');
      if (webId == null || webId.isEmpty) {
        final randomPart = const Uuid().v4().substring(0, 8).toUpperCase();
        webId = 'WEB_BROWSER_$randomPart';
        await LocalStorageService.setString('hardware_web_device_id', webId);
      }
      _cachedDeviceId = webId;
      _cachedDeviceName = 'Navegador Web / PC';
      return _cachedDeviceId!;
    }

    // 1. Si ya se guardó una identidad permanente previa para este equipo, usarla
    try {
      final f = await _obtenerArchivoDeviceIdPersistente();
      if (f != null && await f.exists()) {
        final saved = (await f.readAsString()).trim().toUpperCase();
        if (saved.isNotEmpty) {
          _cachedDeviceId = saved;
          await obtenerNombreDispositivo();
          return _cachedDeviceId!;
        }
      }
    } catch (_) {}

    // 2. Si hay token previo local con deviceId
    try {
      final fToken = await _obtenerArchivoTokenLocal();
      if (fToken != null && await fToken.exists()) {
        final contenido = await fToken.readAsString();
        final data = jsonDecode(contenido) as Map<String, dynamic>;
        final savedId = (data['deviceId'] as String? ?? '').trim().toUpperCase();
        if (savedId.isNotEmpty) {
          _cachedDeviceId = savedId;
          try {
            final f = await _obtenerArchivoDeviceIdPersistente();
            if (f != null) await f.writeAsString(savedId);
          } catch (_) {}
          await obtenerNombreDispositivo();
          return _cachedDeviceId!;
        }
      }
    } catch (_) {}

    // 3. Generación inicial por placa/hardware real
    try {
      if (Platform.isAndroid) {
        final android = await _deviceInfo.androidInfo;
        final nativeId = await _obtenerAndroidIdNativo();
        final hardwareUniquePart = (nativeId != null && nativeId.isNotEmpty)
            ? nativeId
            : android.id;

        final raw = '${android.manufacturer}_${android.model}_$hardwareUniquePart';
        _cachedDeviceId = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_-]'), '');
        _cachedDeviceName = '${android.brand.toUpperCase()} ${android.model}';
      } else if (Platform.isIOS) {
        final ios = await _deviceInfo.iosInfo;
        _cachedDeviceId = (ios.identifierForVendor ?? 'IOS_UNKNOWN').toUpperCase();
        _cachedDeviceName = ios.name;
      } else {
        _cachedDeviceId = 'DEV_${Platform.operatingSystem.toUpperCase()}_${const Uuid().v4().substring(0, 8).toUpperCase()}';
        _cachedDeviceName = 'Dispositivo ${Platform.operatingSystem}';
      }

      // Guardar permanentemente
      try {
        final f = await _obtenerArchivoDeviceIdPersistente();
        if (f != null) await f.writeAsString(_cachedDeviceId!);
      } catch (_) {}
    } catch (_) {
      _cachedDeviceId = 'DEV_UNKNOWN_${DateTime.now().millisecondsSinceEpoch}';
      _cachedDeviceName = 'Dispositivo Móvil';
    }

    return _cachedDeviceId!;
  }

  Future<String> obtenerNombreDispositivo() async {
    if (_cachedDeviceName == null) await obtenerDeviceId();
    return _cachedDeviceName ?? 'Dispositivo Móvil';
  }

  /// Limpia la caché en memoria para obligar a una nueva consulta
  void invalidarCache() {
    _cachedEstado = null;
  }

  /// Guarda el token local cuando Google Sheets confirma que está ACTIVO
  Future<void> _guardarTokenLocal(EstadoLicencia lic) async {
    final data = {
      'deviceId': lic.deviceId,
      'autorizada': lic.autorizada,
      'titular': lic.titular,
      'estado': lic.estado,
      'tipoLicencia': lic.tipoLicencia,
      'fechaVencimiento': lic.fechaVencimiento,
      'ultimaVerificacion': DateTime.now().millisecondsSinceEpoch,
    };

    if (kIsWeb) {
      await LocalStorageService.setString('local_license_token', jsonEncode(data));
      return;
    }

    try {
      final f = await _obtenerArchivoTokenLocal();
      if (f != null) {
        await f.writeAsString(jsonEncode(data));
      }
    } catch (_) {}
  }

  /// Elimina el token local cuando Google Sheets lo BLOQUEA o elimina
  Future<void> _eliminarTokenLocal() async {
    if (kIsWeb) {
      await LocalStorageService.setString('local_license_token', '');
      return;
    }
    try {
      final f = await _obtenerArchivoTokenLocal();
      if (f != null && await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
  }

  /// Lee el token local
  Future<Map<String, dynamic>?> _leerTokenLocal() async {
    if (kIsWeb) {
      final raw = LocalStorageService.getString('local_license_token');
      if (raw != null && raw.isNotEmpty) {
        try {
          return jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {}
      }
      return null;
    }

    try {
      final f = await _obtenerArchivoTokenLocal();
      if (f != null && await f.exists()) {
        final contenido = await f.readAsString();
        return jsonDecode(contenido) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Parsea una línea de CSV respetando comillas y comas internas
  List<String> _parsearCsvLinea(String linea) {
    final List<String> columnas = [];
    final StringBuffer sb = StringBuffer();
    bool dentroDeComillas = false;

    for (int i = 0; i < linea.length; i++) {
      final char = linea[i];
      if (char == '"') {
        dentroDeComillas = !dentroDeComillas;
      } else if (char == ',' && !dentroDeComillas) {
        columnas.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(char);
      }
    }
    columnas.add(sb.toString().trim());
    return columnas.map((c) => c.replaceAll('"', '').trim()).toList();
  }

  /// Valida si una fecha de vencimiento ya expiró
  bool _estaVencida(String fechaStr) {
    final f = fechaStr.trim().toUpperCase();
    if (f.isEmpty || f == 'PERMANENTE' || f == 'ILIMITADO' || f == 'INDEFINIDO') {
      return false;
    }
    try {
      if (f.contains('/') || f.contains('-')) {
        final separador = f.contains('/') ? '/' : '-';
        final partes = f.split(separador);
        if (partes.length == 3) {
          int dia, mes, anio;
          if (partes[0].length == 4) {
            anio = int.parse(partes[0]);
            mes = int.parse(partes[1]);
            dia = int.parse(partes[2]);
          } else {
            dia = int.parse(partes[0]);
            mes = int.parse(partes[1]);
            anio = int.parse(partes[2]);
          }
          final fechaLimite = DateTime(anio, mes, dia, 23, 59, 59);
          return DateTime.now().isAfter(fechaLimite);
        }
      }
    } catch (_) {}
    return false;
  }

  /// Verifica si este dispositivo específico está en la lista autorizada en Google Sheets.
  /// Si está online: Consulta Google Sheets en tiempo real con Cache-Buster.
  /// Si está offline (sótano, carretera): Conserva acceso si ya estaba autorizado previamente (hasta 30 días).
  /// Si está bloqueado en Google Sheets: Lo expulsa y borra el token local de inmediato.
  Future<EstadoLicencia> verificarLicencia({bool forzarRefresco = true}) async {
    if (!forzarRefresco && _cachedEstado != null) return _cachedEstado!;

    final devId = await obtenerDeviceId();
    final devName = await obtenerNombreDispositivo();

    // 1. INTENTO DE CONSULTA EN VIVO A GOOGLE SHEETS
    try {
      http.Response responseSheet;
      try {
        final urlConBuster = '$urlGoogleSheetCsv&t=${DateTime.now().millisecondsSinceEpoch}';
        responseSheet = await http.get(
          Uri.parse(urlConBuster),
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0',
          },
        ).timeout(const Duration(seconds: 6));
      } catch (_) {
        final urlFallback = '$urlGoogleSheetCsvFallback&t=${DateTime.now().millisecondsSinceEpoch}';
        responseSheet = await http.get(
          Uri.parse(urlFallback),
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0',
          },
        ).timeout(const Duration(seconds: 6));
      }

      if (responseSheet.statusCode != 200) {
        final urlFallback = '$urlGoogleSheetCsvFallback&t=${DateTime.now().millisecondsSinceEpoch}';
        responseSheet = await http.get(
          Uri.parse(urlFallback),
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0',
          },
        ).timeout(const Duration(seconds: 6));
      }

      if (responseSheet.statusCode == 200 && responseSheet.body.isNotEmpty) {
        final bodyTrim = responseSheet.body.trim().toLowerCase();
        final esHtml = bodyTrim.startsWith('<html') ||
            bodyTrim.startsWith('<!doctype') ||
            bodyTrim.contains('<head') ||
            bodyTrim.contains('<body');

        if (esHtml) {
          throw Exception('Respuesta no es CSV');
        }

        final lineas = responseSheet.body.split(RegExp(r'\r?\n'));
        if (lineas.isNotEmpty) {
          // Detectar columnas dinámicamente
          int idxDeviceId = 0;
          int idxNombre = 1;
          int idxEstado = 2;
          int idxTipo = 3;
          int idxVencimiento = 5;

          final headerCols = _parsearCsvLinea(lineas[0]);
          for (int c = 0; c < headerCols.length; c++) {
            final colName = headerCols[c].toUpperCase();
            if (colName.contains('DISPOSITIVO') || colName.contains('CODIGO') || colName.contains('ID')) {
              idxDeviceId = c;
            } else if (colName.contains('NOMBRE') || colName.contains('USUARIO') || colName.contains('TITULAR')) {
              idxNombre = c;
            } else if (colName.contains('ESTADO') || colName.contains('STATUS')) {
              idxEstado = c;
            } else if (colName.contains('TIPO')) {
              idxTipo = c;
            } else if (colName.contains('VENCIMIENTO') || colName.contains('EXPIRA') || colName.contains('FIN')) {
              idxVencimiento = c;
            }
          }

          // Recorrer filas
          for (int i = 1; i < lineas.length; i++) {
            final linea = lineas[i];
            if (linea.trim().isEmpty) continue;
            final columnas = _parsearCsvLinea(linea);

            if (columnas.isNotEmpty && columnas.length > idxDeviceId) {
              final idEnSheet = columnas[idxDeviceId].trim().toUpperCase();
              if (idEnSheet.isEmpty) continue;

              final devUpper = devId.trim().toUpperCase();
              bool esMismoDispositivo = false;

              if (idEnSheet == devUpper) {
                esMismoDispositivo = true;
              } else {
                // Coincidencia por partes de hardware
                final devParts = devUpper.split('_');
                final sheetParts = idEnSheet.split('_');
                if (devParts.length >= 3 && sheetParts.length >= 3) {
                  final devSuffix = devParts.sublist(2).join('_');
                  final sheetSuffix = sheetParts.sublist(2).join('_');
                  if (devSuffix.isNotEmpty && devSuffix == sheetSuffix) {
                    esMismoDispositivo = true;
                  }
                }
              }

              if (esMismoDispositivo) {
                final nombreEnSheet = columnas.length > idxNombre ? columnas[idxNombre].trim() : 'Usuario AACH';
                final estadoEnSheet = columnas.length > idxEstado ? columnas[idxEstado].trim().toUpperCase() : 'ACTIVO';
                final tipoLic = columnas.length > idxTipo ? columnas[idxTipo].trim() : 'Asignacion AACH';
                final vencimiento = columnas.length > idxVencimiento ? columnas[idxVencimiento].trim() : '31/12/2099';

                final bool esBloqueadoExplicito = estadoEnSheet == 'BLOQUEADO' ||
                    estadoEnSheet == 'INACTIVO' ||
                    estadoEnSheet == 'SUSPENDIDO' ||
                    estadoEnSheet == 'BAJA' ||
                    estadoEnSheet == 'REVOCADO' ||
                    estadoEnSheet == 'CANCELADO' ||
                    estadoEnSheet == 'NO' ||
                    estadoEnSheet == 'FALSE' ||
                    estadoEnSheet == 'OFF' ||
                    estadoEnSheet.startsWith('BLOQ') ||
                    estadoEnSheet.startsWith('INACT');

                final bool esActivoExplicito = estadoEnSheet == 'ACTIVO' ||
                    estadoEnSheet == 'SI' ||
                    estadoEnSheet == 'TRUE' ||
                    estadoEnSheet == 'AUTORIZADO' ||
                    estadoEnSheet == 'VIGENTE' ||
                    estadoEnSheet == 'OK' ||
                    estadoEnSheet == 'ADMIN';

                final bool vencida = _estaVencida(vencimiento);

                if (esBloqueadoExplicito) {
                  await _eliminarTokenLocal();
                  _cachedEstado = EstadoLicencia(
                    autorizada: false,
                    deviceId: devId,
                    nombreDispositivo: devName,
                    titular: nombreEnSheet.isNotEmpty ? nombreEnSheet : 'Usuario AACH',
                    estado: estadoEnSheet,
                    tipoLicencia: tipoLic.isNotEmpty ? tipoLic : 'Asignacion AACH',
                    fechaVencimiento: vencimiento,
                    motivoBloqueo:
                        'Dispositivo suspendido o bloqueado por Luis Gudiño en Google Sheets. Comunícate al +52 477 377 1473.',
                  );
                  return _cachedEstado!;
                }

                if (vencida) {
                  await _eliminarTokenLocal();
                  _cachedEstado = EstadoLicencia(
                    autorizada: false,
                    deviceId: devId,
                    nombreDispositivo: devName,
                    titular: nombreEnSheet.isNotEmpty ? nombreEnSheet : 'Usuario AACH',
                    estado: 'VENCIDO',
                    tipoLicencia: tipoLic.isNotEmpty ? tipoLic : 'Asignacion AACH',
                    fechaVencimiento: vencimiento,
                    motivoBloqueo:
                        'El periodo de activación expiró el $vencimiento. Comunícate con Luis Gudiño (+52 477 377 1473).',
                  );
                  return _cachedEstado!;
                }

                if (esActivoExplicito) {
                  final licOk = EstadoLicencia(
                    autorizada: true,
                    deviceId: devId,
                    nombreDispositivo: devName,
                    titular: nombreEnSheet.isNotEmpty ? nombreEnSheet : 'Usuario Autorizado',
                    estado: 'ACTIVO',
                    tipoLicencia: tipoLic.isNotEmpty ? tipoLic : 'Asignacion AACH',
                    fechaVencimiento: vencimiento.isNotEmpty ? vencimiento : '31/12/2099',
                    motivoBloqueo: '',
                  );
                  await _guardarTokenLocal(licOk);
                  _cachedEstado = licOk;
                  return _cachedEstado!;
                }

                // Estado desconocido
                await _eliminarTokenLocal();
                _cachedEstado = EstadoLicencia(
                  autorizada: false,
                  deviceId: devId,
                  nombreDispositivo: devName,
                  titular: nombreEnSheet,
                  estado: estadoEnSheet,
                  tipoLicencia: tipoLic,
                  fechaVencimiento: vencimiento,
                  motivoBloqueo:
                      'Estado "$estadoEnSheet" no autorizado. Contacta a Luis Gudiño (+52 477 377 1473).',
                );
                return _cachedEstado!;
              }
            }
          }
        }

        // Si se recorrió todo el Sheet y NO se encontró el Device ID:
        final localData = await _leerTokenLocal();
        if (localData != null) {
          final bool fueAutorizada = localData['autorizada'] as bool? ?? false;
          final String savedId = localData['deviceId'] as String? ?? '';
          final int timestampUltima = localData['ultimaVerificacion'] as int? ?? 0;
          final diferenciaDias = (DateTime.now().millisecondsSinceEpoch - timestampUltima) / (1000 * 60 * 60 * 24);

          if (fueAutorizada && savedId.toUpperCase() == devId.toUpperCase() && diferenciaDias < 30) {
            _cachedEstado = EstadoLicencia(
              autorizada: true,
              deviceId: devId,
              nombreDispositivo: devName,
              titular: localData['titular'] as String? ?? 'Usuario AACH',
              estado: 'ACTIVO (Respaldo Local)',
              tipoLicencia: localData['tipoLicencia'] as String? ?? 'Asignacion AACH',
              fechaVencimiento: localData['fechaVencimiento'] as String? ?? '31/12/2099',
              motivoBloqueo: '',
            );
            return _cachedEstado!;
          }
        }

        await _eliminarTokenLocal();
        _cachedEstado = EstadoLicencia(
          autorizada: false,
          deviceId: devId,
          nombreDispositivo: devName,
          titular: 'Dispositivo No Registrado',
          estado: 'SIN LICENCIA',
          tipoLicencia: 'Sin Autorización Activa',
          fechaVencimiento: 'Pendiente de Alta',
          motivoBloqueo:
              'Este dispositivo no se encuentra dado de alta en la lista de licencias de Luis Gudiño. Envía tu ID por WhatsApp para activarlo.',
        );
        return _cachedEstado!;
      }
    } catch (_) {
      // Error de red / sin internet
    }

    // 2. MODO OFFLINE / TERRENO:
    // Si no hay internet, verificar si ya contaba con token local autorizado
    final localData = await _leerTokenLocal();
    if (localData != null) {
      final bool fueAutorizada = localData['autorizada'] as bool? ?? false;
      final String savedId = localData['deviceId'] as String? ?? '';
      final int timestampUltima = localData['ultimaVerificacion'] as int? ?? 0;
      final diferenciaDias = (DateTime.now().millisecondsSinceEpoch - timestampUltima) / (1000 * 60 * 60 * 24);

      if (fueAutorizada && savedId.toUpperCase() == devId.toUpperCase() && diferenciaDias < 30) {
        _cachedEstado = EstadoLicencia(
          autorizada: true,
          deviceId: devId,
          nombreDispositivo: devName,
          titular: localData['titular'] as String? ?? 'Usuario AACH',
          estado: 'ACTIVO (Modo Terreno)',
          tipoLicencia: localData['tipoLicencia'] as String? ?? 'Asignacion AACH',
          fechaVencimiento: localData['fechaVencimiento'] as String? ?? '31/12/2099',
          motivoBloqueo: '',
        );
        return _cachedEstado!;
      }
    }

    // Si nunca ha sido autorizada online y no hay conexión
    _cachedEstado = EstadoLicencia(
      autorizada: false,
      deviceId: devId,
      nombreDispositivo: devName,
      titular: 'Activación Inicial',
      estado: 'SIN CONEXIÓN',
      tipoLicencia: 'Activación requerida',
      fechaVencimiento: 'Pendiente',
      motivoBloqueo:
          'Se requiere conexión a internet la primera vez para verificar tu dispositivo con Google Sheets. Conéctate a WiFi o datos y reintenta.',
    );
    return _cachedEstado!;
  }
}
