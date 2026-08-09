import 'package:flutter/material.dart';

import 'html_content.dart';

/// Parsed Moodle `mod_quiz_get_attempt_data` question HTML for native controls.
///
/// Moodle returns full web HTML (radios, text inputs, scripts). Flutter's
/// HtmlWidget does not render form controls, so we extract the stem + field
/// names/values and render RadioListTile / TextField instead.
class ParsedQuizQuestion {
  ParsedQuizQuestion({
    required this.slot,
    required this.type,
    required this.stemHtml,
    required this.sequenceCheckName,
    required this.sequenceCheckValue,
    required this.answerFieldName,
    required this.choices,
    this.number,
    this.status,
    this.maxMark,
    this.initialAnswer,
  });

  final int slot;
  final String type;
  final String stemHtml;
  final String? sequenceCheckName;
  final String? sequenceCheckValue;
  final String? answerFieldName;
  final List<QuizChoiceOption> choices;
  final String? number;
  final String? status;
  final String? maxMark;

  /// Previously saved answer for this question (from Moodle HTML on resume).
  final String? initialAnswer;

  bool get isMultichoice => type == 'multichoice' && choices.isNotEmpty;
  bool get isShortAnswer =>
      type == 'shortanswer' && (answerFieldName?.isNotEmpty ?? false);
  bool get hasInteractiveAnswer => isMultichoice || isShortAnswer;

  factory ParsedQuizQuestion.fromMoodle(Map<String, dynamic> raw) {
    final html = raw['html']?.toString() ?? '';
    final type = raw['type']?.toString() ?? '';
    final slot = _asInt(raw['slot']) ?? 0;
    final cleaned = _stripScripts(html);

    return ParsedQuizQuestion(
      slot: slot,
      type: type,
      stemHtml: _extractStemHtml(cleaned),
      sequenceCheckName: _matchAttr(
        cleaned,
        r'name="(q\d+:\d+_:sequencecheck)"',
      ),
      sequenceCheckValue: _matchAttr(
        cleaned,
        r'name="q\d+:\d+_:sequencecheck"\s+value="([^"]*)"',
      ),
      answerFieldName: _extractAnswerFieldName(cleaned, type),
      choices: type == 'multichoice' ? _extractChoices(cleaned) : const [],
      number: raw['number']?.toString() ?? raw['questionnumber']?.toString(),
      status: raw['status']?.toString() ?? raw['state']?.toString(),
      maxMark: raw['maxmark']?.toString(),
      initialAnswer: _extractInitialAnswer(cleaned, type),
    );
  }

  /// Moodle `mod_quiz_process_attempt` / save payload rows for this question.
  List<Map<String, String>> toProcessRows(String? answerValue) {
    final rows = <Map<String, String>>[];
    final seqName = sequenceCheckName;
    final seqValue = sequenceCheckValue;
    if (seqName != null && seqValue != null) {
      rows.add({'name': seqName, 'value': seqValue});
    }
    final field = answerFieldName;
    if (field != null && answerValue != null && answerValue.isNotEmpty) {
      rows.add({'name': field, 'value': answerValue});
    }
    return rows;
  }
}

class QuizChoiceOption {
  const QuizChoiceOption({required this.value, required this.labelHtml});

  final String value;

  /// Raw HTML label so LaTeX (`\( … \)`) renders via [HtmlContent].
  final String labelHtml;
}

/// Native MCQ / short-answer controls for one Moodle quiz question.
///
/// [controller] is owned by the parent ([QuizRenderer]) so the short-answer
/// cursor/state survives page navigation (fixes cursor jumping back to the
/// question stem). [initialValue] seeds MCQ selection on resume/page-back.
class QuizAttemptQuestionCard extends StatelessWidget {
  const QuizAttemptQuestionCard({
    super.key,
    required this.question,
    required this.onAnswerChanged,
    this.initialValue,
    this.controller,
    this.showAnswerStatus = false,
  });

  final ParsedQuizQuestion question;
  final ValueChanged<String?> onAnswerChanged;

  /// Cached answer (from the controller's `_answers` map) to restore UI state
  /// when navigating back to a page.
  final String? initialValue;

  /// External controller for short-answer — preserves cursor position across
  /// rebuilds and page changes.
  final TextEditingController? controller;

  /// When true, renders an answered / unanswered badge (review mode).
  final bool showAnswerStatus;

  bool get _answered =>
      (initialValue != null && initialValue!.isNotEmpty) ||
      ((controller?.text.trim().isEmpty ?? true) == false);

