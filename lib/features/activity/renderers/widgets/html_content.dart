import 'package:flutter/material.dart';

import '../../../../core/rich_text/latex_html_content.dart';

/// Shared HTML renderer for all ESPACE surfaces.
///
/// Renders LaTeX math (`\( ... \)` inline, `\[ ... \]` display) via
/// [LatexHtmlContent] so equations render identically in teacher preview,
/// student attempt, quiz review, and the activity renderer.
class HtmlContent extends StatelessWidget {
  final String html;

  const HtmlContent({
    super.key,
    required this.html,
  });

  @override
  Widget build(BuildContext context) {
    if (html.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return LatexHtmlContent(
      html: html,
      textStyle: Theme.of(context).textTheme.bodyLarge,
    );
  }
}