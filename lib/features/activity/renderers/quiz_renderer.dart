import 'dart:async';

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
  /// slot → Moodle answer field value (radio value or typed text).
  final Map<int, String> _answers = {};
  /// slot → short-answer TextEditingController (owned here so cursor survives
  /// page navigation — fixes LaTeX cursor jumping back to the question stem).
  final Map<int, TextEditingController> _textControllers = {};
  /// page → questions cache so review/submit cover the WHOLE attempt.
  final Map<int, List<ParsedQuizQuestion>> _questionsByPage = {};

  int _currentPage = 0;
  bool _hasPrevPage = false;
  bool _hasNextPage = false;
  bool _reviewMode = false;

  int? _timeLeftSeconds;
  Timer? _timer;
  Timer? _autosaveDebounce;

  @override
  void dispose() {
    _timer?.cancel();
    _autosaveDebounce?.cancel();
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _quiz => Map<String, dynamic>.from(
        widget.activity.details['quiz'] as Map? ?? const {},
      );

  List<dynamic> get _attempts {
    final attemptsData = Map<String, dynamic>.from(
      widget.activity.details['attempts'] as Map? ?? const {},
    );
    return List<dynamic>.from(attemptsData['attempts'] ?? const []);
  }

  Map<String, dynamic>? get _openAttempt {
    for (final attempt in _attempts) {
      final map = Map<String, dynamic>.from(attempt as Map);
      if (map['state'] == 'inprogress') return map;
    }
    return null;
  }

  int get _finishedCount {
    return _attempts
        .where((a) {
          final state = Map<String, dynamic>.from(a as Map)['state']?.toString();
          return state == 'finished' || state == 'overdue' || state == 'abandoned';
        })
        .length;
  }

  int get _attemptsAllowed => _asInt(_quiz['attempts']) ?? 0;

  bool get _hasAttemptsRemaining =>
      _attemptsAllowed == 0 || _finishedCount < _attemptsAllowed;

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

  int? get _currentAttemptId {
    final attempt = Map<String, dynamic>.from(
      _attemptData?['attempt'] as Map? ?? const {},
    );
    return _asInt(attempt['id']);
  }

  /// All cached questions in page order (review / full submit payload).
  List<ParsedQuizQuestion> get _allQuestions {
    final pages = _questionsByPage.keys.toList()..sort();
    final result = <ParsedQuizQuestion>[];
    for (final page in pages) {
      result.addAll(_questionsByPage[page] ?? const []);
    }
    return result;
  }

  List<ParsedQuizQuestion> get _currentPageQuestions =>
      _questionsByPage[_currentPage] ?? const [];

  int get _answeredCount => _answers.length;

  bool _isAnswered(ParsedQuizQuestion question) {
    final value = _answers[question.slot];
    return value != null && value.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Timer
  // ---------------------------------------------------------------------------

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _startTimer(int seconds) {
    _stopTimer();
    if (seconds <= 0) return;
    _timeLeftSeconds = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _timeLeftSeconds = (_timeLeftSeconds ?? 0) - 1;
      });
      if ((_timeLeftSeconds ?? 0) <= 0) {
        timer.cancel();
        _timer = null;
        _onTimeUp();
      }
    });
  }

  Future<void> _onTimeUp() async {
    final attemptId = _currentAttemptId;
    if (attemptId == null) return;

    setState(() {
      _busy = true;
      _message = 'Time is up — saving and submitting your attempt…';
    });
    try {
      await _cacheAllRemainingPages(attemptId);
      await widget.repository.saveQuizAttempt(
        widget.activity.id,
        attemptId,
        data: _buildProcessData(),
      );
      await widget.repository.processQuizAttempt(
        widget.activity.id,
        attemptId,
        data: _buildProcessData(),
        finishattempt: 1,
        timeup: 1,
      );
      final review = await widget.repository.reviewQuizAttempt(
        widget.activity.id,
        attemptId,
      );
      if (!mounted) return;
      _disposeAnswerControllers();
      setState(() {
        _review = review;
        _answers.clear();
        _attemptData = null;
        _reviewMode = false;
        _questionsByPage.clear();
        _message =
            'The time limit has been reached. Your attempt was submitted automatically.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Attempt lifecycle
  // ---------------------------------------------------------------------------

  Future<void> _loadAttempt(int attemptId, {int page = 0}) async {
    final data = await widget.repository.getQuizAttemptData(
      widget.activity.id,
      attemptId,
      page: page,
    );
    final questions = List<dynamic>.from(data['questions'] ?? const []);
    final parsed = questions
        .map((q) => ParsedQuizQuestion.fromMoodle(
              Map<String, dynamic>.from(q as Map),
            ))
        .toList();
    final attempt = Map<String, dynamic>.from(data['attempt'] as Map? ?? const {});
    final timeLeft = _asInt(attempt['timeleft']);

    // Cache page questions for review / full submit.
    _questionsByPage[page] = parsed;

    // Create/restore short-answer controllers so cursor position survives
    // page navigation (fixes LaTeX cursor jumping to the question stem).
    for (final q in parsed) {
      if (!q.isShortAnswer) continue;
      final existing = _textControllers[q.slot];
      if (existing != null) {
        final saved = _answers[q.slot];
        if (existing.text.isEmpty && saved != null) {
          existing.text = saved;
        }
      } else {
        final controller = TextEditingController(
          text: _answers[q.slot] ?? q.initialAnswer ?? '',
        );
        controller.addListener(() {
          final value = controller.text.trim();
          if (value.isEmpty) {
            _answers.remove(q.slot);
          } else {
            _answers[q.slot] = value;
          }
        });
        _textControllers[q.slot] = controller;
      }
    }

    setState(() {
      _attemptData = data;
      _currentPage = _asInt(attempt['currentpage']) ?? page;
      _hasPrevPage = (_asInt(attempt['previouspage']) ?? -1) >= 0;
      _hasNextPage = (_asInt(attempt['nextpage']) ?? -1) >= 0;
      _reviewMode = false;

      if (timeLeft != null && timeLeft > 0) {
        _startTimer(timeLeft);
      } else {
        _stopTimer();
        _timeLeftSeconds = null;
      }
      _message = null;
    });
  }

  /// Walk remaining pages so review / submit cover the whole attempt.
  Future<void> _cacheAllRemainingPages(int attemptId) async {
    var page = _currentPage;
    var hasNext = _hasNextPage;
    while (hasNext) {
      page += 1;
      final data = await widget.repository.getQuizAttemptData(
        widget.activity.id,
        attemptId,
        page: page,
      );
      final questions = List<dynamic>.from(data['questions'] ?? const []);
      final parsed = questions
          .map((q) => ParsedQuizQuestion.fromMoodle(
                Map<String, dynamic>.from(q as Map),
              ))
          .toList();
      _questionsByPage[page] = parsed;
      await _ensureControllers(parsed);
      final attempt =
          Map<String, dynamic>.from(data['attempt'] as Map? ?? const {});
      hasNext = (_asInt(attempt['nextpage']) ?? -1) >= 0;
    }
  }

  Future<void> _ensureControllers(List<ParsedQuizQuestion> parsed) async {
    for (final q in parsed) {
      if (!q.isShortAnswer) continue;
      if (_textControllers.containsKey(q.slot)) continue;
      final controller = TextEditingController(
        text: _answers[q.slot] ?? q.initialAnswer ?? '',
      );
      controller.addListener(() {
        final value = controller.text.trim();
        if (value.isEmpty) {
          _answers.remove(q.slot);
        } else {
          _answers[q.slot] = value;
        }
      });
      _textControllers[q.slot] = controller;
    }
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _message = null;
      _review = null;
    });
    try {
      final open = _openAttempt;
      if (open != null) {
        final attemptId = _asInt(open['id']);
        if (attemptId != null) {
          await _loadAttempt(attemptId);
          setState(() => _message = 'Attempt $attemptId resumed.');
          return;
        }
      }

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

  // ---------------------------------------------------------------------------
  // Save / process / review
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _buildProcessData() {
    final rows = <Map<String, dynamic>>[];
    for (final question in _allQuestions) {
      final answer = _answers[question.slot];
      for (final row in question.toProcessRows(answer)) {
        rows.add(row);
      }
    }
    return rows;
  }

  void _scheduleAutosave() {
    _autosaveDebounce?.cancel();
    _autosaveDebounce = Timer(const Duration(milliseconds: 800), _autosave);
  }

  Future<void> _autosave() async {
    final attemptId = _currentAttemptId;
    if (attemptId == null || _reviewMode) return;
    try {
      await widget.repository.saveQuizAttempt(
        widget.activity.id,
        attemptId,
        data: _buildProcessData(),
      );
    } catch (_) {
      // Non-fatal; next nav/save retries.
    }
  }

  Future<void> _goToPage(int targetPage) async {
    final attemptId = _currentAttemptId;
    if (attemptId == null || _busy) return;

    setState(() => _busy = true);
    try {
      await _autosave();
      await _loadAttempt(attemptId, page: targetPage);
    } catch (error) {
      setState(() => _message = _friendlyError(error));
    } finally {
      setState(() => _busy = false);
    }
  }

  final List<GlobalKey> _reviewQuestionKeys = [];

  Future<void> _enterReview() async {
    final attemptId = _currentAttemptId;
    if (attemptId == null) return;

    setState(() => _busy = true);
    try {
      await _cacheAllRemainingPages(attemptId);
      if (!mounted) return;
      _reviewQuestionKeys
        ..clear()
        ..addAll(List.generate(_allQuestions.length, (_) => GlobalKey()));
      setState(() {
        _reviewMode = true;
        _message = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _jumpToQuestion(int index) async {
    final context = _reviewQuestionKeys[index].currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 300),
      alignment: 0.1,
    );
  }

  void _exitReviewBackToQuestionPage() {
    setState(() => _reviewMode = false);
  }

  Future<void> _confirmAndSubmit() async {
    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit attempt?'),
        content: Text(
          'You have answered $_answeredCount of ${_allQuestions.length} questions. '
          'After submitting you cannot change your answers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (shouldSubmit == true) {
      await _finish();
    }
  }

  Future<void> _finish() async {
    final attemptId = _currentAttemptId;
    if (attemptId == null) {
      return;
    }

    setState(() => _busy = true);
    try {
      // Ensure all pages are cached so the submit payload is complete.
      await _cacheAllRemainingPages(attemptId);
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
      _disposeAnswerControllers();
      setState(() {
        _review = review;
        _answers.clear();
        _attemptData = null;
        _reviewMode = false;
        _questionsByPage.clear();
        _stopTimer();
        _message = 'Attempt submitted.';
      });
    } catch (error) {
      setState(() => _message = _friendlyError(error));
    } finally {
      setState(() => _busy = false);
    }
  }

  void _disposeAnswerControllers() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _textControllers.clear();
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

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
          value: _attemptsAllowed == 0 ? 'Unlimited' : '$_attemptsAllowed',
        ),
        if (_timeLeftSeconds != null)
          _TimerBanner(secondsLeft: _timeLeftSeconds!),
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
        if (!_reviewMode && _currentPageQuestions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            _currentPage == 0
                ? 'Current attempt'
                : 'Current attempt — Page ${_currentPage + 1}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ..._currentPageQuestions.map((question) {
            return QuizAttemptQuestionCard(
              key: ValueKey('quiz-q-${question.slot}-p$_currentPage'),
              question: question,
              onAnswerChanged: (value) {
                setState(() {
                  if (value == null || value.isEmpty) {
                    _answers.remove(question.slot);
                  } else {
                    _answers[question.slot] = value;
                  }
                });
                _scheduleAutosave();
              },
              initialValue: _answers[question.slot],
              controller: question.isShortAnswer
                  ? _textControllers[question.slot]
                  : null,
            );
          }),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_hasPrevPage)
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _goToPage(_currentPage - 1),
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text('Previous'),
                )
              else
                const SizedBox(width: 120),
              if (_hasNextPage)
                FilledButton.icon(
                  onPressed: _busy ? null : () => _goToPage(_currentPage + 1),
                  label: const Text('Next'),
                  icon: const Icon(Icons.chevron_right_rounded),
                  iconAlignment: IconAlignment.end,
                )
              else
                FilledButton.icon(
                  onPressed: _busy ? null : _enterReview,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Review Answers'),
                ),
            ],
          ),
        ],
        if (_reviewMode) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Review your answers',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '$_answeredCount / ${_allQuestions.length} answered',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'You can still edit any answer before submitting.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          // Jump-to-question strip (✓ answered / ⚠ unanswered).
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _allQuestions.length; i++)
                _QuestionChip(
                  number: i + 1,
                  answered: _isAnswered(_allQuestions[i]),
                  onTap: () => _jumpToQuestion(i),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ..._allQuestions.asMap().entries.map((entry) {
            final question = entry.value;
            return KeyedSubtree(
              key: _reviewQuestionKeys[entry.key],
              child: QuizAttemptQuestionCard(
                key: ValueKey('review-q-${question.slot}'),
                question: question,
                showAnswerStatus: true,
                onAnswerChanged: (value) {
                  setState(() {
                    if (value == null || value.isEmpty) {
                      _answers.remove(question.slot);
                    } else {
                      _answers[question.slot] = value;
                    }
                  });
                },
                initialValue: _answers[question.slot],
                controller: question.isShortAnswer
                    ? _textControllers[question.slot]
                    : null,
              ),
            );
          }),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _exitReviewBackToQuestionPage,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Edit'),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : _confirmAndSubmit,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Final Submit'),
              ),
            ],
          ),
        ],
        if (_review != null) ...[
          const SizedBox(height: 16),
          Text('Review', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Grade: ${_review!['grade'] ?? '-'}'),
                  const SizedBox(height: 8),
                  ..._renderMoodleReview(context),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _renderMoodleReview(BuildContext context) {
    final questions = List<dynamic>.from(_review?['questions'] ?? const []);
    if (questions.isEmpty) return const [];
    return questions.map((raw) {
      final q = Map<String, dynamic>.from(raw as Map);
      final html = q['html']?.toString() ?? '';
      final number = q['number']?.toString() ?? q['questionnumber']?.toString();
      final status = q['status']?.toString();
      final mark = q['mark']?.toString();
      return Card(
        margin: const EdgeInsets.only(top: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question ${number ?? ''}${mark != null ? ' — $mark' : ''}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (status != null)
                Text(
                  status,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              const SizedBox(height: 8),
              // Shared pipeline: LatexHtmlContent renders \(…\) everywhere.
              HtmlContent(html: html),
            ],
          ),
        ),
      );
    }).toList();
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

class _QuestionChip extends StatelessWidget {
  const _QuestionChip({
    required this.number,
    required this.answered,
    required this.onTap,
  });

  final int number;
  final bool answered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = answered ? const Color(0xFF2E7D4F) : const Color(0xFFB26A00);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              answered ? Icons.check_circle_outline : Icons.error_outline,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              '$number',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerBanner extends StatelessWidget {
  const _TimerBanner({required this.secondsLeft});

  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    final minutes = secondsLeft ~/ 60;
    final seconds = secondsLeft % 60;
    final label = '$minutes:${seconds.toString().padLeft(2, '0')}';
    final urgent = secondsLeft <= 60;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: urgent
          ? Colors.red.shade50
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: Icon(
          Icons.timer_outlined,
          color: urgent ? Colors.red.shade700 : null,
        ),
        title: Text('Time remaining: $label'),
        subtitle: const Text(
          'Your attempt is submitted automatically when the timer reaches zero.',
        ),
      ),
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

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}