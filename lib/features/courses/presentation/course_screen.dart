import 'package:flutter/material.dart';

import '../../activity/authoring/activity_picker.dart';
import '../../activity/authoring/assignment_editor_screen.dart';
import '../../activity/presentation/activity_screen.dart';
import '../../activity/renderers/widgets/html_content.dart';
import '../../quiz_studio/presentation/quiz_create_screen.dart';
import '../data/courses_repository.dart';

class CourseScreen extends StatefulWidget {
  final int courseId;

  const CourseScreen({super.key, required this.courseId});

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  final CoursesRepository _repository = CoursesRepository();

  late Future<List<dynamic>> _future;
  bool _teacherMode = false;

  @override
  void initState() {
    super.initState();
    _reload();
    _loadAdmin();
  }

  void _reload() {
    _future = _repository.getCourseContents(widget.courseId);
  }

  Future<void> _loadAdmin() async {
    try {
      final admin = await _repository.getAdministration(widget.courseId);
      if (!mounted) return;
      setState(() {
        _teacherMode = _detectTeacher(admin);
      });
    } catch (_) {
      // Students may not have administration options enabled.
    }
  }

  bool _detectTeacher(Map<String, dynamic> admin) {
    final administration = admin['administration'];
    if (administration is Map) {
      final courses = administration['courses'] ?? administration['options'];
      if (courses is List && courses.isNotEmpty) {
        return true;
      }
    }
    return administration != null;
  }

