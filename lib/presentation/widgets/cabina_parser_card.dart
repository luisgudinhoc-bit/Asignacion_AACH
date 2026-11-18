import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/services/whatsapp_parser_service.dart';

/// Panel colapsable para pegar y analizar mensajes brutos de cabina de aseguradoras
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
  bool _isExpanded = false;

  void _processText(String text) {
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
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      _rawTextController.text = data.text!;
      _processText(data.text!);
    }
  }

  void _applyToForm() {
    if (_parsedResult != null) {
      widget.onApplyParsed(_parsedResult!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Datos de cabina extraídos y volcados al formulario.'),
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.statusConcluido,
        ),
      );
      setState(() {
        _isExpanded = false; // Colapsar tras aplicar para despejar pantalla
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
              child: const Icon(Icons.smart_toy_rounded, color: AppColors.whatsappGreen),
            ),
            title: const Text(
              'Pegar mensaje de Cabina',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Text(
              _parsedResult != null && _parsedResult!.hasContent
                  ? 'Datos detectados: Folio ${_parsedResult?.folio ?? "S/F"} • ${_parsedResult?.aseguradora ?? "Cia"}'
                  : 'Extraer automáticamente folio, aseguradora, auto y GPS',
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pega el texto tal cual llegó en WhatsApp:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      TextButton.icon(
                        onPressed: _pasteFromClipboard,
                        icon: const Icon(Icons.content_paste_rounded, size: 16),
                        label: const Text('Pegar', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.whatsappGreen,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _rawTextController,
                    maxLines: 4,
                    onChanged: _processText,
                    decoration: InputDecoration(
                      hintText:
                          'Ejemplo:\n*CABINA QUALITAS*\nREPORTE: 0424123456\nASEGURADO: ROBERTO HERNANDEZ\nTEL: 5541998877\nAUTO: NISSAN VERSA...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: theme.hintColor.withValues(alpha: 0.7),
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
                        if (_parsedResult!.asegurado != null)
                          _buildPreviewBadge(Icons.person, _parsedResult!.asegurado!),
                        if (_parsedResult!.telefonoAsegurado != null)
                          _buildPreviewBadge(Icons.phone, _parsedResult!.telefonoAsegurado!),
                        if (_parsedResult!.vehiculo != null)
                          _buildPreviewBadge(Icons.directions_car, _parsedResult!.vehiculo!),
                        if (_parsedResult!.placas != null)
                          _buildPreviewBadge(Icons.pin, 'Placas: ${_parsedResult!.placas}'),
                        if (_parsedResult!.linkMaps != null)
                          _buildPreviewBadge(Icons.location_on, 'Maps detectado'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _applyToForm,
                      icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
                      label: const Text('Autocompletar Formulario'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.whatsappGreen,
                        foregroundColor: Colors.white,
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
