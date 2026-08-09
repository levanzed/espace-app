import 'package:flutter/material.dart';

import '../models/quiz_draft.dart';

/// Scannable question card for the Quiz Studio canvas.
class QuizQuestionCard extends StatelessWidget {
  const QuizQuestionCard({
    super.key,
    required this.index,
    required this.question,
    required this.onTap,
    required this.onDelete,
    this.onDuplicate,
    this.onSaveToBank,
    this.dragIndex,
  });

  final int index;
  final QuizQuestionDraft question;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onDuplicate;
  final VoidCallback? onSaveToBank;

  /// When set, shows a [ReorderableDragStartListener] handle.
  final int? dragIndex;

  static const Color _accent = Color(0xFF5B4B8A);

  @override
  Widget build(BuildContext context) {
    final isMcq = question.type == QuizQuestionType.multipleChoice;
    final stem = question.stem.trim();
    final stemPreview = stem.isEmpty
        ? 'Untitled question'
        : stem.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0.4,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dragIndex != null)
                    ReorderableDragStartListener(
                      index: dragIndex!,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, right: 4),
                        child: Icon(
                          Icons.drag_handle_rounded,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 8),
                  _IndexBadge(index: index + 1),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _TypeChip(
                              label: isMcq ? 'Multiple choice' : 'Short answer',
                              icon: isMcq
                                  ? Icons.checklist_rounded
                                  : Icons.short_text_rounded,
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_formatMark(question.mark)} pt',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          stemPreview,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                            color: stem.isEmpty
                                ? Colors.grey.shade400
                                : const Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onSaveToBank != null)
                    IconButton(
                      tooltip: 'Save to local bank',
                      onPressed: onSaveToBank,
                      icon: Icon(
                        Icons.bookmark_add_outlined,
                        size: 20,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  if (onDuplicate != null)
                    IconButton(
                      tooltip: 'Duplicate',
                      onPressed: onDuplicate,
                      icon: Icon(
                        Icons.copy_rounded,
                        size: 20,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              if (isMcq && question.choices.any((c) => c.text.trim().isNotEmpty)) ...[
                const SizedBox(height: 14),
                ...question.choices
                    .where((c) => c.text.trim().isNotEmpty)
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(left: 52, bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c.correct
                                    ? const Color(0xFF2E7D4F).withValues(alpha: 0.12)
                                    : Colors.grey.shade100,
                              ),
                              child: Icon(
                                c.correct
                                    ? Icons.check_rounded
                                    : Icons.circle_outlined,
                                size: 14,
                                color: c.correct
                                    ? const Color(0xFF2E7D4F)
                                    : Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _stripHtml(c.text),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.3,
                                  color: c.correct
                                      ? const Color(0xFF1A1A1A)
                                      : Colors.grey.shade700,
                                  fontWeight: c.correct
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
              if (!isMcq &&
                  question.answers.any((a) => a.text.trim().isNotEmpty)) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: question.answers
                        .where((a) => a.text.trim().isNotEmpty)
                        .map(
                          (a) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _stripHtml(a.text),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _accent,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatMark(double mark) {
    if (mark == mark.roundToDouble()) return mark.toInt().toString();
    return mark.toString();
  }

  /// Strip HTML tags/entities so the card preview shows clean text (choices &
  /// answers are Quill rich-text HTML — e.g. `<p>…</p>`, `&`).
  static String _stripHtml(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _IndexBadge extends StatelessWidget {
  const _IndexBadge({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: QuizQuestionCard._accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$index',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: QuizQuestionCard._accent,
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
