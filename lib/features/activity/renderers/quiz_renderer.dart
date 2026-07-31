import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'widgets/activity_layout.dart';
import 'widgets/activity_utils.dart';
import 'widgets/html_content.dart';

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
    });
    try {
      final started = await widget.repository.startQuizAttempt(widget.activity.id);
      final attempt = Map<String, dynamic>.from(started['attempt'] as Map? ?? started);
      final attemptId = attempt['id'] as int?;
      if (attemptId == null) {
        throw Exception('Quiz attempt id missing');
      }
      final data = await widget.repository.getQuizAttemptData(
        widget.activity.id,
        attemptId,
      );
      setState(() {
        _attemptData = data;
        _message = 'Attempt $attemptId started.';
      });
    } catch (error) {
      setState(() => _message = error.toString());
    } finally {
      setState(() => _busy = false);
    }
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
        finishattempt: 1,
      );
      final review = await widget.repository.reviewQuizAttempt(
        widget.activity.id,
        attemptId,
      );
      setState(() {
        _review = review;
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
    final questions = List<dynamic>.from(_attemptData?['questions'] ?? const []);

    return ActivityLayout(
      activity: widget.activity,
      children: [
        HtmlContent(html: _quiz['intro']?.toString() ?? widget.activity.description),
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
        if (questions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Current attempt questions',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...questions.map((question) {
            final map = Map<String, dynamic>.from(question as Map);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: HtmlContent(html: map['html']?.toString() ?? ''),
              ),
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
