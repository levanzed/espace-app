import 'package:flutter/material.dart';

import '../models/quiz_draft.dart';
import '../../activity/renderers/widgets/html_content.dart';

/// Read-only teacher preview of the current [QuizDraft] (local only).
class QuizPreviewScreen extends StatelessWidget {
  const QuizPreviewScreen({super.key, required this.draft});

  final QuizDraft draft;

  @override
  Widget build(BuildContext context) {
    final title = draft.title.trim().isEmpty ? 'Untitled quiz' : draft.title.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher preview'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (draft.introText.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            HtmlContent(
              html: draft.introText.contains('<')
                  ? draft.introText
                  : '<p>${draft.introText}</p>',
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Preview only — answers are not submitted.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ...List.generate(draft.questions.length, (index) {
            final q = draft.questions[index];
            return _PreviewQuestion(index: index + 1, question: q);
          }),
        ],
      ),
    );
  }
}

class _PreviewQuestion extends StatelessWidget {
  const _PreviewQuestion({required this.index, required this.question});

  final int index;
  final QuizQuestionDraft question;

  @override
  Widget build(BuildContext context) {
    final stemHtml = question.stem.contains('<')
        ? question.stem
        : '<p>${question.stem}</p>';
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question $index · ${question.mark} pt',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            HtmlContent(html: stemHtml),
            const SizedBox(height: 12),
            if (question.type == QuizQuestionType.multipleChoice)
              ...question.choices.where((c) => c.text.trim().isNotEmpty).map(
                    (c) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        c.correct
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: c.correct
                            ? const Color(0xFF2E7D4F)
                            : Colors.grey,
                      ),
                      title: Text(c.text),
                    ),
                  )
            else
              const TextField(
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Answer',
                  border: OutlineInputBorder(),
                  hintText: 'Student types here',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
