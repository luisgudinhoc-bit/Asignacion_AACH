import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/location_service.dart';
import '../../core/services/whatsapp_service.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/siniestro_model.dart';
import '../../domain/services/arco_norte_service.dart';
import '../../domain/services/location_resolver_service.dart';
import '../../domain/services/whatsapp_parser_service.dart';
import '../providers/ajustador_provider.dart';
import '../providers/aseguradora_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/siniestro_provider.dart';
import '../widgets/cabina_parser_card.dart';
import 'sync_status_screen.dart';

enum SendMode { none, ajustador, grupo }

/// Formulario de Asignación Rápida y Edición de Siniestros
class AsignacionRapidaScreen extends ConsumerStatefulWidget {
  final bool isStandaloneScreen;
  final SiniestroModel? siniestroToEdit;

  const AsignacionRapidaScreen({
    super.key,
    this.isStandaloneScreen = false,
    this.siniestroToEdit,
  });

  @override
  ConsumerState<AsignacionRapidaScreen> createState() => _AsignacionRapidaScreenState();
}

class _AsignacionRapidaScreenState extends ConsumerState<AsignacionRapidaScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores de texto
  final _folioController = TextEditingController();
  final _aseguradoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _vehiculoController = TextEditingController();
  final _colorController = TextEditingController();
  final _placasController = TextEditingController();
  final _polizaController = TextEditingController();

  // Ubicación estructurada: Municipio, Estado, Referencias y Maps opcional
  final _municipioController = TextEditingController();
  final _estadoController = TextEditingController();
  final _referenciasController = TextEditingController();
  final _mapsController = TextEditingController();

  final _observacionesController = TextEditingController();
  final _otroTipoEventoController = TextEditingController();

  // Estados de selección rápida (Chips)
  String _selectedAseguradora = 'Inbursa';
  String _selectedTipoEvento = 'Choque';
  String? _selectedAjustadorId;
  String _selectedAjustadorNombre = '';
  String _selectedAjustadorTelefono = '';

  bool _isGettingGps = false;
  bool _isResolvingLocation = false;
  String? _parsedHoraAsignacion;

  @override
  void initState() {
    super.initState();
    if (widget.siniestroToEdit != null) {
      final s = widget.siniestroToEdit!;
      _folioController.text = s.folio;
      _selectedAseguradora = s.aseguradora;
      _selectedAjustadorNombre = s.ajustador;
      if (s.tipoEvento.contains(':')) {
        _selectedTipoEvento = s.tipoEvento.split(':').first.trim();
        _otroTipoEventoController.text = s.tipoEvento.split(':').last.trim();
      } else {
        _selectedTipoEvento = s.tipoEvento;
      }
      _aseguradoController.text = s.asegurado;
      _telefonoController.text = s.telefonoAsegurado;
      _vehiculoController.text = s.vehiculo;
      _colorController.text = s.colorVehiculo;
      _placasController.text = s.placas;
      _polizaController.text = s.poliza;
      _municipioController.text = s.municipio;
      _estadoController.text = s.estado;
      _referenciasController.text = s.referencias.isNotEmpty ? s.referencias : s.ubicacion;
      _mapsController.text = s.linkMaps;
      _observacionesController.text = s.observaciones;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ajustadores = ref.read(activeAjustadoresProvider);
        final match = ajustadores.where(
          (a) =>
              a.nombre.toLowerCase() == s.ajustador.toLowerCase() ||
              s.ajustador.toLowerCase().contains(a.nombre.toLowerCase()) ||
              a.nombre.toLowerCase().contains(s.ajustador.toLowerCase()),
        ).firstOrNull;
        if (match != null && mounted) {
          setState(() {
            _selectedAjustadorId = match.id;
            _selectedAjustadorTelefono = match.telefonoWhatsApp;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _folioController.dispose();
    _aseguradoController.dispose();
    _telefonoController.dispose();
    _vehiculoController.dispose();
    _colorController.dispose();
    _placasController.dispose();
    _polizaController.dispose();
    _municipioController.dispose();
    _estadoController.dispose();
    _referenciasController.dispose();
    _mapsController.dispose();
    _observacionesController.dispose();
    _otroTipoEventoController.dispose();
    super.dispose();
  }

  Future<void> _resolveLocationFromMaps(String url) async {
    if (url.trim().isEmpty) return;
    setState(() => _isResolvingLocation = true);
    try {
      final resolved = await LocationResolverService.resolveFromMapsUrl(url);
      if (resolved != null && mounted) {
        setState(() {
          if (resolved.municipio != null && resolved.municipio!.isNotEmpty) {
            _municipioController.text = resolved.municipio!;
          }
          if (resolved.estado != null && resolved.estado!.isNotEmpty) {
            _estadoController.text = resolved.estado!;
          }
          if (resolved.calle != null && resolved.calle!.isNotEmpty) {
            if (_referenciasController.text.isEmpty) {
              _referenciasController.text = resolved.calle!;
            } else if (!_referenciasController.text.contains(resolved.calle!)) {
              _referenciasController.text = '${resolved.calle!} • ${_referenciasController.text}';
            }
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 Ubicación resuelta: ${resolved.municipio ?? ""} ${resolved.estado ?? ""}'),
            backgroundColor: AppColors.statusConcluido,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResolvingLocation = false);
    }
  }

  void _applyParsedData(ParsedCabinaMessage parsed) {
    setState(() {
      if (parsed.folio != null && parsed.folio!.isNotEmpty) {
        _folioController.text = parsed.folio!;
      }
      if (parsed.aseguradora != null && parsed.aseguradora!.isNotEmpty) {
        _selectedAseguradora = parsed.aseguradora!;
      }
      if (parsed.asegurado != null && parsed.asegurado!.isNotEmpty) {
        _aseguradoController.text = parsed.asegurado!;
      }
      if (parsed.telefonoAsegurado != null && parsed.telefonoAsegurado!.isNotEmpty) {
        _telefonoController.text = parsed.telefonoAsegurado!;
      }
      if (parsed.vehiculo != null && parsed.vehiculo!.isNotEmpty) {
        _vehiculoController.text = parsed.vehiculo!;
      }
      if (parsed.colorVehiculo != null && parsed.colorVehiculo!.isNotEmpty) {
        _colorController.text = parsed.colorVehiculo!;
      }
      if (parsed.placas != null && parsed.placas!.isNotEmpty) {
        _placasController.text = parsed.placas!;
      }
      if (parsed.poliza != null && parsed.poliza!.isNotEmpty) {
        _polizaController.text = parsed.poliza!;
      }

      // Ubicación
      if (parsed.municipio != null && parsed.municipio!.isNotEmpty) {
        _municipioController.text = parsed.municipio!;
      }
      if (parsed.estado != null && parsed.estado!.isNotEmpty) {
        _estadoController.text = parsed.estado!;
      }
      if (parsed.referencias != null && parsed.referencias!.isNotEmpty) {
        _referenciasController.text = parsed.referencias!;
      } else if (parsed.ubicacion != null && parsed.ubicacion!.isNotEmpty) {
        _referenciasController.text = parsed.ubicacion!;
      }

      if (parsed.linkMaps != null && parsed.linkMaps!.isNotEmpty) {
        _mapsController.text = parsed.linkMaps!;
        _resolveLocationFromMaps(parsed.linkMaps!);
      }
      if (parsed.tipoEvento != null && parsed.tipoEvento!.isNotEmpty) {
        _selectedTipoEvento = parsed.tipoEvento!;
      }
      if (parsed.detalleEvento != null && parsed.detalleEvento!.isNotEmpty) {
        _otroTipoEventoController.text = parsed.detalleEvento!;
      }
      if (parsed.observaciones != null && parsed.observaciones!.isNotEmpty) {
        _observacionesController.text = parsed.observaciones!;
      }
      if (parsed.horaAsignacion != null && parsed.horaAsignacion!.isNotEmpty) {
        _parsedHoraAsignacion = parsed.horaAsignacion;
      }

      // Ajustador detectado por mención en WhatsApp
      if (parsed.ajustador != null && parsed.ajustador!.isNotEmpty) {
        final ajustadores = ref.read(activeAjustadoresProvider);
        final match = ajustadores.where(
          (a) =>
              a.nombre.toLowerCase().contains(parsed.ajustador!.toLowerCase()) ||
              parsed.ajustador!.toLowerCase().contains(a.nombre.toLowerCase()),
        ).firstOrNull;
        if (match != null) {
          _selectedAjustadorId = match.id;
          _selectedAjustadorNombre = match.nombre;
          _selectedAjustadorTelefono = match.telefonoWhatsApp;
        }
      }
    });
  }

  Future<void> _pasteFolioFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      setState(() {
        _folioController.text = data.text!.trim().toUpperCase();
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingGps = true);
    try {
      final pos = await LocationService.getCurrentLocation();
      if (pos != null) {
        final url = pos.mapsUrl;
        setState(() {
          _mapsController.text = url;
        });
        _resolveLocationFromMaps(url);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo obtener la ubicación GPS.'),
              backgroundColor: AppColors.statusCancelado,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error GPS: $e'), backgroundColor: AppColors.statusCancelado),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingGps = false);
    }
  }

  bool get _hasAnyInfo =>
      _folioController.text.trim().isNotEmpty ||
      _aseguradoController.text.trim().isNotEmpty ||
      _telefonoController.text.trim().isNotEmpty ||
      _vehiculoController.text.trim().isNotEmpty ||
      _colorController.text.trim().isNotEmpty ||
      _municipioController.text.trim().isNotEmpty ||
      _referenciasController.text.trim().isNotEmpty ||
      _mapsController.text.trim().isNotEmpty ||
      _observacionesController.text.trim().isNotEmpty ||
      _selectedAjustadorNombre.isNotEmpty;

  Future<void> _saveAndSend({required SendMode mode}) async {
    // Para registrar no es obligatorio el siniestro, basta con meter algo de información
    if (!_hasAnyInfo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese al menos algún dato del siniestro (ubicación, vehículo, folio, notas) para registrar.'),
          backgroundColor: AppColors.statusCancelado,
        ),
      );
      return;
    }

    // Si se eligió enviar directo al ajustador, se valida que haya un ajustador con teléfono
    if (mode == SendMode.ajustador) {
      if (_selectedAjustadorTelefono.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Para envío directo seleccione un ajustador con teléfono, o use "Enviar al Grupo".'),
            backgroundColor: AppColors.statusAsignado,
          ),
        );
        return;
      }
    }

    var now = DateTime.now();
    if (_parsedHoraAsignacion != null) {
      try {
        final parts = _parsedHoraAsignacion!.split(':');
        if (parts.length == 2) {
          final h = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          now = DateTime(now.year, now.month, now.day, h, m);
        }
      } catch (_) {}
    }

    // Folio flexible: si está vacío se autogenera S/F con marca temporal
    final rawFolio = _folioController.text.trim();
    final folioFinal = rawFolio.isNotEmpty
        ? rawFolio.toUpperCase()
        : 'S/F-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

    final ajustadorFinal = _selectedAjustadorNombre.isNotEmpty
        ? _selectedAjustadorNombre
        : 'Sin Asignar';

    final tipoEventoFinal = ((_selectedTipoEvento == 'Diverso' || _selectedTipoEvento == 'Otro') &&
            _otroTipoEventoController.text.trim().isNotEmpty)
        ? '$_selectedTipoEvento: ${_otroTipoEventoController.text.trim()}'
        : _selectedTipoEvento;

    final isEditing = widget.siniestroToEdit != null;
    SiniestroModel siniestroFinal;

    if (isEditing) {
      final original = widget.siniestroToEdit!;
      siniestroFinal = original.copyWith(
        folio: folioFinal,
        aseguradora: _selectedAseguradora,
        ajustador: ajustadorFinal,
        tipoEvento: tipoEventoFinal,
        municipio: _municipioController.text.trim(),
        estado: _estadoController.text.trim(),
        referencias: _referenciasController.text.trim(),
        ubicacion: _referenciasController.text.trim(),
        linkMaps: _mapsController.text.trim(),
        asegurado: _aseguradoController.text.trim(),
        telefonoAsegurado: _telefonoController.text.trim(),
        vehiculo: _vehiculoController.text.trim(),
        colorVehiculo: _colorController.text.trim(),
        placas: _placasController.text.trim().toUpperCase(),
        poliza: _polizaController.text.trim(),
        observaciones: _observacionesController.text.trim(),
        ultimaActualizacion: now,
      );
      await ref.read(siniestroListProvider.notifier).updateSiniestro(siniestroFinal);
    } else {
      siniestroFinal = SiniestroModel(
        folio: folioFinal,
        aseguradora: _selectedAseguradora,
        ajustador: ajustadorFinal,
        estatus: SiniestroEstatus.asignado,
        tipoEvento: tipoEventoFinal,
        municipio: _municipioController.text.trim(),
        estado: _estadoController.text.trim(),
        referencias: _referenciasController.text.trim(),
        ubicacion: _referenciasController.text.trim(),
        linkMaps: _mapsController.text.trim(),
        asegurado: _aseguradoController.text.trim(),
        telefonoAsegurado: _telefonoController.text.trim(),
        vehiculo: _vehiculoController.text.trim(),
        colorVehiculo: _colorController.text.trim(),
        placas: _placasController.text.trim().toUpperCase(),
        poliza: _polizaController.text.trim(),
        fechaAsignacion: now,
        observaciones: _observacionesController.text.trim(),
      );
      await ref.read(siniestroListProvider.notifier).createSiniestro(siniestroFinal);
    }

    // Envío a WhatsApp si fue solicitado
    if (mode == SendMode.ajustador || mode == SendMode.grupo) {
      final msg = WhatsAppService.buildAsignacionMessage(
        folio: siniestroFinal.folio,
        aseguradora: siniestroFinal.aseguradora,
        ajustador: siniestroFinal.ajustador,
        tipoEvento: siniestroFinal.tipoEvento,
        vehiculo: siniestroFinal.vehiculo,
        colorVehiculo: siniestroFinal.colorVehiculo,
        placas: siniestroFinal.placas,
        asegurado: siniestroFinal.asegurado,
        telefonoAsegurado: siniestroFinal.telefonoAsegurado,
        ubicacion: siniestroFinal.direccionCompleta,
        linkMaps: siniestroFinal.linkMaps,
        observaciones: siniestroFinal.observaciones,
        fechaHora: siniestroFinal.fechaAsignacion,
      );

      if (mode == SendMode.ajustador) {
        await WhatsAppService.sendWhatsAppMessage(
          phone: _selectedAjustadorTelefono,
          message: msg,
        );
      } else if (mode == SendMode.grupo) {
        await WhatsAppService.shareToWhatsAppGeneric(msg);
      }
    }

    final sheetsService = ref.read(googleSheetsServiceProvider);
    final isConnected = sheetsService.isSignedIn;

    if (mounted) {
      if (isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? '✅ Siniestro ${siniestroFinal.folio} actualizado y sincronizado en Google Sheets.'
                : '✅ Siniestro ${siniestroFinal.folio} registrado y sincronizado en Google Sheets.'),
            backgroundColor: AppColors.statusConcluido,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Text(isEditing
                ? '⚠️ Siniestro ${siniestroFinal.folio} actualizado localmente. (Sin vincular: inicia sesión con Google en Ajustes para enviarlo al Excel).'
                : '⚠️ Siniestro ${siniestroFinal.folio} guardado localmente. (Sin vincular: inicia sesión con Google en Ajustes para enviarlo al Excel).'),
            backgroundColor: AppColors.statusAsignado,
            action: SnackBarAction(
              label: 'Ver cola',
              textColor: Colors.white,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SyncStatusScreen()),
                );
              },
            ),
          ),
        );
      }

      if (widget.isStandaloneScreen || isEditing) {
        Navigator.of(context).pop();
      } else {
        _resetForm();
      }
    }
  }

  void _resetForm() {
    _folioController.clear();
    _aseguradoController.clear();
    _telefonoController.clear();
    _vehiculoController.clear();
    _colorController.clear();
    _placasController.clear();
    _polizaController.clear();
    _municipioController.clear();
    _estadoController.clear();
    _referenciasController.clear();
    _mapsController.clear();
    _observacionesController.clear();
    _otroTipoEventoController.clear();
    _parsedHoraAsignacion = null;
    setState(() {
      _selectedTipoEvento = 'Choque';
      _selectedAseguradora = 'Inbursa';
      _selectedAjustadorId = null;
      _selectedAjustadorNombre = '';
      _selectedAjustadorTelefono = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ajustadores = ref.watch(activeAjustadoresProvider);
    final aseguradoras = ref.watch(aseguradorasNamesProvider);
    final isEditing = widget.siniestroToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? 'Editar Siniestro: ${widget.siniestroToEdit!.folio}'
              : 'Nueva Asignación Rápida',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: (widget.isStandaloneScreen || isEditing)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            children: [
              // 1. Parser Inteligente de Cabina y Reenvíos WhatsApp
              CabinaParserCard(onApplyParsed: _applyParsedData),

              // 2. Selector Rápido de Aseguradora
              _buildSectionTitle('1. Aseguradora'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: aseguradoras.map((cia) {
                    final isSelected = _selectedAseguradora == cia;
                    final ciaColor = AppColors.getAseguradoraColor(cia);
                    final textColor = isSelected
                        ? Colors.white
                        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(
                          cia,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        labelStyle: TextStyle(
                          color: textColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 13,
                        ),
                        selected: isSelected,
                        selectedColor: ciaColor,
                        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                        side: BorderSide(
                          color: isSelected
                              ? ciaColor
                              : (isDark ? AppColors.borderDark : Colors.grey.shade400),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedAseguradora = cia);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Folio / Siniestro con Pegado Directo (No obligatorio)
              _buildSectionTitle('2. Folio / Siniestro (Opcional - Si está vacío asigna S/F)'),
              TextFormField(
                controller: _folioController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Ej. 3059238 / INB-998877 (o déjalo vacío si cabina aún no lo da)',
                  prefixIcon: const Icon(Icons.confirmation_number_outlined),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste_go_rounded, color: AppColors.primaryLight),
                    tooltip: 'Pegar desde portapapeles',
                    onPressed: _pasteFolioFromClipboard,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 4. Ajustador Asignado (ChoiceChips con contraste garantizado)
              _buildSectionTitle('3. Ajustador Asignado (Toca para seleccionar o cambiar)'),
              ajustadores.isEmpty
                  ? const Text(
                      'No hay ajustadores activos. Agréguelos en Ajustes.',
                      style: TextStyle(color: Colors.red),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ajustadores.map((aj) {
                        final isSelected = _selectedAjustadorId == aj.id;
                        final textColor = isSelected
                            ? Colors.white
                            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
                        return ChoiceChip(
                          avatar: CircleAvatar(
                            backgroundColor: isSelected
                                ? Colors.white
                                : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                            child: Text(
                              aj.nombre.isNotEmpty ? aj.nombre[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                          ),
                          label: Text(
                            aj.nombre,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          labelStyle: TextStyle(
                            color: textColor,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 13,
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark ? AppColors.borderDark : AppColors.borderLight),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedAjustadorId = aj.id;
                                _selectedAjustadorNombre = aj.nombre;
                                _selectedAjustadorTelefono = aj.telefonoWhatsApp;
                              } else {
                                _selectedAjustadorId = null;
                                _selectedAjustadorNombre = '';
                                _selectedAjustadorTelefono = '';
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 16),

              // 5. Ubicación y Referencias
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('4. Ubicación y Referencias'),
                  TextButton.icon(
                    onPressed: () => _showArcoNorteCatalog(context),
                    icon: const Icon(Icons.alt_route_rounded, size: 16, color: AppColors.primaryLight),
                    label: const Text('Tramos Arco Norte (Km)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _municipioController,
                      decoration: const InputDecoration(
                        hintText: 'Municipio / Localidad',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _estadoController,
                      decoration: const InputDecoration(
                        hintText: 'Estado (ej: Hidalgo)',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _referenciasController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Calle, esquina, colonia o tramo carretero...',
                  prefixIcon: Icon(Icons.navigation_outlined),
                ),
              ),
              const SizedBox(height: 8),

              // Enlace de Google Maps (Opcional)
              TextFormField(
                controller: _mapsController,
                decoration: InputDecoration(
                  hintText: 'Enlace Google Maps (Opcional)',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_mapsController.text.isNotEmpty)
                        IconButton(
                          icon: _isResolvingLocation
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.auto_fix_high_rounded, color: AppColors.whatsappGreen),
                          tooltip: 'Resolver Municipio y Estado desde este enlace',
                          onPressed: () => _resolveLocationFromMaps(_mapsController.text),
                        ),
                      IconButton(
                        icon: _isGettingGps
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location_rounded, color: AppColors.primaryLight),
                        tooltip: 'Obtener GPS Actual',
                        onPressed: _isGettingGps ? null : _getCurrentLocation,
                      ),
                    ],
                  ),
                ),
                onChanged: (val) {
                  if (val.contains('maps') || val.contains('http') || RegExp(r'\d+\.\d+').hasMatch(val)) {
                    _resolveLocationFromMaps(val);
                  }
                },
              ),
              const SizedBox(height: 16),

              // 6. Tipo de Evento (ChoiceChips con contraste)
              _buildSectionTitle('5. Tipo de Evento'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AppConstants.tiposEvento.map((evento) {
                    final isSelected = _selectedTipoEvento == evento;
                    final textColor = isSelected
                        ? Colors.white
                        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text(
                          evento,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        labelStyle: TextStyle(
                          color: textColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 13,
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? AppColors.borderDark : AppColors.borderLight),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedTipoEvento = evento);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (_selectedTipoEvento == 'Diverso' || _selectedTipoEvento == 'Otro') ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _otroTipoEventoController,
                  decoration: InputDecoration(
                    hintText: _selectedTipoEvento == 'Diverso'
                        ? 'Especificar evento diverso (ej: Semoviente, Bache, Animal...)'
                        : 'Especificar otro tipo de siniestro...',
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                    isDense: true,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // 7. Datos del Vehículo
              _buildSectionTitle('6. Datos del Vehículo'),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _vehiculoController,
                      decoration: const InputDecoration(
                        hintText: 'Marca / Submarca (ej: Versa 2022)',
                        prefixIcon: Icon(Icons.directions_car_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _colorController,
                      decoration: const InputDecoration(
                        hintText: 'Color (ej: Blanco)',
                        prefixIcon: Icon(Icons.palette_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              // Placas y Póliza colapsables (opcionales)
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    'Datos adicionales de cabina (Placas / Póliza - opcional)',
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _placasController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              hintText: 'Placas (ej: NXZ-4433)',
                              prefixIcon: Icon(Icons.pin_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _polizaController,
                            decoration: const InputDecoration(
                              hintText: 'Póliza / Inciso',
                              prefixIcon: Icon(Icons.description_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 8. Asegurado / Reportante
              _buildSectionTitle('7. Asegurado / Reportante'),
              TextFormField(
                controller: _aseguradoController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Nombre del conductor o reportante',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: 'Teléfono de contacto (10 dígitos)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // 9. Observaciones Adicionales
              _buildSectionTitle('8. Observaciones Adicionales'),
              TextFormField(
                controller: _observacionesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Notas de cabina, lesionados, vialidades cerradas, terceros...',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 24),

              // Botones de Despacho y Envío
              // Botón 1: Enviar al Ajustador Directo (si hay ajustador seleccionado)
              if (_selectedAjustadorNombre.isNotEmpty) ...[
                ElevatedButton.icon(
                  onPressed: () => _saveAndSend(mode: SendMode.ajustador),
                  icon: const Icon(Icons.person_pin_circle_rounded, size: 20),
                  label: Text(
                    isEditing
                        ? 'Actualizar y Enviar a $_selectedAjustadorNombre'
                        : 'Guardar y Enviar a $_selectedAjustadorNombre (Directo)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.whatsappGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Botón 2: Enviar al Grupo de WhatsApp (Siempre disponible)
              ElevatedButton.icon(
                onPressed: () => _saveAndSend(mode: SendMode.grupo),
                icon: const Icon(Icons.groups_rounded, size: 20),
                label: Text(
                  isEditing
                      ? 'Actualizar y Enviar al Grupo WhatsApp'
                      : 'Guardar y Enviar al Grupo de WhatsApp',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF128C7E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
              const SizedBox(height: 10),

              // Botón 3: Solo Guardar en Base Local
              OutlinedButton.icon(
                onPressed: () => _saveAndSend(mode: SendMode.none),
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  isEditing ? 'Solo Guardar Cambios' : 'Solo Guardar en Base Local',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryLight,
        ),
      ),
    );
  }

  void _showArcoNorteCatalog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Autopista Arco Norte (Tramos y Km)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Text(
                    'Toca un tramo para aplicar automáticamente Municipio, Estado y CP:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: ArcoNorteService.tramos.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final t = ArcoNorteService.tramos[index];
                        return ListTile(
                          dense: true,
                          title: Text('${t.localidad} (${t.estado})', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Tramo: ${t.tramoKilometrico} • CP ${t.codigoPostal}'),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                          onTap: () {
                            setState(() {
                              _municipioController.text = t.localidad;
                              _estadoController.text = t.estado;
                              _referenciasController.text = 'Autopista Arco Norte (${t.tramoKilometrico}) CP ${t.codigoPostal}';
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
