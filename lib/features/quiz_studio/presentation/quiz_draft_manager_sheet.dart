import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/quiz_draft_store.dart';
import '../models/quiz_draft.dart';

/// Lists local drafts for Open / Discard in Quiz Studio.
class QuizDraftManagerSheet extends StatefulWidget {
  const QuizDraftManagerSheet({
    super.key,
    required this.courseId,
    required this.store,
    required this.currentDraftId,
  });

  final int courseId;
  final QuizDraftStore store;
  final String currentDraftId;

  static Future<QuizDraft?> show(
    BuildContext context, {
    required int courseId,
    required QuizDraftStore store,
    required String currentDraftId,
  }) {
    return showModalBottomSheet<QuizDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => QuizDraftManagerSheet(
        courseId: courseId,
        store: store,
        currentDraftId: currentDraftId,
      ),
    );
  }

  @override
  State<QuizDraftManagerSheet> createState() => _QuizDraftManagerSheetState();
}

class _QuizDraftManagerSheetState extends State<QuizDraftManagerSheet> {
  late Future<List<QuizDraft>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.store.listDrafts(courseId: widget.courseId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.store.listDrafts(courseId: widget.courseId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.7;
    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Drafts',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<QuizDraft>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final drafts = snapshot.data ?? const [];
                if (drafts.isEmpty) {
                  return Center(
                    child: Text(
                      'No saved drafts yet.\nAutosave keeps your current quiz locally.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }
                final fmt = DateFormat.MMMd().add_jm();
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: drafts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final d = drafts[index];
                    final isCurrent = d.id == widget.currentDraftId;
                    final title =
                        d.title.trim().isEmpty ? 'Untitled quiz' : d.title.trim();
                    return Material(
                      color: isCurrent
                          ? const Color(0xFF5B4B8A).withValues(alpha: 0.08)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        title: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${d.questions.length} question${d.questions.length == 1 ? '' : 's'}'
                          ' · ${fmt.format(d.updatedAt.toLocal())}'
                          '${isCurrent ? ' · current' : ''}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Discard',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Discard draft?'),
                                content: Text(
                                  isCurrent
                                      ? 'This removes the saved copy. Your open editor is unchanged until you leave.'
                                      : 'Delete “$title” from this device?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Discard'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await widget.store.delete(d.id);
                              await _reload();
                            }
                          },
                        ),
                        onTap: isCurrent
                            ? () => Navigator.pop(context)
                            : () => Navigator.pop(context, d),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
