import 'package:flutter/material.dart';

import '../models/quiz_draft.dart';

/// Local-only quiz settings (applied to Moodle in Phase 2).
class QuizSettingsSheet extends StatefulWidget {
  const QuizSettingsSheet({super.key, required this.settings});

  final QuizSettingsDraft settings;

  static Future<QuizSettingsDraft?> show(
    BuildContext context,
    QuizSettingsDraft settings,
  ) {
    return showModalBottomSheet<QuizSettingsDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => QuizSettingsSheet(settings: settings),
    );
  }

  @override
  State<QuizSettingsSheet> createState() => _QuizSettingsSheetState();
}

class _QuizSettingsSheetState extends State<QuizSettingsSheet> {
  late final TextEditingController _timeLimit;
  late final TextEditingController _attempts;
  late final TextEditingController _passGrade;
  late bool _shuffleQuestions;
  late bool _shuffleAnswers;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _timeLimit = TextEditingController(
      text: s.timeLimitSeconds <= 0 ? '' : '${s.timeLimitSeconds ~/ 60}',
    );
    _attempts = TextEditingController(
      text: s.attemptsAllowed <= 0 ? '' : '${s.attemptsAllowed}',
    );
    _passGrade = TextEditingController(
      text: s.gradeToPass <= 0 ? '' : '${s.gradeToPass}',
    );
    _shuffleQuestions = s.shuffleQuestions;
    _shuffleAnswers = s.shuffleAnswers;
  }

  @override
  void dispose() {
    _timeLimit.dispose();
    _attempts.dispose();
    _passGrade.dispose();
    super.dispose();
  }

  void _save() {
    final minutes = int.tryParse(_timeLimit.text.trim()) ?? 0;
    final attempts = int.tryParse(_attempts.text.trim()) ?? 0;
    final pass = double.tryParse(_passGrade.text.trim()) ?? 0;
    Navigator.pop(
      context,
      QuizSettingsDraft(
        timeLimitSeconds: minutes <= 0 ? 0 : minutes * 60,
        attemptsAllowed: attempts < 0 ? 0 : attempts,
        shuffleQuestions: _shuffleQuestions,
        shuffleAnswers: _shuffleAnswers,
        gradeToPass: pass < 0 ? 0 : pass,
        timeOpen: widget.settings.timeOpen,
        timeClose: widget.settings.timeClose,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Quiz settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Stored on this draft only. Moodle apply comes in Phase 2.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _timeLimit,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Time limit (minutes)',
                helperText: 'Leave empty for no limit',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _attempts,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Attempts allowed',
                helperText: 'Leave empty for unlimited',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passGrade,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Pass grade',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Shuffle questions'),
              value: _shuffleQuestions,
              onChanged: (v) => setState(() => _shuffleQuestions = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Shuffle answers'),
              value: _shuffleAnswers,
              onChanged: (v) => setState(() => _shuffleAnswers = v),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _save,
              child: const Text('Save settings'),
            ),
          ],
        ),
      ),
    );
  }
}
