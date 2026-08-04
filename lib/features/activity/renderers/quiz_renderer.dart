import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'widgets/activity_layout.dart';
import 'widgets/activity_utils.dart';
import 'widgets/html_content.dart';
import 'widgets/quiz_attempt_question.dart';

class QuizRenderer extends ActivityRenderer {
  const QuizRenderer();

  @override
  Widget build(
    BuildContext context,
    Activity activity, {
    ActivityRepository? repository,
  }) {
    return _QuizView(
      activity: activity,
      repository: repository ?? ActivityRepository(),
    );
  }
}

class _QuizView extends StatefulWidget {
  const _QuizView({
    required this.activity,
    required this.repository,
  });

  final Activity activity;
  final ActivityRepository repository;

  @override
  State<_QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<_QuizView> {
  bool _busy = false;
  String? _message;
  Map<String, dynamic>? _attemptData;
  Map<String, dynamic>? _review;
  List<ParsedQuizQuestion> _parsedQuestions = const [];
  /// slot → Moodle answer field value (radio value or typed text).
  final Map<int, String> _answers = {};

  Map<String, dynamic> get _quiz => Map<String, dynamic>.from(
        widget.activity.details['quiz'] as Map? ?? const {},
      );

  List<dynamic> get _attempts {
    final attemptsData = Map<String, dynamic>.from(
      widget.activity.details['attempts'] as Map? ?? const {},
    );
    return List<dynamic>.from(attemptsData['attempts'] ?? const []);
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _message = null;
      _review = null;
    });
    try {
      final started =
          await widget.repository.startQuizAttempt(widget.activity.id);
      final attempt =
          Map<String, dynamic>.from(started['attempt'] as Map? ?? started);
      final attemptId = attempt['id'] as int?;
      if (attemptId == null) {
        throw Exception('Quiz attempt id missing');
      }
      final data = await widget.repository.getQuizAttemptData(
        widget.activity.id,
        attemptId,
      );
      final questions = List<dynamic>.from(data['questions'] ?? const []);
      final parsed = questions
          .map((q) => ParsedQuizQuestion.fromMoodle(
                Map<String, dynamic>.from(q as Map),
              ))
          .toList();
      setState(() {
        _attemptData = data;
        _parsedQuestions = parsed;
        _answers.clear();
        _message = 'Attempt $attemptId started.';
      });
    } catch (error) {
      setState(() => _message = error.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  List<Map<String, dynamic>> _buildProcessData() {
    final rows = <Map<String, dynamic>>[];
    for (final question in _parsedQuestions) {
      final answer = _answers[question.slot];
      for (final row in question.toProcessRows(answer)) {
        rows.add(row);
      }
    }
    return rows;
  }

  Future<void> _finish() async {
    final attempt = Map<String, dynamic>.from(
      _attemptData?['attempt'] as Map? ?? const {},
    );
    final attemptId = attempt['id'] as int?;
    if (attemptId == null) {
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.repository.processQuizAttempt(
        widget.activity.id,
        attemptId,
        data: _buildProcessData(),
        finishattempt: 1,
      );
      final review = await widget.repository.reviewQuizAttempt(
        widget.activity.id,
        attemptId,
      );
      setState(() {
        _review = review;
        _parsedQuestions = const [];
        _answers.clear();
        _attemptData = null;
        _message = 'Attempt submitted.';
      });
    } catch (error) {
      setState(() => _message = error.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActivityLayout(
      activity: widget.activity,
      children: [
        HtmlContent(
          html: _quiz['intro']?.toString() ?? widget.activity.description,
        ),
        const SizedBox(height: 20),
        _InfoCard(
          icon: Icons.schedule_rounded,
          title: 'Opens',
          value: formatTimestamp(_quiz['timeopen'] as int?),
        ),
        _InfoCard(
          icon: Icons.timer_off_rounded,
          title: 'Closes',
          value: formatTimestamp(_quiz['timeclose'] as int?),
        ),
        _InfoCard(
          icon: Icons.replay_rounded,
          title: 'Attempts allowed',
          value: _quiz['attempts']?.toString() ?? 'Unlimited',
        ),
        Text('Your attempts', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_attempts.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.quiz_outlined),
              title: Text('No attempts yet'),
            ),
          )
        else
          ..._attempts.map((attempt) {
            final map = Map<String, dynamic>.from(attempt as Map);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.fact_check_rounded),
                title: Text('Attempt ${map['attempt'] ?? ''}'),
                subtitle: Text(
                  'State: ${map['state'] ?? 'unknown'} • Grade: ${map['sumgrades'] ?? '-'}',
                ),
              ),
            );
          }),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(_message!),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _start,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start / resume attempt'),
        ),
        if (_parsedQuestions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Current attempt questions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ..._parsedQuestions.map((question) {
            return QuizAttemptQuestionCard(
              key: ValueKey('quiz-q-${question.slot}'),
              question: question,
              onAnswerChanged: (value) {
                setState(() {
                  if (value == null || value.isEmpty) {
                    _answers.remove(question.slot);
                  } else {
                    _answers[question.slot] = value;
                  }
                });
              },
            );
          }),
          FilledButton(
            onPressed: _busy ? null : _finish,
            child: const Text('Submit attempt'),
          ),
        ],
        if (_review != null) ...[
          const SizedBox(height: 16),
          Text('Review', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Grade: ${_review!['grade'] ?? '-'}'),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }
}
