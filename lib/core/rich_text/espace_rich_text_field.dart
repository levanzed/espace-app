import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';

import 'espace_rich_text.dart';
import 'latex_html_content.dart';

/// Shared ESPACE WYSIWYG field (Quill). Teachers never edit raw HTML.
///
/// Use for quiz stems/intros now; assignments/lessons/notes later.
class EspaceRichTextField extends StatefulWidget {
  const EspaceRichTextField({
    super.key,
    required this.controller,
    this.minHeight = 120,
    this.maxHeight = 280,
    this.hintText,
    this.autofocus = false,
    this.showToolbar = true,
  });

  final QuillController controller;
  final double minHeight;
  final double maxHeight;
  final String? hintText;
  final bool autofocus;
  final bool showToolbar;

  /// Create a controller from HTML (Moodle / draft).
  static QuillController controllerFromHtml(String? html) {
    return QuillController(
      document: EspaceRichText.documentFromHtml(html),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  /// HTML for Moodle publish/update.
  static String htmlOf(QuillController controller) {
    return EspaceRichText.htmlFromDocument(controller.document);
  }

  static bool isBlank(QuillController controller) {
    return EspaceRichText.isEmpty(controller.document);
  }

  @override
  State<EspaceRichTextField> createState() => _EspaceRichTextFieldState();
}

class _EspaceRichTextFieldState extends State<EspaceRichTextField> {
  static const Color _accent = Color(0xFF5B4B8A);

  late final FocusNode _focusNode;
  late final ScrollController _scrollController;
  String _liveHtml = '';

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _liveHtml = EspaceRichText.htmlFromDocument(widget.controller.document);
    widget.controller.addListener(_onDocumentChanged);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  void _onDocumentChanged() {
    final html = EspaceRichText.htmlFromDocument(widget.controller.document);
    if (html != _liveHtml) {
      setState(() => _liveHtml = html);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onDocumentChanged);
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _insertEquation() async {
    final input = TextEditingController();
    final latex = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insert equation'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: r'e.g. x^2 + y^2 = z^2',
            border: OutlineInputBorder(),
            helperText: r'Inserted as \( … \) for Moodle MathJax',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, input.text.trim()),
            child: const Text('Insert'),
          ),
        ],
      ),
    );
    input.dispose();
    if (latex == null || latex.isEmpty) return;

    final index = widget.controller.selection.baseOffset;
    final length = widget.controller.selection.extentOffset - index;
    final safeIndex = index < 0 ? widget.controller.document.length - 1 : index;
    final embed = r'\(' '$latex' r'\)';
    widget.controller.replaceText(
      safeIndex,
      length < 0 ? 0 : length,
      embed,
      TextSelection.collapsed(offset: safeIndex + embed.length),
    );
  }

  QuillSimpleToolbarConfig get _toolbarConfig {
    return QuillSimpleToolbarConfig(
      multiRowsDisplay: false,
      showDividers: false,
      showFontFamily: false,
      showFontSize: false,
      showBoldButton: true,
      showItalicButton: true,
      showUnderLineButton: true,
      showStrikeThrough: false,
      showInlineCode: false,
      showColorButton: false,
      showBackgroundColorButton: false,
      showClearFormat: true,
      showAlignmentButtons: true,
      showHeaderStyle: false,
      showListNumbers: true,
      showListBullets: true,
      showListCheck: false,
      showCodeBlock: false,
      showQuote: false,
      showIndent: false,
      showLink: true,
      showUndo: true,
      showRedo: true,
      showSearchButton: false,
      showSubscript: false,
      showSuperscript: false,
      showSmallButton: false,
      showDirection: false,
      showLineHeightButton: false,
      embedButtons: FlutterQuillEmbeds.toolbarButtons(
        videoButtonOptions: null,
        cameraButtonOptions: null,
      ),
      customButtons: [
        QuillToolbarCustomButtonOptions(
          icon: const Icon(Icons.functions),
          tooltip: 'Equation',
          onPressed: _insertEquation,
        ),
      ],
      buttonOptions: QuillSimpleToolbarButtonOptions(
        base: QuillToolbarBaseButtonOptions(
          iconTheme: QuillIconTheme(
            iconButtonSelectedData: IconButtonData(
              color: _accent,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showToolbar) ...[
              QuillSimpleToolbar(
                controller: widget.controller,
                config: _toolbarConfig,
              ),
              Divider(height: 1, color: Colors.grey.shade200),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: widget.minHeight,
                maxHeight: widget.maxHeight,
              ),
                child: QuillEditor.basic(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  scrollController: _scrollController,
                  config: QuillEditorConfig(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    placeholder: widget.hintText,
                    embedBuilders: FlutterQuillEmbeds.defaultEditorBuilders(),
                    scrollable: true,
                    // Autofocus is handled once in initState via _focusNode.requestFocus().
                    // Setting autoFocus: false prevents the Quill editor from re-requesting
                    // focus on every parent rebuild, which was causing the cursor to jump
                    // from option/answer fields back to the question stem.
                    autoFocus: false,
                    expands: false,
                  ),
                ),
            ),
            if (_liveHtml.contains(r'\(') || _liveHtml.contains(r'\[')) ...[
              Divider(height: 1, color: Colors.grey.shade200),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EQUATION PREVIEW',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Reuses the exact same renderer as preview/attempt/review.
                    LatexHtmlContent(html: _liveHtml),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
