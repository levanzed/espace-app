import 'package:flutter/material.dart';

import '../models/quiz_draft.dart';

/// Full-screen question editor (replaces cramped dialogs).
///
/// Returns an updated [QuizQuestionDraft], or null if cancelled.
class QuizQuestionEditorScreen extends StatefulWidget {
  const QuizQuestionEditorScreen({
    super.key,
    required this.type,
    this.existing,
  });

  final QuizQuestionType type;
  final QuizQuestionDraft? existing;

  @override
  State<QuizQuestionEditorScreen> createState() =>
      _QuizQuestionEditorScreenState();
}

class _QuizQuestionEditorScreenState extends State<QuizQuestionEditorScreen> {
  static const Color _accent = Color(0xFF5B4B8A);

  late final TextEditingController _stem;
  late final TextEditingController _mark;
  late List<TextEditingController> _options;
  int _correctIndex = 0;
  bool _caseSensitive = false;
  String? _localError;

  bool get _isMcq => widget.type == QuizQuestionType.multipleChoice;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _stem = TextEditingController(text: e?.stem ?? '');
    _mark = TextEditingController(text: (e?.mark ?? 1.0).toString());
    _caseSensitive = e?.caseSensitive ?? false;

    if (_isMcq) {
      if (e != null && e.choices.isNotEmpty) {
        _options =
            e.choices.map((c) => TextEditingController(text: c.text)).toList();
        _correctIndex = e.choices.indexWhere((c) => c.correct);
        if (_correctIndex < 0) _correctIndex = 0;
      } else {
        _options = [TextEditingController(), TextEditingController()];
      }
    } else {
      if (e != null && e.answers.isNotEmpty) {
        _options =
            e.answers.map((a) => TextEditingController(text: a.text)).toList();
      } else {
        _options = [TextEditingController()];
      }
    }
  }

  @override
  void dispose() {
    _stem.dispose();
    _mark.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() => _options.add(TextEditingController()));
  }

  void _removeOption(int index) {
    final minCount = _isMcq ? 2 : 1;
    if (_options.length <= minCount) return;
    setState(() {
      _options[index].dispose();
      _options.removeAt(index);
      if (_correctIndex >= _options.length) {
        _correctIndex = _options.length - 1;
      }
    });
  }

  void _save() {
    final stem = _stem.text.trim();
    if (stem.isEmpty) {
      setState(() => _localError = 'Add a question stem.');
      return;
    }
    final mark = double.tryParse(_mark.text.trim()) ?? 0;
    if (mark <= 0) {
      setState(() => _localError = 'Mark must be greater than zero.');
      return;
    }

    final id =
        widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString();

    if (_isMcq) {
      final filled = <McqChoiceDraft>[];
      for (var i = 0; i < _options.length; i++) {
        final text = _options[i].text.trim();
        if (text.isEmpty) continue;
        filled.add(McqChoiceDraft(text: text, correct: i == _correctIndex));
      }
      if (filled.length < 2) {
        setState(() => _localError = 'Add at least two choices.');
        return;
      }
      if (!filled.any((c) => c.correct)) {
        // Correct index pointed at an empty row — force first filled as correct.
        filled.first.correct = true;
      }
      final correctCount = filled.where((c) => c.correct).length;
      if (correctCount != 1) {
        setState(() => _localError = 'Mark exactly one choice as correct.');
        return;
      }
      Navigator.pop(
        context,
        QuizQuestionDraft(
          id: id,
          type: QuizQuestionType.multipleChoice,
          mark: mark,
          stem: stem,
          choices: filled,
        ),
      );
      return;
    }

    final answers = _options
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .map((t) => ShortAnswerEntryDraft(text: t))
        .toList();
    if (answers.isEmpty) {
      setState(() => _localError = 'Add at least one accepted answer.');
      return;
    }
    Navigator.pop(
      context,
      QuizQuestionDraft(
        id: id,
        type: QuizQuestionType.shortAnswer,
        mark: mark,
        stem: stem,
        answers: answers,
        caseSensitive: _caseSensitive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    final title = _isMcq
        ? (isNew ? 'Multiple choice' : 'Edit multiple choice')
        : (isNew ? 'Short answer' : 'Edit short answer');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(title),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Done',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          if (_localError != null) ...[
            _ErrorBanner(message: _localError!),
            const SizedBox(height: 16),
          ],
          _SectionLabel(label: 'Question'),
          const SizedBox(height: 10),
          TextField(
            controller: _stem,
            autofocus: isNew,
            maxLines: 4,
            minLines: 3,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, height: 1.4),
            decoration: InputDecoration(
              hintText: 'Write the question…',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _mark,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Points',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          _SectionLabel(
            label: _isMcq ? 'Choices' : 'Accepted answers',
            hint: _isMcq ? 'Tap the circle to mark the correct one' : null,
          ),
          const SizedBox(height: 12),
          ...List.generate(_options.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                  child: Row(
                    children: [
                      if (_isMcq)
                        Radio<int>(
                          value: index,
                          groupValue: _correctIndex,
                          activeColor: _accent,
                          onChanged: (v) =>
                              setState(() => _correctIndex = v ?? 0),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            Icons.tag_rounded,
                            size: 18,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      Expanded(
                        child: TextField(
                          controller: _options[index],
                          decoration: InputDecoration(
                            hintText: _isMcq
                                ? 'Choice ${index + 1}'
                                : 'Answer ${index + 1}',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_options.length > (_isMcq ? 2 : 1))
                        IconButton(
                          onPressed: () => _removeOption(index),
                          icon: Icon(
                            Icons.remove_circle_outline,
                            color: Colors.grey.shade400,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _addOption,
            icon: const Icon(Icons.add_rounded),
            label: Text(_isMcq ? 'Add choice' : 'Add answer'),
            style: TextButton.styleFrom(foregroundColor: _accent),
          ),
          if (!_isMcq) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Case sensitive'),
              subtitle: const Text('Answers must match letter casing'),
              value: _caseSensitive,
              activeThumbColor: _accent,
              onChanged: (v) => setState(() => _caseSensitive = v),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.hint});

  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint!,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message, style: TextStyle(color: Colors.red.shade900)),
      ),
    );
  }
}
