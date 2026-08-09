/// In-memory quiz authoring model (Phase 1A + 1B).
///
/// Canonical editing model for Quiz Studio. [toPublishRequest] maps to the
/// stable create-only FastAPI payload. Local JSON ([toJson]/[fromJson]) is for
/// drafts, import/export, and the local question bank — not Moodle round-trip.
library;

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String newQuizDraftId() => _uuid.v4();

class RichTextDraft {
  RichTextDraft({this.format = 'html', this.text = ''});

  String format;
  String text;

  Map<String, dynamic> toJson() => {'format': format, 'text': text};

  factory RichTextDraft.fromJson(Map<String, dynamic> json) => RichTextDraft(
        format: json['format']?.toString() ?? 'html',
        text: json['text']?.toString() ?? '',
      );
}

class McqChoiceDraft {
  McqChoiceDraft({required this.text, this.correct = false});

  String text;
  bool correct;

  Map<String, dynamic> toJson() => {
        'text': {'format': 'plain', 'text': text},
        'correct': correct,
      };

  /// Local draft / bank serialization (flat text).
  Map<String, dynamic> toDraftJson() => {
        'text': text,
        'correct': correct,
      };

  factory McqChoiceDraft.fromDraftJson(Map<String, dynamic> json) {
    final textField = json['text'];
    final text = textField is Map
        ? (textField['text']?.toString() ?? '')
        : (textField?.toString() ?? '');
    return McqChoiceDraft(
      text: text,
      correct: json['correct'] == true || json['correct'] == 1,
    );
  }
}

class ShortAnswerEntryDraft {
  ShortAnswerEntryDraft({required this.text, this.fraction = 1.0});

  String text;
  double fraction;

  Map<String, dynamic> toJson() => {'text': text, 'fraction': fraction};

  factory ShortAnswerEntryDraft.fromJson(Map<String, dynamic> json) =>
      ShortAnswerEntryDraft(
        text: json['text']?.toString() ?? '',
        fraction: (json['fraction'] as num?)?.toDouble() ?? 1.0,
      );
}

enum QuizQuestionType { multipleChoice, shortAnswer }

/// Quiz settings for Studio authoring.
///
/// Sent on publish via `payload.settings` (local_espace 1.1.15+).
class QuizSettingsDraft {
  QuizSettingsDraft({
    this.timeLimitSeconds = 0,
    this.attemptsAllowed = 0,
    this.shuffleQuestions = false,
    this.shuffleAnswers = true,
    this.gradeToPass = 0,
    this.timeOpen,
    this.timeClose,
    this.questionsPerPage = 0,
  });

  /// 0 = no limit.
  int timeLimitSeconds;

  /// 0 = unlimited.
  int attemptsAllowed;
  bool shuffleQuestions;
  bool shuffleAnswers;
  double gradeToPass;
  DateTime? timeOpen;
  DateTime? timeClose;

  /// 0 = all questions on one page; otherwise questions per page.
  int questionsPerPage;

  Map<String, dynamic> toJson() => {
        'timeLimitSeconds': timeLimitSeconds,
        'attemptsAllowed': attemptsAllowed,
        'shuffleQuestions': shuffleQuestions,
        'shuffleAnswers': shuffleAnswers,
        'gradeToPass': gradeToPass,
        'timeOpen': timeOpen?.toIso8601String(),
        'timeClose': timeClose?.toIso8601String(),
        'questionsPerPage': questionsPerPage,
      };

