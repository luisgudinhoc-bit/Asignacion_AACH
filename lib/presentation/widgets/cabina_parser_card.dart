import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/ocr/ocr_service.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/services/whatsapp_parser_service.dart';

/// Panel para capturar y analizar mensajes de cabina por Imagen (OCR local) o Texto
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
  bool _isProcessingImage = false;

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
    if (data != null && data.text != null) {
      _rawTextController.text = data.text!;
      _processText(data.text!, autoApply: true);
    }
  }

  Future<void> _processImageOcr({required bool fromCamera}) async {
    setState(() => _isProcessingImage = true);
    try {
      final text = fromCamera
          ? await OcrService.extractTextFromCamera()
          : await OcrService.extractTextFromGallery();

      if (text != null && text.trim().isNotEmpty) {
        _rawTextController.text = text;
        _processText(text, autoApply: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚡ Captura procesada con OCR Local (0 tokens). Datos volcados al formulario.'),
              backgroundColor: AppColors.statusConcluido,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📱 El OCR por cámara/captura corre nativamente en el celular Android (0 tokens). En esta versión Web de PC, pega el texto del mensaje en el recuadro para probar en tiempo real.'),
            backgroundColor: AppColors.statusAsignado,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al leer imagen: $e'),
            backgroundColor: AppColors.statusCancelado,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingImage = false);
      }
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
              child: _isProcessingImage
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.whatsappGreen),
                    )
                  : const Icon(Icons.document_scanner_rounded, color: AppColors.whatsappGreen),
            ),
            title: const Text(
              'Carga Rápida (Captura o Mensaje)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Text(
              _parsedResult != null && _parsedResult!.hasContent
                  ? 'Detectado: Folio ${_parsedResult?.folio ?? "S/F"} • ${_parsedResult?.aseguradora ?? "Cia"}'
                  : 'Sube la captura de WhatsApp o pega el texto (Cero tokens de IA)',
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
                  // Botones rápidos de captura por Imagen
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt_rounded, size: 16, color: AppColors.accent),
                            SizedBox(width: 6),
                            Text(
                              'Escanear con OCR Local (0 Tokens / Sin Internet)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isProcessingImage ? null : () => _processImageOcr(fromCamera: false),
                                icon: const Icon(Icons.photo_library_rounded, size: 16),
                                label: const Text('Subir Captura'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryLight,
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isProcessingImage ? null : () => _processImageOcr(fromCamera: true),
                                icon: const Icon(Icons.camera_alt_rounded, size: 16),
                                label: const Text('Tomar Foto'),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'O pega el texto directo de WhatsApp:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      TextButton.icon(
                        onPressed: _pasteFromClipboard,
                        icon: const Icon(Icons.content_paste_rounded, size: 16),
                        label: const Text('Pegar y Extraer', style: TextStyle(fontSize: 12)),
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
                    maxLines: 3,
                    onChanged: (text) => _processText(text, autoApply: false),
                    decoration: InputDecoration(
                      hintText: 'Pega aquí el chat o el texto extraído...',
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
                        if (_parsedResult!.ajustador != null)
                          _buildPreviewBadge(Icons.assignment_ind, 'Ajustador: ${_parsedResult!.ajustador!}'),
                        if (_parsedResult!.asegurado != null)
                          _buildPreviewBadge(Icons.person, _parsedResult!.asegurado!),
                        if (_parsedResult!.telefonoAsegurado != null)
                          _buildPreviewBadge(Icons.phone, _parsedResult!.telefonoAsegurado!),
                        if (_parsedResult!.municipio != null)
                          _buildPreviewBadge(Icons.location_city, 'Mpio: ${_parsedResult!.municipio!}'),
                        if (_parsedResult!.estado != null)
                          _buildPreviewBadge(Icons.map, 'Edo: ${_parsedResult!.estado!}'),
                        if (_parsedResult!.linkMaps != null)
                          _buildPreviewBadge(Icons.location_on, 'Maps detectado'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _applyToForm,
                      icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
                      label: const Text('Volcar y Validar Formulario'),
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
