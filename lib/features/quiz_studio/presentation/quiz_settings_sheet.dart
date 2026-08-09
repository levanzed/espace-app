import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/quiz_draft.dart';

/// Quiz settings applied to Moodle on publish.
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
  static const _accent = Color(0xFF5B4B8A);
  static const _qppPresets = [0, 1, 2, 5, 10];

  late final TextEditingController _timeLimit;
  late final TextEditingController _attempts;
  late final TextEditingController _passGrade;
  late final TextEditingController _customQppController;
  late bool _shuffleQuestions;
  late bool _shuffleAnswers;
  late DateTime? _timeOpen;
  late DateTime? _timeClose;
  late int _questionsPerPage;
  late FeedbackRelease _feedbackRelease;
  bool _customQpp = false;

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
    _timeOpen = s.timeOpen;
    _timeClose = s.timeClose;
    _questionsPerPage = s.questionsPerPage;
    _feedbackRelease = s.feedbackRelease;
    _customQpp = !_qppPresets.contains(s.questionsPerPage) && s.questionsPerPage > 0;
    _customQppController = TextEditingController(
      text: _customQpp ? '${s.questionsPerPage}' : '',
    );
  }

  @override
  void dispose() {
    _timeLimit.dispose();
    _attempts.dispose();
    _passGrade.dispose();
    _customQppController.dispose();
    super.dispose();
  }

  void _save() {
    final minutes = int.tryParse(_timeLimit.text.trim()) ?? 0;
    final attempts = int.tryParse(_attempts.text.trim()) ?? 0;
    final pass = double.tryParse(_passGrade.text.trim()) ?? 0;
    var qpp = _questionsPerPage;
    if (_customQpp) {
      qpp = int.tryParse(_customQppController.text.trim()) ?? 0;
      if (qpp < 0) qpp = 0;
    }
    Navigator.pop(
      context,
      QuizSettingsDraft(
        timeLimitSeconds: minutes <= 0 ? 0 : minutes * 60,
        attemptsAllowed: attempts < 0 ? 0 : attempts,
        shuffleQuestions: _shuffleQuestions,
        shuffleAnswers: _shuffleAnswers,
        gradeToPass: pass < 0 ? 0 : pass,
        timeOpen: _timeOpen,
        timeClose: _timeClose,
        questionsPerPage: qpp,
        feedbackRelease: _feedbackRelease,
      ),
    );
  }

  Future<void> _pickDateTime({required bool isOpen}) async {
    final current = isOpen ? _timeOpen : _timeClose;
    final now = DateTime.now();
    final initial = current ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;

    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isOpen) {
        _timeOpen = combined;
      } else {
        _timeClose = combined;
      }
    });
  }

  void _clearDateTime({required bool isOpen}) {
    setState(() {
      if (isOpen) {
        _timeOpen = null;
      } else {
        _timeClose = null;
      }
    });
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
              'Applied when you publish this quiz to Moodle.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 20),
            const _SectionHeader(label: 'General'),
            const SizedBox(height: 12),
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
            const SizedBox(height: 20),
            const _SectionHeader(label: 'Availability'),
            const SizedBox(height: 12),
            _DateTimeTile(
              label: 'Open date & time',
              value: _timeOpen,
              onPick: () => _pickDateTime(isOpen: true),
              onClear: _timeOpen == null ? null : () => _clearDateTime(isOpen: true),
            ),
            const SizedBox(height: 8),
            _DateTimeTile(
              label: 'Close date & time',
              value: _timeClose,
              onPick: () => _pickDateTime(isOpen: false),
              onClear: _timeClose == null ? null : () => _clearDateTime(isOpen: false),
            ),
            const SizedBox(height: 20),
            const _SectionHeader(label: 'Behaviour'),
            const SizedBox(height: 4),
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
            Text(
              'Questions per page',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _qppPresets)
                  ChoiceChip(
                    label: Text(preset == 0 ? 'All' : '$preset'),
                    selected: !_customQpp && _questionsPerPage == preset,
                    onSelected: (_) => setState(() {
                      _customQpp = false;
                      _questionsPerPage = preset;
                    }),
                  ),
                ChoiceChip(
                  label: const Text('Custom'),
                  selected: _customQpp,
                  onSelected: (_) => setState(() => _customQpp = true),
                ),
              ],
            ),
            if (_customQpp) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customQppController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Questions per page',
                  helperText: '0 = all on one page',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const _SectionHeader(label: 'Feedback'),
            const SizedBox(height: 4),
            Text(
              'When to release question feedback to students',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<FeedbackRelease>(
              initialValue: _feedbackRelease,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: FeedbackRelease.immediately,
                  child: Text('Immediately after submission'),
                ),
                DropdownMenuItem(
                  value: FeedbackRelease.afterAttempt,
                  child: Text('After the attempt is finished'),
                ),
                DropdownMenuItem(
                  value: FeedbackRelease.afterOpen,
                  child: Text('After the quiz opens'),
                ),
                DropdownMenuItem(
                  value: FeedbackRelease.afterClose,
                  child: Text('After the quiz closes'),
                ),
                DropdownMenuItem(
                  value: FeedbackRelease.never,
                  child: Text('Never'),
                ),
              ],
              onChanged: (v) => setState(() => _feedbackRelease = v ?? _feedbackRelease),
            ),
            const SizedBox(height: 20),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade600,
      ),
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({
    required this.label,
    required this.value,
    required this.onPick,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(Icons.event_rounded, color: _QuizSettingsSheetState._accent),
        title: Text(label),
        subtitle: Text(
          value == null
              ? 'Not set'
              : DateFormat('EEE, MMM d, yyyy · h:mm a').format(value!),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onClear != null)
              IconButton(
                tooltip: 'Clear',
                onPressed: onClear,
                icon: Icon(Icons.close_rounded, color: Colors.grey.shade500),
              ),
            IconButton(
              tooltip: 'Pick',
              onPressed: onPick,
              icon: const Icon(Icons.edit_calendar_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
