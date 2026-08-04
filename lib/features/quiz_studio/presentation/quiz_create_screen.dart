import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../courses/data/courses_repository.dart';
import '../data/local_question_bank.dart';
import '../data/quiz_draft_store.dart';
import '../data/quiz_studio_repository.dart';
import '../models/quiz_draft.dart';
import 'quiz_draft_manager_sheet.dart';
import 'quiz_preview_screen.dart';
import 'quiz_question_card.dart';
import 'quiz_question_editor_screen.dart';
import 'quiz_settings_sheet.dart';

/// Quiz Studio — teacher canvas for authoring and publishing a quiz.
///
/// Phase 1B: local drafts, reorder/dup/undo. Publish remains create-only.
class QuizCreateScreen extends StatefulWidget {
  const QuizCreateScreen({
    super.key,
    required this.courseId,
    this.initialSectionId,
    this.initialDraft,
  });

  final int courseId;
  final int? initialSectionId;
  final QuizDraft? initialDraft;

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
  final _draftStore = QuizDraftStore();
  final _questionBank = LocalQuestionBank();
  final _titleController = TextEditingController();
  final _introController = TextEditingController();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  late QuizDraft _draft;
  Timer? _autosaveTimer;
  bool _dirty = false;
  String _questionFilter = '';

  List<_SectionOption> _sections = [];
  int? _sectionId;
  bool _loadingSections = true;
  bool _publishing = false;
  bool _showInstructions = false;
  String? _error;
  String? _autosaveLabel;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialDraft ??
        QuizDraft(
          courseId: widget.courseId,
          sectionId: widget.initialSectionId,
        );
    _draft.courseId ??= widget.courseId;
    _titleController.text = _draft.title;
    _introController.text = _draft.introText;
    _sectionId = _draft.sectionId ?? widget.initialSectionId;
    _titleController.addListener(_onDraftFieldChanged);
    _introController.addListener(_onDraftFieldChanged);
    _loadSections();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _titleController.removeListener(_onDraftFieldChanged);
    _introController.removeListener(_onDraftFieldChanged);
    _titleController.dispose();
    _introController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onDraftFieldChanged() {
    _dirty = true;
    _scheduleAutosave();
  }

