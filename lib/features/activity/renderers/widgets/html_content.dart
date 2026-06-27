import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

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

    return HtmlWidget(
      html,
      textStyle: Theme.of(context).textTheme.bodyLarge,
    );
  }
}
