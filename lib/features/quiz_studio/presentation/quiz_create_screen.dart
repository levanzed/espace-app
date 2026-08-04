import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../courses/data/courses_repository.dart';
import '../data/quiz_studio_repository.dart';
import '../models/quiz_draft.dart';
import 'quiz_question_card.dart';
import 'quiz_question_editor_screen.dart';

/// Quiz Studio V1 — teacher canvas for authoring and publishing a quiz.
///
/// Layout grows toward AI Studio: details header → question cards → add actions
/// → sticky Publish. No dialogs; question edit is a dedicated screen.
class QuizCreateScreen extends StatefulWidget {
  const QuizCreateScreen({
    super.key,
    required this.courseId,
    this.initialSectionId,
  });

  final int courseId;
  final int? initialSectionId;

  @override
  State<QuizCreateScreen> createState() => _QuizCreateScreenState();
}

class _SectionOption {
  _SectionOption({required this.id, required this.label});

  final int id;
  final String label;
}

class _QuizCreateScreenState extends State<QuizCreateScreen> {
  static const Color _bg = Color(0xFFF7F8FA);

  final _courses = CoursesRepository();
  final _quizStudio = QuizStudioRepository();
  final _titleController = TextEditingController();
  final _introController = TextEditingController();
  final _scrollController = ScrollController();
  final _draft = QuizDraft();