  void _markDirty() {
    _dirty = true;
    _draft.touch();
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 800), _autosave);
  }

  Future<void> _autosave() async {
    if (!_dirty) return;
    _syncControllersIntoDraft();
    try {
      await _draftStore.save(_draft);
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _autosaveLabel = 'Draft saved';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _autosaveLabel = 'Autosave failed');
    }
  }

  void _syncControllersIntoDraft() {
    _draft.title = _titleController.text;
    _draft.introText = _introController.text;
    _draft.sectionId = _sectionId;
    _draft.courseId = widget.courseId;
  }

  Future<void> _saveNow() async {
    _syncControllersIntoDraft();
    await _draftStore.save(_draft);
    if (!mounted) return;
    setState(() {
      _dirty = false;
      _autosaveLabel = 'Draft saved';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draft saved on this device')),
    );
  }

  Future<void> _newDraft() async {
    final discard = await _confirmLeaveIfDirty();
    if (!discard || !mounted) return;
    setState(() {
      _draft = QuizDraft(
        courseId: widget.courseId,
        sectionId: _sectionId,
      );
      _titleController.text = '';
      _introController.text = '';
      _dirty = false;
      _autosaveLabel = null;
      _error = null;
    });
  }

  Future<void> _openDraftManager() async {
    final selected = await QuizDraftManagerSheet.show(
      context,
      courseId: widget.courseId,
      store: _draftStore,
      currentDraftId: _draft.id,
    );
    if (selected == null || !mounted) return;
    if (selected.id == _draft.id) return;
    final ok = await _confirmLeaveIfDirty();
    if (!ok || !mounted) return;
    setState(() {
      _draft = selected;
      _titleController.text = _draft.title;
      _introController.text = _draft.introText;
      if (_draft.sectionId != null) _sectionId = _draft.sectionId;
      _dirty = false;
      _autosaveLabel = 'Draft opened';
      _error = null;
    });
  }

  Future<bool> _confirmLeaveIfDirty() async {
    if (!_dirty) return true;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Save the current draft before continuing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == 'cancel' || result == null) return false;
    if (result == 'save') {
      await _saveNow();
    }
    return true;
  }

  void _openPreview() {
    _syncControllersIntoDraft();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizPreviewScreen(draft: _draft),
      ),
    );
  }

  Future<void> _exportJson() async {
    _syncControllersIntoDraft();
    final json = const JsonEncoder.withIndent('  ').convert(_draft.toDraftJson());
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Quiz JSON copied to clipboard')),
    );
  }

  Future<void> _importJson() async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import quiz JSON'),
        content: TextField(
          controller: controller,
          maxLines: 12,
          decoration: const InputDecoration(
            hintText: 'Paste Quiz Studio JSON…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (raw == null || raw.trim().isEmpty || !mounted) return;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final imported = QuizDraft.fromDraftJson(map);
      imported.courseId = widget.courseId;
      imported.sectionId = _sectionId;
      setState(() {
        _draft = imported;
        _titleController.text = _draft.title;
        _introController.text = _draft.introText;
        _error = null;
      });
      _markDirty();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiz imported')),
      );
    } catch (_) {
      _showError('Could not import JSON. Check the format and try again.');
    }
  }

  Future<void> _saveQuestionToBank(int index) async {
    await _questionBank.saveQuestion(_draft.questions[index]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to local question bank')),
    );
  }

  Future<void> _reuseFromBank() async {
    final items = await _questionBank.list();
    if (!mounted) return;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local question bank is empty')),
      );
      return;
    }
    final selected = await showModalBottomSheet<QuizQuestionDraft>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, i) {
          final q = items[i];
          final stem = q.stem.replaceAll(RegExp(r'<[^>]+>'), ' ').trim();
          return ListTile(
            title: Text(stem.isEmpty ? 'Untitled' : stem, maxLines: 2),
            subtitle: Text(
              q.type == QuizQuestionType.multipleChoice
                  ? 'Multiple choice'
                  : 'Short answer',
            ),
            onTap: () => Navigator.pop(ctx, q),
          );
        },
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _draft.questions.add(selected.duplicate());
    });
    _markDirty();
  }

  List<int> get _visibleQuestionIndexes {
    final q = _questionFilter.trim().toLowerCase();
    if (q.isEmpty) {
      return List.generate(_draft.questions.length, (i) => i);
    }
    final indexes = <int>[];
    for (var i = 0; i < _draft.questions.length; i++) {
      final stem = _draft.questions[i].stem.toLowerCase();
      if (stem.contains(q)) indexes.add(i);
    }
    return indexes;
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
    _markDirty();
  }

  void _duplicateQuestion(int index) {
    final copy = _draft.questions[index].duplicate();
    setState(() {
      _draft.questions.insert(index + 1, copy);
    });
    _markDirty();
  }

  void _deleteQuestion(int index) {
    final removed = _draft.questions[index];
    setState(() {
      _draft.questions.removeAt(index);
    });
    _markDirty();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Question removed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted) return;
            setState(() {
              final insertAt = index.clamp(0, _draft.questions.length);
              _draft.questions.insert(insertAt, removed);
            });
            _markDirty();
          },
        ),
      ),
    );
  }

  void _reorderQuestions(int oldIndex, int newIndex) {
    setState(() {
      final item = _draft.questions.removeAt(oldIndex);
      _draft.questions.insert(newIndex, item);
    });
    _markDirty();
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
      // Published quizzes live in Moodle; drop the local draft copy.
      await _draftStore.delete(_draft.id);
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
    final visible = _visibleQuestionIndexes;
    final filtering = _questionFilter.trim().isNotEmpty;

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
                _autosaveLabel ??
                    (count == 0
                        ? 'New quiz'
                        : '$count question${count == 1 ? '' : 's'}'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Preview',
              onPressed: _draft.questions.isEmpty ? null : _openPreview,
              icon: const Icon(Icons.visibility_outlined),
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) async {
                switch (value) {
                  case 'new':
                    await _newDraft();
                  case 'open':
                    await _openDraftManager();
                  case 'save':
                    await _saveNow();
                  case 'discard':
                    final messenger = ScaffoldMessenger.of(context);
                    await _draftStore.delete(_draft.id);
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Draft discarded from device'),
                      ),
                    );
                    await _newDraft();
                  case 'export':
                    await _exportJson();
                  case 'import':
                    await _importJson();
                  case 'bank':
                    await _reuseFromBank();
                  case 'settings':
                    final next = await QuizSettingsSheet.show(
                      context,
                      _draft.settings,
                    );
                    if (next != null && mounted) {
                      setState(() => _draft.settings = next);
                      _markDirty();
                    }
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'new', child: Text('New draft')),
                PopupMenuItem(value: 'open', child: Text('Open draft…')),
                PopupMenuItem(value: 'save', child: Text('Save draft')),
                PopupMenuItem(value: 'discard', child: Text('Discard draft')),
                PopupMenuDivider(),
                PopupMenuItem(value: 'settings', child: Text('Quiz settings…')),
                PopupMenuItem(value: 'export', child: Text('Export JSON')),
                PopupMenuItem(value: 'import', child: Text('Import JSON…')),
                PopupMenuItem(
                  value: 'bank',
                  child: Text('Reuse from local bank…'),
                ),
              ],
            ),
          ],
        ),
        body: _loadingSections
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
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
                                    () =>
                                        _showInstructions = !_showInstructions,
                                  );
                                },
                                sectionId: _sectionId,
                                sections: _sections,
                                onSectionChanged: (id) =>
                                    setState(() => _sectionId = id),
                              ),
                              const SizedBox(height: 28),
                              _QuestionsHeader(count: count),
                              if (count > 0) ...[
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _searchController,
                                  onChanged: (value) => setState(
                                    () => _questionFilter = value,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Search questions…',
                                    prefixIcon: const Icon(Icons.search, size: 20),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    isDense: true,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              if (count == 0)
                                _EmptyQuestions(
                                  onAddMcq: () => _openEditor(
                                    type: QuizQuestionType.multipleChoice,
                                  ),
                                  onAddShortAnswer: () => _openEditor(
                                    type: QuizQuestionType.shortAnswer,
                                  ),
                                ),
                            ]),
                          ),
                        ),
                        if (count > 0 && !filtering)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                            sliver: SliverReorderableList(
                              itemCount: count,
                              onReorderItem: _reorderQuestions,
                              itemBuilder: (context, index) {
                                final q = _draft.questions[index];
                                return Padding(
                                  key: ValueKey(q.id),
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: QuizQuestionCard(
                                    index: index,
                                    question: q,
                                    dragIndex: index,
                                    onTap: () => _openEditor(
                                      type: q.type,
                                      existing: q,
                                      replaceIndex: index,
                                    ),
                                    onDuplicate: () =>
                                        _duplicateQuestion(index),
                                    onDelete: () => _deleteQuestion(index),
                                    onSaveToBank: () =>
                                        _saveQuestionToBank(index),
                                  ),
                                );
                              },
                            ),
                          ),
                        if (count > 0 && filtering)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, i) {
                                  final index = visible[i];
                                  final q = _draft.questions[index];
                                  return Padding(
                                    key: ValueKey('filter-${q.id}'),
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: QuizQuestionCard(
                                      index: index,
                                      question: q,
                                      onTap: () => _openEditor(
                                        type: q.type,
                                        existing: q,
                                        replaceIndex: index,
                                      ),
                                      onDuplicate: () =>
                                          _duplicateQuestion(index),
                                      onDelete: () => _deleteQuestion(index),
                                      onSaveToBank: () =>
                                          _saveQuestionToBank(index),
                                    ),
                                  );
                                },
                                childCount: visible.length,
                              ),
                            ),
                          ),
                        if (count > 0)
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 8),
                          ),
                        if (count > 0)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                            sliver: SliverToBoxAdapter(
                              child: _AddQuestionRow(
                                onAddMcq: () => _openEditor(
                                  type: QuizQuestionType.multipleChoice,
                                ),
                                onAddShortAnswer: () => _openEditor(
                                  type: QuizQuestionType.shortAnswer,
                                ),
                              ),
                            ),
                          )
                        else
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 24),
                          ),
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