  IconData _icon(String type) {
    switch (type) {
      case 'assign':
        return Icons.assignment_rounded;
      case 'quiz':
        return Icons.quiz_rounded;
      case 'forum':
        return Icons.forum_rounded;
      case 'resource':
        return Icons.picture_as_pdf_rounded;
      case 'folder':
        return Icons.folder_rounded;
      case 'url':
        return Icons.language_rounded;
      case 'page':
        return Icons.article_rounded;
      case 'book':
        return Icons.menu_book_rounded;
      case 'label':
        return Icons.label_outline_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'assign':
        return Colors.orange;
      case 'quiz':
        return Colors.deepPurple;
      case 'forum':
        return Colors.green;
      case 'resource':
        return Colors.red;
      case 'folder':
        return Colors.amber.shade800;
      case 'url':
        return Colors.cyan;
      case 'page':
        return Colors.blue;
      case 'book':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  Future<void> _addSection() async {
    final nameController = TextEditingController();
    final summaryController = TextEditingController();

    Future<void> submit(BuildContext dialogContext) async {
      final name = nameController.text.trim();
      final summary = summaryController.text.trim();
      try {
        await _repository.sectionAction(
          widget.courseId,
          action: 'section_add',
          name: name.isEmpty ? null : name,
          summary: summary.isEmpty ? null : summary,
        );
        if (dialogContext.mounted) {
          Navigator.pop(dialogContext, true);
        }
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add section'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Section name (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: summaryController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => submit(dialogContext),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      summaryController.dispose();
    });

    if (created == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _sectionVisibility(int sectionId, {required bool hide}) async {
    await _repository.sectionAction(
      widget.courseId,
      action: hide ? 'section_hide' : 'section_show',
      sectionIds: [sectionId],
    );
    setState(_reload);
  }

  Future<void> _editSection(
    int sectionId, {
    required String currentName,
    required String currentSummary,
  }) async {
    final nameController = TextEditingController(text: currentName);
    final summaryController = TextEditingController(text: currentSummary);

    Future<void> submit(BuildContext dialogContext) async {
      final name = nameController.text.trim();
      final summary = summaryController.text;
      try {
        await _repository.renameSection(
          widget.courseId,
          sectionId,
          name: name,
          summary: summary,
        );
        if (dialogContext.mounted) {
          Navigator.pop(dialogContext, true);
        }
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit section'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Section name',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: summaryController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => submit(dialogContext),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      summaryController.dispose();
    });

    if (saved == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _moveSection(int sectionId, int targetSectionId) async {
    try {
      await _repository.sectionAction(
        widget.courseId,
        action: 'section_move',
        sectionIds: [sectionId],
        targetSectionId: targetSectionId,
      );
      if (!mounted) return;
      setState(_reload);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _deleteSection(int sectionId, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete section'),
          content: Text('Delete "$label"? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    try {
      await _repository.sectionAction(
        widget.courseId,
        action: 'section_delete',
        sectionIds: [sectionId],
      );
      if (!mounted) return;
      setState(_reload);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _moduleAction(String action, int cmid) async {
    try {
      await _repository.moduleAction(
        widget.courseId,
        action: action,
        cmid: cmid,
      );
      setState(_reload);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _openQuizCreator({int? sectionId}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuizCreateScreen(
          courseId: widget.courseId,
          initialSectionId: sectionId,
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiz published to Moodle.')),
      );
    }
  }

  Future<void> _openAssignmentEditor({
    required int sectionId,
    int? cmid,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AssignmentEditorScreen(
          courseId: widget.courseId,
          sectionId: sectionId,
          cmid: cmid,
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cmid == null ? 'Assignment created.' : 'Assignment updated.',
          ),
        ),
      );
    }
  }

  Future<void> _showAddActivityPicker(int sectionId) async {
    final entry = await showActivityPicker(context);
    if (entry == null || !mounted) return;
    if (entry.modname == 'assign') {
      await _openAssignmentEditor(sectionId: sectionId);
      return;
    }
    if (entry.modname == 'quiz') {
      await _openQuizCreator(sectionId: sectionId);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${entry.label} is coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F8FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          if (_teacherMode)
            IconButton(
              tooltip: 'Create quiz',
              onPressed: () => _openQuizCreator(),
              icon: const Icon(Icons.quiz_outlined),
            ),
          if (_teacherMode)
            IconButton(
              tooltip: 'Add section',
              onPressed: _addSection,
              icon: const Icon(Icons.playlist_add_rounded),
            ),
          IconButton(
            tooltip: 'Grades',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _CourseGradesScreen(
                  courseId: widget.courseId,
                  repository: _repository,
                ),
              ),
            ),
            icon: const Icon(Icons.grade_outlined),
          ),
          IconButton(
            tooltip: 'Participants',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _ParticipantsScreen(
                  courseId: widget.courseId,
                  repository: _repository,
                ),
              ),
            ),
            icon: const Icon(Icons.people_outline),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final sections = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: sections.length,
            itemBuilder: (context, index) {
              final section = sections[index];
              final sectionId = section['id'] as int? ?? 0;
              final sectionNum = section['section'] as int? ?? index;
              final modules = (section['modules'] as List<dynamic>? ?? []);
              final sectionVisible = section['visible'] == 1 ||
                  section['visible'] == true;
              final sectionName = (section['name'] == null ||
                      section['name'].toString().trim().isEmpty)
                  ? 'GENERAL'
                  : section['name'].toString();
              final sectionSummary =
                  section['summary']?.toString().trim() ?? '';
              final canReorder = sectionNum > 0;
              final previous = index > 0 ? sections[index - 1] : null;
              final next =
                  index < sections.length - 1 ? sections[index + 1] : null;
              final previousId = previous?['id'] as int?;
              final nextId = next?['id'] as int?;
              final canMoveUp = canReorder && previousId != null &&
                  (previous?['section'] as int? ?? 0) > 0;
              final canMoveDown = canReorder && nextId != null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sectionName.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      if (_teacherMode) ...[
                        IconButton(
                          tooltip: 'Edit section',
                          onPressed: () => _editSection(
                            sectionId,
                            currentName: sectionName == 'GENERAL'
                                ? ''
                                : sectionName,
                            currentSummary: sectionSummary,
                          ),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        if (canMoveUp)
                          IconButton(
                            tooltip: 'Move section up',
                            onPressed: () =>
                                _moveSection(sectionId, previousId!),
                            icon: const Icon(Icons.arrow_upward),
                          ),
                        if (canMoveDown)
                          IconButton(
                            tooltip: 'Move section down',
                            onPressed: () => _moveSection(sectionId, nextId!),
                            icon: const Icon(Icons.arrow_downward),
                          ),
                        if (sectionVisible)
                          IconButton(
                            tooltip: 'Hide section',
                            onPressed: () =>
                                _sectionVisibility(sectionId, hide: true),
                            icon: const Icon(Icons.visibility_off_outlined),
                          )
                        else
                          IconButton(
                            tooltip: 'Show section',
                            onPressed: () =>
                                _sectionVisibility(sectionId, hide: false),
                            icon: const Icon(Icons.visibility_outlined),
                          ),
                        if (canReorder)
                          IconButton(
                            tooltip: 'Delete section',
                            onPressed: () =>
                                _deleteSection(sectionId, sectionName),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        IconButton(
                          tooltip: 'Add activity',
                          onPressed: () => _showAddActivityPicker(sectionId),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ],
                  ),
                  if (sectionSummary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    HtmlContent(html: sectionSummary),
                  ],
                  const SizedBox(height: 14),
                  ...modules.map((module) {
                    final type = module['modname']?.toString() ?? '';
                    final cmid = module['id'] as int? ?? 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        elevation: .4,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ActivityScreen(cmid: cmid),
                              ),
                            );
                          },
                          onLongPress: !_teacherMode
                              ? null
                              : () {
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (context) => ListView(
                                      shrinkWrap: true,
                                      children: [
                                        ListTile(
                                          title: Text(module['name']?.toString() ?? ''),
                                          subtitle: Text(type),
                                        ),
                                        if (type == 'assign')
                                          ListTile(
                                            leading: const Icon(Icons.edit_outlined),
                                            title: const Text('Edit'),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _openAssignmentEditor(
                                                sectionId: sectionId,
                                                cmid: cmid,
                                              );
                                            },
                                          ),
                                        ListTile(
                                          leading: const Icon(Icons.visibility_off),
                                          title: const Text('Hide'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _moduleAction('cm_hide', cmid);
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.visibility),
                                          title: const Text('Show'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _moduleAction('cm_show', cmid);
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.copy_all_outlined),
                                          title: const Text('Duplicate'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _moduleAction('cm_duplicate', cmid);
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.delete_outline),
                                          title: const Text('Delete'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _moduleAction('cm_delete', cmid);
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: _color(type).withValues(alpha: .12),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(_icon(type), color: _color(type)),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        module['name']?.toString() ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 17,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        type.toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                          letterSpacing: .5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 22),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CourseGradesScreen extends StatelessWidget {
  const _CourseGradesScreen({
    required this.courseId,
    required this.repository,
  });

  final int courseId;
  final CoursesRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grades')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: repository.getGrades(courseId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final usergrades = List<dynamic>.from(
            snapshot.data?['usergrades'] ?? const [],
          );
          if (usergrades.isEmpty) {
            return const Center(child: Text('No grades available'));
          }
          final gradeitems = List<dynamic>.from(
            Map<String, dynamic>.from(usergrades.first as Map)['gradeitems'] ??
                const [],
          );
          return ListView.builder(
            itemCount: gradeitems.length,
            itemBuilder: (context, index) {
              final item = Map<String, dynamic>.from(gradeitems[index] as Map);
              return ListTile(
                title: Text(item['itemname']?.toString() ?? 'Item'),
                subtitle: Text(item['graderaw']?.toString() ?? '-'),
                trailing: Text(item['percentageformatted']?.toString() ?? ''),
              );
            },
          );
        },
      ),
    );
  }
}

class _ParticipantsScreen extends StatelessWidget {
  const _ParticipantsScreen({
    required this.courseId,
    required this.repository,
  });

  final int courseId;
  final CoursesRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Participants')),
      body: FutureBuilder<List<dynamic>>(
        future: repository.getParticipants(courseId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final users = snapshot.data!;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = Map<String, dynamic>.from(users[index] as Map);
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(user['fullname']?.toString() ?? ''),
                subtitle: Text(user['email']?.toString() ?? ''),
              );
            },
          );
        },
      ),
    );
  }
}
