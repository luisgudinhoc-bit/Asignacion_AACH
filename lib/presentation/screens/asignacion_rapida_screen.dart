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
import '../providers/siniestro_provider.dart';
import '../widgets/cabina_parser_card.dart';

/// Formulario de Asignación Rápida con optimización para captura ágil con una mano
class AsignacionRapidaScreen extends ConsumerStatefulWidget {
  final bool isStandaloneScreen;

  const AsignacionRapidaScreen({
    super.key,
    this.isStandaloneScreen = false,
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

  // Estados de selección rápida (Chips)
  String _selectedAseguradora = 'Inbursa';
  String _selectedTipoEvento = 'Choque';
  String? _selectedAjustadorId;
  String _selectedAjustadorNombre = '';
  String _selectedAjustadorTelefono = '';

  bool _isGettingGps = false;
  bool _isResolvingLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ajustadores = ref.read(activeAjustadoresProvider);
      if (ajustadores.isNotEmpty && _selectedAjustadorNombre.isEmpty) {
        setState(() {
          _selectedAjustadorId = ajustadores.first.id;
          _selectedAjustadorNombre = ajustadores.first.nombre;
          _selectedAjustadorTelefono = ajustadores.first.telefonoWhatsApp;
        });
      }
    });
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
        // Resolver automáticamente municipio, estado y calle desde el link de Maps
        _resolveLocationFromMaps(parsed.linkMaps!);
      }
      if (parsed.tipoEvento != null && parsed.tipoEvento!.isNotEmpty) {
        _selectedTipoEvento = parsed.tipoEvento!;
      }
      if (parsed.observaciones != null && parsed.observaciones!.isNotEmpty) {
        _observacionesController.text = parsed.observaciones!;
      }

      // Ajustador detectado por mención en WhatsApp
      if (parsed.ajustador != null && parsed.ajustador!.isNotEmpty) {
        final ajustadores = ref.read(activeAjustadoresProvider);
        final match = ajustadores.firstWhere(
          (a) => a.nombre.toLowerCase().contains(parsed.ajustador!.toLowerCase()) ||
              parsed.ajustador!.toLowerCase().contains(a.nombre.toLowerCase()),
          orElse: () => ajustadores.first,
        );
        _selectedAjustadorId = match.id;
        _selectedAjustadorNombre = match.nombre;
        _selectedAjustadorTelefono = match.telefonoWhatsApp;
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

  Future<void> _fetchCurrentGps() async {
    setState(() => _isGettingGps = true);
    try {
      final loc = await LocationService.getCurrentLocation();
      if (loc != null) {
        setState(() {
          if (_referenciasController.text.isEmpty) {
            _referenciasController.text = loc.displayText;
          }
          _mapsController.text = loc.mapsUrl;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📍 Coordenadas GPS fijadas exitosamente.'),
              backgroundColor: AppColors.statusConcluido,
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

  Future<void> _saveAndSend({required bool sendWhatsApp}) async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor complete los campos obligatorios.'),
          backgroundColor: AppColors.statusCancelado,
        ),
      );
      return;
    }

    if (_selectedAjustadorNombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe seleccionar un ajustador activo.'),
          backgroundColor: AppColors.statusCancelado,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final nuevoSiniestro = SiniestroModel(
      folio: _folioController.text.trim().toUpperCase(),
      aseguradora: _selectedAseguradora,
      ajustador: _selectedAjustadorNombre,
      estatus: SiniestroEstatus.asignado,
      tipoEvento: _selectedTipoEvento,
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

    // Guardar localmente y encolar a Sheets
    await ref.read(siniestroListProvider.notifier).createSiniestro(nuevoSiniestro);

    if (sendWhatsApp) {
      final msg = WhatsAppService.buildAsignacionMessage(
        folio: nuevoSiniestro.folio,
        aseguradora: nuevoSiniestro.aseguradora,
        ajustador: nuevoSiniestro.ajustador,
        tipoEvento: nuevoSiniestro.tipoEvento,
        vehiculo: nuevoSiniestro.vehiculo,
        placas: nuevoSiniestro.placas,
        asegurado: nuevoSiniestro.asegurado,
        telefonoAsegurado: nuevoSiniestro.telefonoAsegurado,
        ubicacion: nuevoSiniestro.direccionCompleta,
        linkMaps: nuevoSiniestro.linkMaps,
        observaciones: nuevoSiniestro.observaciones,
        fechaHora: now,
      );

      await WhatsAppService.sendWhatsAppMessage(
        phone: _selectedAjustadorTelefono,
        message: msg,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Siniestro ${nuevoSiniestro.folio} registrado correctamente.'),
          backgroundColor: AppColors.statusConcluido,
        ),
      );

      if (widget.isStandaloneScreen) {
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
    setState(() {
      _selectedTipoEvento = 'Choque';
      _selectedAseguradora = 'Inbursa';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ajustadores = ref.watch(activeAjustadoresProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nueva Asignación Rápida',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: widget.isStandaloneScreen
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

              // 2. Selector Rápido de Aseguradora (Inbursa, Mapfre, Crabi, SPT, Otra Compañía)
              _buildSectionTitle('1. Aseguradora'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AppConstants.defaultAseguradoras.map((cia) {
                    final isSelected = _selectedAseguradora == cia;
                    final ciaColor = AppColors.getAseguradoraColor(cia);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(cia),
                        selected: isSelected,
                        selectedColor: ciaColor.withValues(alpha: 0.2),
                        side: BorderSide(
                          color: isSelected ? ciaColor : Colors.grey.shade400,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        labelStyle: TextStyle(
                          color: isSelected ? ciaColor : theme.textTheme.bodyMedium?.color,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
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

              // 3. Folio / Siniestro con Pegado Directo
              _buildSectionTitle('2. Folio / Siniestro'),
              TextFormField(
                controller: _folioController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Ej. 3059238 / INB-998877',
                  prefixIcon: const Icon(Icons.confirmation_number_outlined),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste_go_rounded, color: AppColors.primaryLight),
                    tooltip: 'Pegar desde portapapeles',
                    onPressed: _pasteFolioFromClipboard,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'El número de folio o siniestro es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 4. Ajustador Asignado (ChoiceChips)
              _buildSectionTitle('3. Ajustador Asignado'),
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
                        return ChoiceChip(
                          avatar: CircleAvatar(
                            backgroundColor: isSelected
                                ? AppColors.primary
                                : Colors.grey.shade400,
                            child: Text(
                              aj.nombre[0].toUpperCase(),
                              style: const TextStyle(fontSize: 11, color: Colors.white),
                            ),
                          ),
                          label: Text(aj.nombre),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _selectedAjustadorId = aj.id;
                                _selectedAjustadorNombre = aj.nombre;
                                _selectedAjustadorTelefono = aj.telefonoWhatsApp;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 16),

              // 4. Ubicación y Referencias (Municipio, Estado, Referencias, Maps opcional)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('4. Ubicación y Referencias'),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppColors.primaryLight,
                    ),
                    icon: const Icon(Icons.alt_route_rounded, size: 16),
                    label: const Text('Tramos Arco Norte (Km)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _showArcoNorteModal(context),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _municipioController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Municipio (ej: Pachuca)',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _estadoController,
                      textCapitalization: TextCapitalization.words,
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
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Referencias: calle, carretera, autopista, cerradas, km...',
                  prefixIcon: const Icon(Icons.directions_outlined),
                  suffixIcon: IconButton(
                    icon: _isGettingGps
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded, color: AppColors.primaryLight),
                    tooltip: 'Insertar GPS actual',
                    onPressed: _isGettingGps ? null : _fetchCurrentGps,
                  ),
                ),
              ),
              // Banner reactivo de Arco Norte si se detecta un kilometraje
              Builder(
                builder: (context) {
                  final textToCheck = '${_referenciasController.text} ${_municipioController.text}';
                  final match = ArcoNorteService.findKmInText(textToCheck);
                  if (match == null) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.alt_route_rounded, color: AppColors.primaryLight, size: 26),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🛣️ Arco Norte: Tramo ${match.localidad}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryLight),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Km ${match.kilometro.toStringAsFixed(0)} • CP ${match.codigoPostal} • ${match.estado}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryLight,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            setState(() {
                              _municipioController.text = match.localidad;
                              _estadoController.text = match.estado;
                              _mapsController.text = match.linkGoogleMaps;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('🛣️ Ubicación ajustada a Tramo ${match.localidad} (${match.estado})'),
                                backgroundColor: AppColors.statusConcluido,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check, size: 14),
                          label: const Text('Aplicar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mapsController,
                onChanged: (text) {
                  if (text.contains('maps') && text.contains('http')) {
                    _resolveLocationFromMaps(text);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Enlace Google Maps (Opcional - https://maps.app.goo.gl/...)',
                  prefixIcon: const Icon(Icons.pin_drop_outlined),
                  suffixIcon: IconButton(
                    icon: _isResolvingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_fix_high_rounded, color: AppColors.primaryLight),
                    tooltip: 'Resolver Municipio y Estado desde Maps',
                    onPressed: () {
                      final url = _mapsController.text.trim();
                      if (url.isNotEmpty) {
                        _resolveLocationFromMaps(url);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 6. Tipo de Evento (ChoiceChips)
              _buildSectionTitle('5. Tipo de Evento'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AppConstants.tiposEvento.map((evento) {
                    final isSelected = _selectedTipoEvento == evento;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text(evento),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) setState(() => _selectedTipoEvento = evento);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
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
                        hintText: 'Color',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                        prefixIcon: Icon(Icons.article_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 8. Datos del Asegurado / Reportante
              _buildSectionTitle('7. Asegurado / Reportante'),
              TextFormField(
                controller: _aseguradoController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Nombre completo (ej: Daniel Rojas)',
                  prefixIcon: Icon(Icons.person_outline_rounded),
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
                  hintText: 'Notas de cabina, lesionados, vialidades cerradas...',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 24),

              // Botón Principal: Guardar y Enviar por WhatsApp
              ElevatedButton.icon(
                onPressed: () => _saveAndSend(sendWhatsApp: true),
                icon: const Icon(Icons.send_rounded, size: 20),
                label: Text(
                  _selectedAjustadorNombre.isNotEmpty
                      ? 'Guardar y Enviar a $_selectedAjustadorNombre por WhatsApp'
                      : 'Guardar y Enviar por WhatsApp',
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

              // Botón Secundario: Solo Guardar en Local
              OutlinedButton.icon(
                onPressed: () => _saveAndSend(sendWhatsApp: false),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Solo Guardar en Base Local'),
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
      padding: const EdgeInsets.only(bottom: 6.0, top: 4.0),
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

  /// Muestra la tabla de tramos carreteros y kilometrajes de Arco Norte
  void _showArcoNorteModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final filteredTramos = ArcoNorteService.tramos.where((t) {
              if (filter.isEmpty) return true;
              final q = filter.toLowerCase();
              return t.localidad.toLowerCase().contains(q) ||
                  t.codigoPostal.contains(q) ||
                  t.tramoKilometrico.toLowerCase().contains(q) ||
                  t.estado.toLowerCase().contains(q);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              maxChildSize: 0.92,
              minChildSize: 0.45,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.alt_route_rounded, color: AppColors.primaryLight),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Tramos Carreteros Arco Norte',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(modalCtx),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Buscar por km, localidad o C.P. (ej. 182, Sahagún)',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            filter = val;
                          });
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: filteredTramos.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final tramo = filteredTramos[i];
                          return ListTile(
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    tramo.localidad,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'CP ${tramo.codigoPostal}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              '${tramo.tramoKilometrico} • ${tramo.estado}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                            onTap: () {
                              setState(() {
                                _municipioController.text = tramo.localidad;
                                _estadoController.text = tramo.estado;
                                _referenciasController.text = 'Autopista Arco Norte ${tramo.tramoKilometrico}';
                                _mapsController.text =
                                    'https://www.google.com/maps?q=${tramo.latitud},${tramo.longitud}(Arco+Norte+${tramo.localidad})';
                              });
                              Navigator.pop(modalCtx);
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('🛣️ Tramo seleccionado: ${tramo.localidad} (${tramo.tramoKilometrico})'),
                                  backgroundColor: AppColors.statusConcluido,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
