import 'package:dio/dio.dart';
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

  /// The most recent open (in-progress) attempt, if any.
  Map<String, dynamic>? get _openAttempt {
    for (final attempt in _attempts) {
      final map = Map<String, dynamic>.from(attempt as Map);
      if (map['state'] == 'inprogress') return map;
    }
    return null;
  }

  /// Number of finished attempts (Moodle states: finished / overdue / abandoned).
  int get _finishedCount {
    return _attempts
        .where((a) {
          final state = Map<String, dynamic>.from(a as Map)['state']?.toString();
          return state == 'finished' || state == 'overdue' || state == 'abandoned';
        })
        .length;
  }

  /// Moodle attempts-allowed value (0 = unlimited).
  int get _attemptsAllowed => _asInt(_quiz['attempts']) ?? 0;

  bool get _hasAttemptsRemaining =>
      _attemptsAllowed == 0 || _finishedCount < _attemptsAllowed;

  /// The most recent finished attempt (for review when exhausted).
  Map<String, dynamic>? get _lastFinishedAttempt {
    Map<String, dynamic>? last;
    for (final attempt in _attempts) {
      final map = Map<String, dynamic>.from(attempt as Map);
      final state = map['state']?.toString();
      if (state == 'finished' || state == 'overdue' || state == 'abandoned') {
        last = map;
      }
    }
    return last;
  }

  Future<void> _loadAttempt(int attemptId) async {
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
      _review = null;
      _message = 'Attempt $attemptId resumed.';
    });
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _message = null;
      _review = null;
    });
    try {
      // Resume an open attempt if one exists (Moodle rejects start_attempt
      // while an attempt is in progress → HTTP 400).
      final open = _openAttempt;
      if (open != null) {
        final attemptId = _asInt(open['id']);
        if (attemptId != null) {
          await _loadAttempt(attemptId);
          return;
        }
      }

      // No open attempt: start a new one (only if attempts remain).
      if (!_hasAttemptsRemaining) {
        final last = _lastFinishedAttempt;
        if (last != null) {
          final attemptId = _asInt(last['id']);
          if (attemptId != null) {
            final review = await widget.repository.reviewQuizAttempt(
              widget.activity.id,
              attemptId,
            );
            setState(() {
              _review = review;
              _message = 'No attempts remaining. Showing your last review.';
            });
            return;
          }
        }
        setState(() => _message = 'No attempts remaining.');
        return;
      }

      final started =
          await widget.repository.startQuizAttempt(widget.activity.id);
      final attempt =
          Map<String, dynamic>.from(started['attempt'] as Map? ?? started);
      final attemptId = _asInt(attempt['id']);
      if (attemptId == null) {
        throw Exception('Quiz attempt id missing');
      }
      await _loadAttempt(attemptId);
      setState(() => _message = 'Attempt $attemptId started.');
    } catch (error) {
      setState(() => _message = _friendlyError(error));
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
    final attemptId = _asInt(attempt['id']);
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
      setState(() => _message = _friendlyError(error));
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _reviewLast() async {
    final last = _lastFinishedAttempt;
    if (last == null) return;
    final attemptId = _asInt(last['id']);
    if (attemptId == null) return;

    setState(() => _busy = true);
    try {
      final review = await widget.repository.reviewQuizAttempt(
        widget.activity.id,
        attemptId,
      );
      setState(() {
        _review = review;
        _message = null;
      });
    } catch (error) {
      setState(() => _message = _friendlyError(error));
    } finally {
      setState(() => _busy = false);
    }
  }

  /// Extract the Moodle message from a DioException (FastAPI detail.moodle).
  String _friendlyError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail is Map) {
          final message = detail['message']?.toString().trim();
          if (message != null && message.isNotEmpty) return message;
          final moodle = detail['moodle'];
          if (moodle is Map) {
            final moodleMessage = moodle['message']?.toString().trim();
            if (moodleMessage != null && moodleMessage.isNotEmpty) {
              return moodleMessage;
            }
          }
        }
        if (detail is String && detail.trim().isNotEmpty) return detail.trim();
      }
    }
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    final open = _openAttempt;
    final hasOpen = open != null;
    final canStart = _hasAttemptsRemaining;

    String buttonLabel;
    IconData buttonIcon;
    if (hasOpen) {
      buttonLabel = 'Resume attempt';
      buttonIcon = Icons.play_arrow_rounded;
    } else if (canStart) {
      buttonLabel = 'Start attempt';
      buttonIcon = Icons.play_arrow_rounded;
    } else {
      buttonLabel = 'Review last attempt';
      buttonIcon = Icons.rate_review_rounded;
    }

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
          value: formatTimestamp(_asInt(_quiz['timeopen'])),
        ),
        _InfoCard(
          icon: Icons.timer_off_rounded,
          title: 'Closes',
          value: formatTimestamp(_asInt(_quiz['timeclose'])),
        ),
        _InfoCard(
          icon: Icons.replay_rounded,
          title: 'Attempts allowed',
          value: _attemptsAllowed == 0
              ? 'Unlimited'
              : '$_attemptsAllowed',
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
            final state = map['state']?.toString() ?? 'unknown';
            final stateLabel = _stateLabel(state);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.fact_check_rounded),
                title: Text('Attempt ${map['attempt'] ?? ''}'),
                subtitle: Text(
                  'State: $stateLabel • Grade: ${map['sumgrades'] ?? '-'}',
                ),
                trailing: state == 'finished' || state == 'overdue'
                    ? IconButton(
                        tooltip: 'Review',
                        onPressed: _busy ? null : _reviewLast,
                        icon: const Icon(Icons.visibility_outlined),
                      )
                    : null,
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
          icon: Icon(buttonIcon),
          label: Text(buttonLabel),
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

  static String _stateLabel(String state) {
    switch (state) {
      case 'inprogress':
        return 'In progress';
      case 'finished':
        return 'Finished';
      case 'overdue':
        return 'Overdue';
      case 'abandoned':
        return 'Abandoned';
      default:
        return state;
    }
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

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}