  List<_SectionOption> _sections = [];
  int? _sectionId;
  bool _loadingSections = true;
  bool _publishing = false;
  bool _showInstructions = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sectionId = widget.initialSectionId;
    _loadSections();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _introController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail is Map) {
          final message = detail['message']?.toString().trim();
          if (message != null && message.isNotEmpty) return message;
        }
        if (detail is String && detail.trim().isNotEmpty) return detail.trim();
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Publishing took too long. Check the course in Moodle, then try again if needed.';
        case DioExceptionType.connectionError:
          return 'Could not reach the ESPACE server. Check your connection and try again.';
        default:
          break;
      }
      final code = error.response?.statusCode;
      if (code == 401 || code == 403) {
        return 'You do not have permission to publish a quiz in this course.';
      }
      if (code == 404) {
        return 'Publish is unavailable. The API may need an update.';
      }
    }
    return 'Could not publish the quiz. Please try again.';
  }

  void _showError(String message) {
    setState(() => _error = message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _loadSections() async {
    try {
      final contents = await _courses.getCourseContents(widget.courseId);
      final options = <_SectionOption>[];
      for (final section in contents) {
        final map = Map<String, dynamic>.from(section as Map);
        final id = _asInt(map['id']) ?? 0;
        if (id <= 0) continue;
        final num = _asInt(map['section']) ?? 0;
        final name = map['name']?.toString().trim() ?? '';
        final label = name.isEmpty
            ? (num == 0 ? 'General' : 'Section $num')
            : name;
        options.add(_SectionOption(id: id, label: label));
      }
      if (!mounted) return;
      setState(() {
        _sections = options;
        _loadingSections = false;
        final selectedStillValid =
            _sectionId != null && options.any((o) => o.id == _sectionId);
        if (!selectedStillValid) {
          _sectionId = options.isNotEmpty ? options.first.id : null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingSections = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _openEditor({
    required QuizQuestionType type,
    QuizQuestionDraft? existing,
    int? replaceIndex,
  }) async {
    final result = await Navigator.of(context).push<QuizQuestionDraft>(
      MaterialPageRoute(
        builder: (_) => QuizQuestionEditorScreen(
          type: type,
          existing: existing,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (replaceIndex != null) {
        _draft.questions[replaceIndex] = result;
      } else {
        _draft.questions.add(result);
      }
      _error = null;
    });
  }

  Future<void> _confirmDelete(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove question?'),
        content: const Text('This question will be removed from the draft.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _draft.questions.removeAt(index));
    }
  }

  Future<void> _publish() async {
    if (_publishing) return;

    _draft.title = _titleController.text;
    _draft.introText = _introController.text;

    final validation = _draft.validateForPublish();
    if (validation != null) {
      _showError(validation);
      return;
    }
    if (_sectionId == null) {
      _showError('Choose a course section.');
      return;
    }

    setState(() {
      _publishing = true;
      _error = null;
    });

    try {
      await _quizStudio.publishQuiz(
        courseId: widget.courseId,
        sectionId: _sectionId!,
        body: _draft.toPublishRequest(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      // Draft stays intact; only the error banner updates.
      _showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _draft.questions.length;

    return PopScope(
      canPop: !_publishing,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Column(
            children: [
              const Text('Quiz Studio'),
              Text(
                count == 0
                    ? 'New quiz'
                    : '$count question${count == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        body: _loadingSections
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                      children: [
                        if (_error != null) ...[
                          _ErrorBanner(message: _error!),
                          const SizedBox(height: 16),
                        ],
                        _DetailsCard(
                          titleController: _titleController,
                          introController: _introController,
                          showInstructions: _showInstructions,
                          onToggleInstructions: () {
                            setState(
                              () => _showInstructions = !_showInstructions,
                            );
                          },
                          sectionId: _sectionId,
                          sections: _sections,
                          onSectionChanged: (id) =>
                              setState(() => _sectionId = id),
                        ),
                        const SizedBox(height: 28),
                        _QuestionsHeader(count: count),
                        const SizedBox(height: 14),
                        if (count == 0)
                          _EmptyQuestions(
                            onAddMcq: () => _openEditor(
                              type: QuizQuestionType.multipleChoice,
                            ),
                            onAddShortAnswer: () => _openEditor(
                              type: QuizQuestionType.shortAnswer,
                            ),
                          )
                        else ...[
                          ...List.generate(count, (index) {
                            final q = _draft.questions[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: QuizQuestionCard(
                                index: index,
                                question: q,
                                onTap: () => _openEditor(
                                  type: q.type,
                                  existing: q,
                                  replaceIndex: index,
                                ),
                                onDelete: () => _confirmDelete(index),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          _AddQuestionRow(
                            onAddMcq: () => _openEditor(
                              type: QuizQuestionType.multipleChoice,
                            ),
                            onAddShortAnswer: () => _openEditor(
                              type: QuizQuestionType.shortAnswer,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _PublishBar(
                    publishing: _publishing,
                    enabled: !_publishing,
                    onPublish: _publish,
                  ),
                ],
              ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.titleController,
    required this.introController,
    required this.showInstructions,
    required this.onToggleInstructions,
    required this.sectionId,
    required this.sections,
    required this.onSectionChanged,
  });

  final TextEditingController titleController;
  final TextEditingController introController;
  final bool showInstructions;
  final VoidCallback onToggleInstructions;
  final int? sectionId;
  final List<_SectionOption> sections;
  final ValueChanged<int?> onSectionChanged;

  static const Color _accent = Color(0xFF5B4B8A);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0.4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
              decoration: const InputDecoration(
                hintText: 'Quiz title',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              // Controlled: section may be set after contents load.
              // ignore: deprecated_member_use
              value: sectionId,
              isExpanded: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.folder_outlined, size: 20),
                labelText: 'Section',
                filled: true,
                fillColor: const Color(0xFFF7F8FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: sections
                  .map(
                    (s) => DropdownMenuItem(value: s.id, child: Text(s.label)),
                  )
                  .toList(),
              onChanged: onSectionChanged,
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: onToggleInstructions,
              style: TextButton.styleFrom(
                foregroundColor: _accent,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    showInstructions
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    showInstructions || introController.text.trim().isNotEmpty
                        ? 'Instructions'
                        : 'Add instructions (optional)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (showInstructions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: introController,
                  maxLines: 4,
                  minLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Shown to students before they start…',
                    filled: true,
                    fillColor: const Color(0xFFF7F8FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuestionsHeader extends StatelessWidget {
  const _QuestionsHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'QUESTIONS',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF5B4B8A).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5B4B8A),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyQuestions extends StatelessWidget {
  const _EmptyQuestions({
    required this.onAddMcq,
    required this.onAddShortAnswer,
  });

  final VoidCallback onAddMcq;
  final VoidCallback onAddShortAnswer;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF5B4B8A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.quiz_outlined,
                size: 32,
                color: Color(0xFF5B4B8A),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Start with a question',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add multiple choice or short answer questions,\nthen publish when you are ready.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            _AddQuestionRow(
              onAddMcq: onAddMcq,
              onAddShortAnswer: onAddShortAnswer,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddQuestionRow extends StatelessWidget {
  const _AddQuestionRow({
    required this.onAddMcq,
    required this.onAddShortAnswer,
  });

  final VoidCallback onAddMcq;
  final VoidCallback onAddShortAnswer;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AddTile(
            icon: Icons.checklist_rounded,
            label: 'Multiple choice',
            onTap: onAddMcq,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AddTile(
            icon: Icons.short_text_rounded,
            label: 'Short answer',
            onTap: onAddShortAnswer,
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF5B4B8A)),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublishBar extends StatelessWidget {
  const _PublishBar({
    required this.publishing,
    required this.enabled,
    required this.onPublish,
  });

  final bool publishing;
  final bool enabled;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: enabled ? onPublish : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF5B4B8A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: publishing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Publishing…',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Publish to Moodle',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                'Students can attempt it as soon as it appears in the course.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade800, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.red.shade900, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