  @override
  Widget build(BuildContext context) {
    final q = question;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Question ${q.number ?? q.slot}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (showAnswerStatus) ...[
                  const SizedBox(width: 8),
                  _AnswerStatusBadge(answered: _answered),
                ],
              ],
            ),
            if (q.status != null || q.maxMark != null) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (q.status != null) q.status!,
                  if (q.maxMark != null) 'Marked out of ${q.maxMark}',
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (q.stemHtml.trim().isNotEmpty) HtmlContent(html: q.stemHtml),
            const SizedBox(height: 12),
            if (q.isMultichoice)
              RadioGroup<String>(
                groupValue: initialValue,
                onChanged: (value) {
                  onAnswerChanged(value);
                },
                child: Column(
                  children: [
                    for (final choice in q.choices)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: HtmlContent(html: choice.labelHtml),
                        value: choice.value,
                      ),
                  ],
                ),
              )
            else if (q.isShortAnswer)
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Answer',
                  border: OutlineInputBorder(),
                  helperText: r'LaTeX (\ ( … \) ) renders in review',
                ),
                textInputAction: TextInputAction.done,
              )
            else
              Text(
                'This question type (${q.type}) is not interactive yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnswerStatusBadge extends StatelessWidget {
  const _AnswerStatusBadge({required this.answered});

  final bool answered;

  @override
  Widget build(BuildContext context) {
    final color = answered ? const Color(0xFF2E7D4F) : const Color(0xFFB26A00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            answered ? Icons.check_circle_outline : Icons.error_outline,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            answered ? 'Answered' : 'Unanswered',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String _stripScripts(String html) {
  return html
      .replaceAll(
        RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
        '',
      )
      .replaceAll(
        RegExp(r'<style[\s\S]*?</style>', caseSensitive: false),
        '',
      );
}

String _extractStemHtml(String html) {
  final match = RegExp(
    r'<div class="qtext">([\s\S]*?)</div>\s*(?:<fieldset|<div class="ablock")',
    caseSensitive: false,
  ).firstMatch(html);
  if (match != null) {
    return match.group(1)?.trim() ?? '';
  }
  final fallback = RegExp(
    r'<div class="qtext">([\s\S]*?)</div>',
    caseSensitive: false,
  ).firstMatch(html);
  return fallback?.group(1)?.trim() ?? '';
}

String? _matchAttr(String html, String pattern) {
  return RegExp(pattern, caseSensitive: false).firstMatch(html)?.group(1);
}

String? _extractAnswerFieldName(String html, String type) {
  if (type == 'multichoice') {
    return _matchAttr(
      html,
      r'<input[^>]*type="radio"[^>]*name="(q\d+:\d+_answer)"[^>]*value="(?!-1)\d+"',
    ) ??
        _matchAttr(html, r'name="(q\d+:\d+_answer)"');
  }
  if (type == 'shortanswer') {
    return _matchAttr(
      html,
      r'<input[^>]*type="text"[^>]*name="(q\d+:\d+_answer)"',
    );
  }
  return null;
}

/// Extract the previously-submitted answer value from Moodle's HTML so a
/// resumed attempt restores the student's saved answers.
String? _extractInitialAnswer(String html, String type) {
  if (type == 'shortanswer') {
    return _matchAttr(
      html,
      r'<input[^>]*type="text"[^>]*name="q\d+:\d+_answer"[^>]*value="([^"]*)"',
    );
  }
  if (type == 'multichoice') {
    // Checked radio → its value is the saved answer.
    return _matchAttr(
      html,
      r'<input[^>]*type="radio"[^>]*name="q\d+:\d+_answer"[^>]*value="(-?\d+)"[^>]*checked',
    );
  }
  return null;
}

List<QuizChoiceOption> _extractChoices(String html) {
  final choices = <QuizChoiceOption>[];
  final radioPattern = RegExp(
    r'<input[^>]*type="radio"[^>]*name="q\d+:\d+_answer"[^>]*value="(-?\d+)"[^>]*',
    caseSensitive: false,
  );

  for (final match in radioPattern.allMatches(html)) {
    final value = match.group(1);
    if (value == null || value == '-1') {
      continue;
    }

    final after = html.substring(match.end);
    final labelMatch = RegExp(
      r'data-region="answer-label"[^>]*>\s*(?:<span class="answernumber">([^<]*)</span>)?\s*<div[^>]*>([\s\S]*?)</div>',
      caseSensitive: false,
    ).firstMatch(after);

    var labelHtml = '';
    if (labelMatch != null) {
      final number = (labelMatch.group(1) ?? '').trim();
      // Keep raw inner HTML so LaTeX renders via HtmlContent.
      final text = (labelMatch.group(2) ?? '').trim();
      labelHtml = [number, text].where((p) => p.isNotEmpty).join(' ');
    }
    if (labelHtml.isEmpty) {
      labelHtml = 'Option ${choices.length + 1}';
    }

    choices.add(QuizChoiceOption(value: value, labelHtml: labelHtml));
  }

  return choices;
}