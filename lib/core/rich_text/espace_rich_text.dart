import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

/// HTML ↔ Quill helpers for ESPACE authoring.
///
/// Teachers edit Delta in the UI. Moodle receives HTML only at publish/update.
abstract final class EspaceRichText {
  /// Build a Quill [Document] from Moodle/Studio HTML or plain text.
  static Document documentFromHtml(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) {
      return Document();
    }

    final html = text.contains('<') ? text : '<p>${_escapeHtml(text)}</p>';
    try {
      final delta = HtmlToDelta().convert(html);
      if (delta.isEmpty) {
        return Document();
      }
      return Document.fromDelta(delta);
    } catch (_) {
      // Fallback: treat as plain text so the editor never fails to open.
      return Document.fromDelta(
        Delta()
          ..insert(text)
          ..insert('\n'),
      );
    }
  }

  /// Convert Quill document to Moodle-friendly HTML.
  static String htmlFromDocument(Document document) {
    final maps = document.toDelta().toJson();
    if (maps.isEmpty) {
      return '';
    }

    final converter = QuillDeltaToHtmlConverter(
      maps,
      ConverterOptions(
        converterOptions: OpConverterOptions(inlineStylesFlag: true),
      ),
    );
    var html = converter.convert().trim();
    html = _normalizeMoodleHtml(html);
    return html;
  }

  /// True when the document has no visible teacher content.
  static bool isEmpty(Document document) {
    final plain = document.toPlainText().replaceAll('\n', '').trim();
    return plain.isEmpty;
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  static String _normalizeMoodleHtml(String html) {
    if (html.isEmpty || html == '<p><br/></p>' || html == '<p><br></p>') {
      return '';
    }
    // Collapse Quill empty paragraphs that confuse Moodle filters.
    return html
        .replaceAll('<p><br/></p>', '')
        .replaceAll('<p><br></p>', '')
        .trim();
  }
}
