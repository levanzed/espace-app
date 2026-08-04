/// In-memory quiz authoring model (Phase 1A).
///
/// Mirrors the FastAPI `QuizPublishPayload` shape so publish is a straight
/// serialization. Future AI / import features can populate the same structure.
library;

class RichTextDraft {
  RichTextDraft({this.format = 'html', this.text = ''});

  String format;
  String text;

  Map<String, dynamic> toJson() => {'format': format, 'text': text};
}

class McqChoiceDraft {
  McqChoiceDraft({required this.text, this.correct = false});

  String text;
  bool correct;

  Map<String, dynamic> toJson() => {
        'text': {'format': 'plain', 'text': text},
        'correct': correct,
      };
}

class ShortAnswerEntryDraft {
  ShortAnswerEntryDraft({required this.text, this.fraction = 1.0});

  String text;
  double fraction;

  Map<String, dynamic> toJson() => {'text': text, 'fraction': fraction};
}

enum QuizQuestionType { multipleChoice, shortAnswer }

class QuizQuestionDraft {
  QuizQuestionDraft({
    required this.id,
    required this.type,
    this.mark = 1.0,
    this.stem = '',
    List<McqChoiceDraft>? choices,
    List<ShortAnswerEntryDraft>? answers,
    this.caseSensitive = false,
  })  : choices = choices ?? [],
        answers = answers ?? [];

  final String id;
  QuizQuestionType type;
  double mark;
  String stem;
  List<McqChoiceDraft> choices;
  List<ShortAnswerEntryDraft> answers;
  bool caseSensitive;

  String get typeApi => type == QuizQuestionType.multipleChoice
      ? 'multiple_choice'
      : 'short_answer';

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
    return map;
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
    this.title = '',
    this.introText = '',
    List<QuizQuestionDraft>? questions,
  }) : questions = questions ?? [];

  String title;
  String introText;
  final List<QuizQuestionDraft> questions;

  Map<String, dynamic> toPublishRequest() {
    final intro = introText.trim();
    return {
      'payload': {
        'title': title.trim(),
        'intro': {
          'format': 'html',
          'text': intro.isEmpty
              ? ''
              : (intro.contains('<') ? intro : '<p>$intro</p>'),
        },
        'questions': questions.map((q) => q.toJson()).toList(),
      },
    };
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
        final correct = q.choices.where((c) => c.correct && c.text.trim().isNotEmpty);
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
