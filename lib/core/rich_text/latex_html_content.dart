import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

/// Renders HTML with LaTeX math support.
///
/// Splits the HTML on `\( ... \)` (inline) and `\[ ... \]` (display) delimiters
/// and renders math segments with [Math.tex]. All other segments render as
/// normal HTML via [HtmlWidget].
///
/// Used by teacher preview, student attempt, quiz review, and the activity
/// renderer so equations render identically everywhere.
class LatexHtmlContent extends StatelessWidget {
  const LatexHtmlContent({
    super.key,
    required this.html,
    this.textStyle,
  });

  final String html;
  final TextStyle? textStyle;

  static final RegExp _inlineMath = RegExp(r'\\\((.+?)\\\)', dotAll: true);
  static final RegExp _displayMath = RegExp(r'\\\[(.+?)\\\]', dotAll: true);

  @override
  Widget build(BuildContext context) {
    final source = html.trim();
    if (source.isEmpty) return const SizedBox.shrink();

    final segments = _splitMath(source);
    if (segments.length == 1 && !segments.first.isMath) {
      return HtmlWidget(
        source,
        textStyle: textStyle ?? Theme.of(context).textTheme.bodyLarge,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final segment in segments)
          if (segment.isMath)
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: segment.display ? 8 : 2,
                horizontal: segment.display ? 0 : 2,
              ),
              child: Align(
                alignment: segment.display
                    ? Alignment.centerLeft
                    : Alignment.centerLeft,
                child: Math.tex(
                  segment.latex,
                  mathStyle: segment.display ? MathStyle.display : MathStyle.text,
                  textStyle: textStyle ?? Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            )
          else if (segment.html.trim().isNotEmpty)
            HtmlWidget(
              segment.html,
              textStyle: textStyle ?? Theme.of(context).textTheme.bodyLarge,
            ),
      ],
    );
  }

  /// Split HTML into alternating HTML / math segments.
  static List<_MathSegment> _splitMath(String html) {
    final segments = <_MathSegment>[];
    var cursor = 0;

    // Display math first (longest match) so \[...\] isn't consumed by \(...\).
    final displayMatches = _displayMath.allMatches(html).toList();
    final inlineMatches = _inlineMath.allMatches(html).toList();

    final events = <_MathEvent>[
      for (final m in displayMatches)
        _MathEvent(m.start, m.end, m.group(1) ?? '', display: true),
      for (final m in inlineMatches)
        _MathEvent(m.start, m.end, m.group(1) ?? '', display: false),
    ]..sort((a, b) => a.start.compareTo(b.start));

    // Drop overlapping events (display wins over inline at same position).
    final filtered = <_MathEvent>[];
    for (final e in events) {
      if (filtered.isNotEmpty && e.start < filtered.last.end) continue;
      filtered.add(e);
    }

    for (final e in filtered) {
      if (e.start > cursor) {
        segments.add(_MathSegment.html(html.substring(cursor, e.start)));
      }
      segments.add(_MathSegment.latex(e.latex, display: e.display));
      cursor = e.end;
    }
    if (cursor < html.length) {
      segments.add(_MathSegment.html(html.substring(cursor)));
    }
    if (segments.isEmpty) {
      segments.add(_MathSegment.html(html));
    }
    return segments;
  }
}

class _MathEvent {
  const _MathEvent(this.start, this.end, this.latex, {required this.display});

  final int start;
  final int end;
  final String latex;
  final bool display;
}

class _MathSegment {
  const _MathSegment.html(this.html) : latex = '', isMath = false, display = false;

  const _MathSegment.latex(this.latex, {required this.display})
      : html = '',
        isMath = true;

  final String html;
  final String latex;
  final bool isMath;
  final bool display;
}