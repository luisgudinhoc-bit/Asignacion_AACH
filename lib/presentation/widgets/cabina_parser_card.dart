import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/services/whatsapp_parser_service.dart';

/// Panel limpio para capturar y analizar mensajes de cabina o texto libre de WhatsApp
class CabinaParserCard extends StatefulWidget {
  final Function(ParsedCabinaMessage parsed) onApplyParsed;

  const CabinaParserCard({
    super.key,
    required this.onApplyParsed,
  });

  @override
  State<CabinaParserCard> createState() => _CabinaParserCardState();
}

class _CabinaParserCardState extends State<CabinaParserCard> {
  final TextEditingController _rawTextController = TextEditingController();
  ParsedCabinaMessage? _parsedResult;
  bool _isExpanded = true;

  void _processText(String text, {bool autoApply = false}) {
    if (text.trim().isEmpty) {
      setState(() {
        _parsedResult = null;
      });
      return;
    }
    final result = WhatsAppParserService.parse(text);
    setState(() {
      _parsedResult = result;
    });

    if (autoApply && result.hasContent) {
      _applyToForm();
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      _rawTextController.text = data.text!;
      _processText(data.text!, autoApply: true);
    }
  }

  void _applyToForm() {
    if (_parsedResult != null) {
      widget.onApplyParsed(_parsedResult!);
      setState(() {
        _isExpanded = false; // Colapsar tras aplicar para dejar ver los campos a validar
      });
    }
  }

  @override
  void dispose() {
    _rawTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _parsedResult != null && _parsedResult!.hasContent
              ? AppColors.whatsappGreen
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
          width: _parsedResult != null && _parsedResult!.hasContent ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            leading: CircleAvatar(
              backgroundColor: AppColors.whatsappGreen.withValues(alpha: 0.15),
              child: const Icon(Icons.paste_rounded, color: AppColors.whatsappGreen),
            ),
            title: const Text(
              'Pega el texto del chat o mensaje libre',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Text(
              _parsedResult != null && _parsedResult!.hasContent
                  ? 'Detectado: Folio ${_parsedResult?.folio ?? "S/F"} • ${_parsedResult?.aseguradora ?? "Cia"} • ${_parsedResult?.vehiculo ?? ""}'
                  : 'Inbursa, Crabi, coordenadas GPS, link de Maps o chat libre',
              style: TextStyle(
                fontSize: 12,
                color: _parsedResult != null && _parsedResult!.hasContent
                    ? AppColors.whatsappGreen
                    : theme.hintColor,
                fontWeight: _parsedResult != null && _parsedResult!.hasContent
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            trailing: Icon(
              _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: AppColors.primaryLight,
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pasteFromClipboard,
                          icon: const Icon(Icons.content_paste_rounded, size: 16),
                          label: const Text(
                            'Pegar Portapapeles',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.whatsappGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _processText(_rawTextController.text, autoApply: false),
                          icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                          label: const Text(
                            'Interpretar Texto',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                            side: BorderSide(
                              color: isDark ? AppColors.primaryLight : AppColors.primary,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _rawTextController,
                    minLines: 3,
                    maxLines: 6,
                    onChanged: (text) => _processText(text, autoApply: false),
                    decoration: InputDecoration(
                      hintText: 'Ejemplo:\nKm 164 +200 dir Atlacomulco\nVersa bco\nEsteban Pérez\nSemoviente\n3059330\n22:30 22:32\nO pega coordenadas (20.650354,-98.649149) o link de Maps...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: theme.hintColor.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.surfaceDark.withValues(alpha: 0.5)
                          : const Color(0xFFF1F5F9),
                    ),
                  ),
                  if (_parsedResult != null && _parsedResult!.hasContent) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (_parsedResult!.folio != null)
                          _buildPreviewBadge(Icons.confirmation_number, 'Folio: ${_parsedResult!.folio}'),
                        if (_parsedResult!.aseguradora != null)
                          _buildPreviewBadge(Icons.apartment, _parsedResult!.aseguradora!),
                        if (_parsedResult!.ajustador != null)
                          _buildPreviewBadge(Icons.assignment_ind, 'Ajustador: ${_parsedResult!.ajustador!}'),
                        if (_parsedResult!.asegurado != null)
                          _buildPreviewBadge(Icons.person, _parsedResult!.asegurado!),
                        if (_parsedResult!.telefonoAsegurado != null)
                          _buildPreviewBadge(Icons.phone_android_rounded, 'Tel: ${_parsedResult!.telefonoAsegurado!}'),
                        if (_parsedResult!.vehiculo != null)
                          _buildPreviewBadge(Icons.directions_car, _parsedResult!.vehiculo!),
                        if (_parsedResult!.colorVehiculo != null)
                          _buildPreviewBadge(Icons.palette_outlined, _parsedResult!.colorVehiculo!),
                        if (_parsedResult!.tipoEvento != null)
                          _buildPreviewBadge(Icons.warning_amber_rounded, '${_parsedResult!.tipoEvento!}${_parsedResult!.detalleEvento != null && _parsedResult!.detalleEvento!.isNotEmpty && _parsedResult!.detalleEvento != _parsedResult!.tipoEvento ? " (${_parsedResult!.detalleEvento})" : ""}'),
                        if (_parsedResult!.horaReporte != null && _parsedResult!.horaAsignacion != null)
                          _buildPreviewBadge(Icons.access_time_rounded, 'Cabina: ${_parsedResult!.horaReporte!} ➔ Asig: ${_parsedResult!.horaAsignacion!}'),
                        if (_parsedResult!.horaReporte != null && _parsedResult!.horaAsignacion == null)
                          _buildPreviewBadge(Icons.access_time_rounded, 'Reporte: ${_parsedResult!.horaReporte!}'),
                        if (_parsedResult!.horaReporte == null && _parsedResult!.horaAsignacion != null)
                          _buildPreviewBadge(Icons.access_time_rounded, 'Asig: ${_parsedResult!.horaAsignacion!}'),
                        if (_parsedResult!.municipio != null)
                          _buildPreviewBadge(Icons.location_city, 'Mpio: ${_parsedResult!.municipio!}'),
                        if (_parsedResult!.estado != null)
                          _buildPreviewBadge(Icons.map, 'Edo: ${_parsedResult!.estado!}'),
                        if (_parsedResult!.linkMaps != null)
                          _buildPreviewBadge(Icons.location_on, 'Maps detectado'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _applyToForm,
                      icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
                      label: const Text('Volcar y Validar Formulario', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.whatsappGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primaryLight),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
