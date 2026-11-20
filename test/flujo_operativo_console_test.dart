import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:asignacion_aach/core/constants/app_constants.dart';
import 'package:asignacion_aach/core/services/whatsapp_service.dart';
import 'package:asignacion_aach/core/utils/date_formatter.dart';
import 'package:asignacion_aach/domain/models/ajustador_model.dart';
import 'package:asignacion_aach/domain/models/siniestro_metrics.dart';
import 'package:asignacion_aach/domain/models/siniestro_model.dart';
import 'package:asignacion_aach/domain/models/sync_item_model.dart';
import 'package:asignacion_aach/domain/services/whatsapp_parser_service.dart';

void main() {
  test('Simulacion Operativa Completa en Consola - Asignacion AACH', () async {
    stdout.writeln('');
    stdout.writeln('======================================================================');
    stdout.writeln('        🚨 SIMULADOR OPERATIVO EN CONSOLA - ASIGNACIÓN AACH 🚨        ');
    stdout.writeln('======================================================================');

    // 1. Inicialización de Hive
    stdout.writeln('\n[1/5] INICIALIZANDO PERSISTENCIA LOCAL OFFLINE-FIRST (HIVE)...');
    final tempDir = Directory.systemTemp.createTempSync('aach_test_');
    Hive.init(tempDir.path);

    final siniestrosBox = await Hive.openBox(AppConstants.siniestrosBox);
    final ajustadoresBox = await Hive.openBox(AppConstants.ajustadoresBox);
    final syncQueueBox = await Hive.openBox(AppConstants.syncQueueBox);

    for (final aj in AjustadorModel.defaultAjustadores) {
      await ajustadoresBox.put(aj.id, aj.toMap());
    }
    stdout.writeln('  ✅ Base de datos NoSQL Hive inicializada en: ${tempDir.path}');
    stdout.writeln('  ✅ Ajustadores de despacho cargados: Axel, Alejandro, Ian, Luis');

    // 2. Parser Inteligente de WhatsApp
    stdout.writeln('\n[2/5] PARSER INTELIGENTE DE WHATSAPP (MENSAJE REAL CABINA QUALITAS)...');
    const mensajeQualitas = '''
*CABINA QUALITAS REPORTA*
REPORTE: 0424123456
ASEGURADO: ROBERTO HERNANDEZ DIAZ
TEL: 5541998877
VEHICULO: NISSAN VERSA 2021 COLOR BLANCO
PLACAS: NXZ4433
UBICACION: AV INSURGENTES SUR 1602 COL CREDITO CONSTRUCTOR CDMX
MAPS: https://maps.app.goo.gl/abcdef12345
POLIZA: 123456789
CABINA SOLICITA ARRIBO INMEDIATO
''';

    final parsed = WhatsAppParserService.parse(mensajeQualitas);
    stdout.writeln('  🔍 Campos extraídos por Regex:');
    stdout.writeln('     • Folio:           ${parsed.folio}');
    stdout.writeln('     • Aseguradora:     ${parsed.aseguradora} (Normalizada)');
    stdout.writeln('     • Asegurado:       ${parsed.asegurado}');
    stdout.writeln('     • Teléfono:        ${parsed.telefonoAsegurado}');
    stdout.writeln('     • Vehículo:        ${parsed.vehiculo}');
    stdout.writeln('     • Color:           ${parsed.colorVehiculo}');
    stdout.writeln('     • Placas:          ${parsed.placas}');
    stdout.writeln('     • Enlace Maps:     ${parsed.linkMaps}');

    expect(parsed.folio, '0424123456');
    expect(parsed.aseguradora, 'Quálitas');

    // 3. Creación y Persistencia de Siniestro
    stdout.writeln('\n[3/5] CREANDO SINIESTRO Y GENERANDO FICHA OPERATIVA...');
    final fechaAsignacion = DateTime.now().subtract(const Duration(minutes: 35));

    final siniestro1 = SiniestroModel(
      folio: parsed.folio ?? 'S/F-01',
      aseguradora: parsed.aseguradora ?? 'Quálitas',
      ajustador: 'Axel',
      tipoEvento: 'Choque',
      ubicacion: parsed.ubicacion ?? '',
      linkMaps: parsed.linkMaps ?? '',
      asegurado: parsed.asegurado ?? '',
      telefonoAsegurado: parsed.telefonoAsegurado ?? '',
      vehiculo: parsed.vehiculo ?? '',
      colorVehiculo: parsed.colorVehiculo ?? '',
      placas: parsed.placas ?? '',
      poliza: parsed.poliza ?? '',
      fechaAsignacion: fechaAsignacion,
    );

    await siniestrosBox.put(siniestro1.id, siniestro1.toMap());

    final syncItem = SyncItemModel(
      siniestroId: siniestro1.id,
      action: SyncAction.create,
      payload: siniestro1.toMap(),
    );
    await syncQueueBox.put(syncItem.id, syncItem.toMap());

    stdout.writeln('  ✅ Siniestro persistido en Hive (ID: ${siniestro1.id})');
    stdout.writeln('  ✅ Encolado en SyncQueue (${syncQueueBox.length} pendientes de enviar a Sheets)');

    final fichaWhatsApp = WhatsAppService.buildAsignacionMessage(
      folio: siniestro1.folio,
      aseguradora: siniestro1.aseguradora,
      ajustador: siniestro1.ajustador,
      tipoEvento: siniestro1.tipoEvento,
      vehiculo: siniestro1.vehiculo,
      colorVehiculo: siniestro1.colorVehiculo,
      placas: siniestro1.placas,
      asegurado: siniestro1.asegurado,
      telefonoAsegurado: siniestro1.telefonoAsegurado,
      ubicacion: siniestro1.ubicacion,
      linkMaps: siniestro1.linkMaps,
      fechaHora: siniestro1.fechaAsignacion,
    );

    expect(fichaWhatsApp.contains('Nissan Versa 2021 Blanco'), isTrue);

    stdout.writeln('\n  📱 Ficha WhatsApp formateada para el ajustador:');
    stdout.writeln('------------------------------------------------------------');
    stdout.writeln(fichaWhatsApp);
    stdout.writeln('------------------------------------------------------------');

    // 4. Ciclo de Vida y Transición de Estados
    stdout.writeln('[4/5] SIMULANDO TRANSICIÓN DE ESTADOS (FLUJO OPERATIVO)...');
    stdout.writeln('  🟡 Estado Inicial: ${siniestro1.estatus.displayName} (${DateFormatter.timeElapsed(siniestro1.fechaAsignacion)})');

    final fechaArribo = fechaAsignacion.add(const Duration(minutes: 20));
    final enAtencion = siniestro1.copyWith(
      estatus: SiniestroEstatus.enAtencion,
      fechaArribo: fechaArribo,
    );
    await siniestrosBox.put(enAtencion.id, enAtencion.toMap());
    stdout.writeln('  🔵 Transición a: ${enAtencion.estatus.displayName} (Tiempo de arribo: ${fechaArribo.difference(fechaAsignacion).inMinutes} min)');

    final fechaCierre = fechaArribo.add(const Duration(minutes: 35));
    final concluido = enAtencion.copyWith(
      estatus: SiniestroEstatus.concluido,
      fechaConclusion: fechaCierre,
      tipoCierre: 'Con Convenio',
    );
    await siniestrosBox.put(concluido.id, concluido.toMap());
    stdout.writeln('  🟢 Transición a: ${concluido.estatus.displayName} [Tipo: ${concluido.tipoCierre}] (Duración atención: ${fechaCierre.difference(fechaArribo).inMinutes} min)');

    // 5. Métricas y Corte Operativo
    stdout.writeln('\n[5/5] CÁLCULO DE MÉTRICAS Y CORTE OPERATIVO...');

    final siniestro2 = SiniestroModel(
      folio: 'INB-887766',
      aseguradora: 'Inbursa',
      ajustador: 'Alejandro',
      estatus: SiniestroEstatus.concluido,
      tipoCierre: 'Volante de Admisión',
      fechaAsignacion: DateTime.now().subtract(const Duration(hours: 2)),
      fechaArribo: DateTime.now().subtract(const Duration(hours: 1, minutes: 40)),
      fechaConclusion: DateTime.now().subtract(const Duration(hours: 1)),
    );
    final siniestro3 = SiniestroModel(
      folio: 'GNP-554433',
      aseguradora: 'GNP Seguros',
      ajustador: 'Ian',
      estatus: SiniestroEstatus.enAtencion,
      fechaAsignacion: DateTime.now().subtract(const Duration(minutes: 30)),
      fechaArribo: DateTime.now().subtract(const Duration(minutes: 10)),
    );
    final siniestro4 = SiniestroModel(
      folio: 'AXA-112233',
      aseguradora: 'AXA Seguros',
      ajustador: 'Luis',
      estatus: SiniestroEstatus.asignado,
      fechaAsignacion: DateTime.now().subtract(const Duration(minutes: 5)),
    );

    final todosSiniestros = [concluido, siniestro2, siniestro3, siniestro4];
    final metrics = SiniestroMetrics.fromList(todosSiniestros);

    stdout.writeln('  📊 Total de Siniestros:       ${metrics.total}');
    stdout.writeln('  🟢 Concluidos:                ${metrics.concluidos}');
    stdout.writeln('  🔵 En Atención / Arribo:      ${metrics.enAtencion}');
    stdout.writeln('  🟡 Asignados (Pendientes):    ${metrics.asignados}');
    stdout.writeln('  ⏱️ Tiempo Promedio de Arribo: ${metrics.tiempoPromedioArribo?.inMinutes ?? 0} min');
    stdout.writeln('  ⏱️ Duración Prom. Atención:  ${metrics.tiempoPromedioConclusion?.inMinutes ?? 0} min');
    stdout.writeln('  📋 Desglose de Cierres:       ${metrics.desgloseCierres}');
    stdout.writeln('  👤 Desglose por Ajustador:    ${metrics.desgloseAjustadores}');

    expect(metrics.total, 4);
    expect(metrics.concluidos, 2);

    await Hive.close();
    tempDir.deleteSync(recursive: true);

    stdout.writeln('\n======================================================================');
    stdout.writeln('  ✅ SIMULACIÓN DE CONSOLA FINALIZADA CON ÉXITO: 100% OPERATIVO       ');
    stdout.writeln('======================================================================\n');
  });
}