  factory QuizSettingsDraft.fromJson(Map<String, dynamic>? json) {
    if (json == null) return QuizSettingsDraft();
    return QuizSettingsDraft(
      timeLimitSeconds: (json['timeLimitSeconds'] as num?)?.toInt() ?? 0,
      attemptsAllowed: (json['attemptsAllowed'] as num?)?.toInt() ?? 0,
      shuffleQuestions: json['shuffleQuestions'] == true,
      shuffleAnswers: json['shuffleAnswers'] != false,
      gradeToPass: (json['gradeToPass'] as num?)?.toDouble() ?? 0,
      timeOpen: _parseDate(json['timeOpen']),
      timeClose: _parseDate(json['timeClose']),
      questionsPerPage: (json['questionsPerPage'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class QuizQuestionDraft {
  QuizQuestionDraft({
    String? id,
    required this.type,
    this.mark = 1.0,
    this.stem = '',
    List<McqChoiceDraft>? choices,
    List<ShortAnswerEntryDraft>? answers,
    this.caseSensitive = false,
    this.generalFeedback = '',
    this.correctFeedback = '',
    this.incorrectFeedback = '',
    this.partiallyCorrectFeedback = '',
  })  : id = id ?? newQuizDraftId(),
        choices = choices ?? [],
        answers = answers ?? [];

  final String id;
  QuizQuestionType type;
  double mark;
  String stem;
  List<McqChoiceDraft> choices;
  List<ShortAnswerEntryDraft> answers;
  bool caseSensitive;

  /// Rich-text (HTML) feedback shown after grading. LaTeX `\( … \)` renders
  /// via the shared LatexHtmlContent pipeline on every surface.
  String generalFeedback;
  String correctFeedback;
  String incorrectFeedback;
  String partiallyCorrectFeedback;

  String get typeApi => type == QuizQuestionType.multipleChoice
      ? 'multiple_choice'
      : 'short_answer';

  QuizQuestionDraft duplicate() {
    return QuizQuestionDraft(
      type: type,
      mark: mark,
      stem: stem,
      choices: choices
          .map((c) => McqChoiceDraft(text: c.text, correct: c.correct))
          .toList(),
      answers: answers
          .map((a) => ShortAnswerEntryDraft(text: a.text, fraction: a.fraction))
          .toList(),
      caseSensitive: caseSensitive,
      generalFeedback: generalFeedback,
      correctFeedback: correctFeedback,
      incorrectFeedback: incorrectFeedback,
      partiallyCorrectFeedback: partiallyCorrectFeedback,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'type': typeApi,
      'mark': mark,
      'stem': {
        'format': 'html',
        'text': _stemAsHtml(stem),
      },
    };
    if (type == QuizQuestionType.multipleChoice) {
      map['choices'] = choices.map((c) => c.toJson()).toList();
    } else {
      map['answers'] = answers.map((a) => a.toJson()).toList();
      map['case_sensitive'] = caseSensitive;
    }
    // Feedback is additive — only include non-empty fields so the publish
    // payload stays backward compatible with older local_espace versions.
    if (generalFeedback.trim().isNotEmpty) {
      map['general_feedback'] = {'format': 'html', 'text': generalFeedback};
    }
    if (correctFeedback.trim().isNotEmpty) {
      map['correct_feedback'] = {'format': 'html', 'text': correctFeedback};
    }
    if (incorrectFeedback.trim().isNotEmpty) {
      map['incorrect_feedback'] = {'format': 'html', 'text': incorrectFeedback};
    }
    if (partiallyCorrectFeedback.trim().isNotEmpty) {
      map['partially_correct_feedback'] = {
        'format': 'html',
        'text': partiallyCorrectFeedback,
      };
    }
    return map;
  }

  Map<String, dynamic> toDraftJson() => {
        'id': id,
        'type': typeApi,
        'mark': mark,
        'stem': stem,
        'choices': choices.map((c) => c.toDraftJson()).toList(),
        'answers': answers.map((a) => a.toJson()).toList(),
        'caseSensitive': caseSensitive,
        'generalFeedback': generalFeedback,
        'correctFeedback': correctFeedback,
        'incorrectFeedback': incorrectFeedback,
        'partiallyCorrectFeedback': partiallyCorrectFeedback,
      };

  factory QuizQuestionDraft.fromDraftJson(Map<String, dynamic> json) {
    final typeRaw = json['type']?.toString() ?? 'multiple_choice';
    final type = typeRaw == 'short_answer'
        ? QuizQuestionType.shortAnswer
        : QuizQuestionType.multipleChoice;
    final stemField = json['stem'];
    final stem = stemField is Map
        ? (stemField['text']?.toString() ?? '')
        : (stemField?.toString() ?? '');

    return QuizQuestionDraft(
      id: json['id']?.toString(),
      type: type,
      mark: (json['mark'] as num?)?.toDouble() ?? 1.0,
      stem: stem,
      choices: (json['choices'] as List? ?? [])
          .map((c) => McqChoiceDraft.fromDraftJson(
                Map<String, dynamic>.from(c as Map),
              ))
          .toList(),
      answers: (json['answers'] as List? ?? [])
          .map((a) => ShortAnswerEntryDraft.fromJson(
                Map<String, dynamic>.from(a as Map),
              ))
          .toList(),
      caseSensitive:
          json['caseSensitive'] == true || json['case_sensitive'] == true,
      generalFeedback: json['generalFeedback']?.toString() ?? '',
      correctFeedback: json['correctFeedback']?.toString() ?? '',
      incorrectFeedback: json['incorrectFeedback']?.toString() ?? '',
      partiallyCorrectFeedback:
          json['partiallyCorrectFeedback']?.toString() ?? '',
    );
  }

  static String _stemAsHtml(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (t.contains('<')) return t;
    return '<p>$t</p>';
  }
}

class QuizDraft {
  QuizDraft({
    String? id,
    this.title = '',
    this.introText = '',
    List<QuizQuestionDraft>? questions,
    QuizSettingsDraft? settings,
    this.courseId,
    this.sectionId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? newQuizDraftId(),
        questions = questions ?? [],
        settings = settings ?? QuizSettingsDraft(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  String introText;
  final List<QuizQuestionDraft> questions;
  QuizSettingsDraft settings;

  /// Optional context when saved from a course.
  int? courseId;
  int? sectionId;
  DateTime createdAt;
  DateTime updatedAt;

  void touch() {
    updatedAt = DateTime.now();
  }

  Map<String, dynamic> toPublishRequest() {
    final intro = introText.trim();
    final payload = <String, dynamic>{
      'title': title.trim(),
      'intro': {
        'format': 'html',
        'text': intro.isEmpty
            ? ''
            : (intro.contains('<') ? intro : '<p>$intro</p>'),
      },
      'questions': questions.map((q) => q.toJson()).toList(),
    };
    final settingsJson = _settingsToPublishJson();
    if (settingsJson != null) {
      payload['settings'] = settingsJson;
    }
    return {'payload': payload};
  }

  /// Map local [QuizSettingsDraft] to the publish API settings object.
  ///
  /// Returns null when all values are at Moodle defaults, keeping the payload
  /// additive and backward compatible (no `settings` key ⇒ old behavior).
  Map<String, dynamic>? _settingsToPublishJson() {
    final s = settings;
    final allDefaults = s.timeLimitSeconds <= 0 &&
        s.attemptsAllowed <= 0 &&
        !s.shuffleQuestions &&
        s.shuffleAnswers &&
        s.gradeToPass <= 0 &&
        s.timeOpen == null &&
        s.timeClose == null &&
        s.questionsPerPage <= 0;
    if (allDefaults) return null;

    return {
      'timelimit': s.timeLimitSeconds,
      'attempts': s.attemptsAllowed,
      'shufflequestions': s.shuffleQuestions,
      'shuffleanswers': s.shuffleAnswers,
      'gradepass': s.gradeToPass,
      'timeopen': s.timeOpen != null
          ? s.timeOpen!.millisecondsSinceEpoch ~/ 1000
          : 0,
      'timeclose': s.timeClose != null
          ? s.timeClose!.millisecondsSinceEpoch ~/ 1000
          : 0,
      'questionsperpage': s.questionsPerPage,
    };
  }

  Map<String, dynamic> toDraftJson() => {
        'schemaVersion': 1,
        'id': id,
        'title': title,
        'introText': introText,
        'questions': questions.map((q) => q.toDraftJson()).toList(),
        'settings': settings.toJson(),
        'courseId': courseId,
        'sectionId': sectionId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory QuizDraft.fromDraftJson(Map<String, dynamic> json) {
    return QuizDraft(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '',
      introText: json['introText']?.toString() ?? '',
      questions: (json['questions'] as List? ?? [])
          .map((q) => QuizQuestionDraft.fromDraftJson(
                Map<String, dynamic>.from(q as Map),
              ))
          .toList(),
      settings: QuizSettingsDraft.fromJson(
        json['settings'] is Map
            ? Map<String, dynamic>.from(json['settings'] as Map)
            : null,
      ),
      courseId: (json['courseId'] as num?)?.toInt(),
      sectionId: (json['sectionId'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String? validateForPublish() {
    if (title.trim().isEmpty) return 'Quiz title is required.';
    if (questions.isEmpty) return 'Add at least one question.';
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final n = i + 1;
      if (q.stem.trim().isEmpty) return 'Question $n needs a stem.';
      if (q.mark <= 0) return 'Question $n mark must be greater than zero.';
      if (q.type == QuizQuestionType.multipleChoice) {
        final nonEmpty = q.choices.where((c) => c.text.trim().isNotEmpty);
        if (nonEmpty.length < 2) {
          return 'Question $n needs at least two choices.';
        }
        final correct =
            q.choices.where((c) => c.correct && c.text.trim().isNotEmpty);
        if (correct.length != 1) {
          return 'Question $n must have exactly one correct choice.';
        }
      } else {
        final nonEmpty = q.answers.where((a) => a.text.trim().isNotEmpty);
        if (nonEmpty.isEmpty) {
          return 'Question $n needs at least one accepted answer.';
        }
      }
    }
    return null;
  }
}
