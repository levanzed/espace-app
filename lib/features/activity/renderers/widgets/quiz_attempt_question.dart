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
  const QuizChoiceOption({required this.value, required this.label});

  final String value;
  final String label;
}

/// Native MCQ / short-answer controls for one Moodle quiz question.
class QuizAttemptQuestionCard extends StatefulWidget {
  const QuizAttemptQuestionCard({
    super.key,
    required this.question,
    required this.onAnswerChanged,
  });

  final ParsedQuizQuestion question;
  final ValueChanged<String?> onAnswerChanged;

  @override
  State<QuizAttemptQuestionCard> createState() =>
      _QuizAttemptQuestionCardState();
}

class _QuizAttemptQuestionCardState extends State<QuizAttemptQuestionCard> {
  String? _selectedValue;
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _textController.addListener(() {
      widget.onAnswerChanged(
        _textController.text.trim().isEmpty ? null : _textController.text,
      );
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question ${q.number ?? q.slot}',
              style: theme.textTheme.titleMedium,
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
                groupValue: _selectedValue,
                onChanged: (value) {
                  setState(() => _selectedValue = value);
                  widget.onAnswerChanged(value);
                },
                child: Column(
                  children: [
                    for (final choice in q.choices)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(choice.label),
                        value: choice.value,
                      ),
                  ],
                ),
              )
            else if (q.isShortAnswer)
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Answer',
                  border: OutlineInputBorder(),
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

    var label = '';
    if (labelMatch != null) {
      final number = (labelMatch.group(1) ?? '').trim();
      final text = _stripTags(labelMatch.group(2) ?? '').trim();
      label = [number, text].where((part) => part.isNotEmpty).join(' ');
    }
    if (label.isEmpty) {
      label = 'Option ${choices.length + 1}';
    }

    choices.add(QuizChoiceOption(value: value, label: label));
  }

  return choices;
}

String _stripTags(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
