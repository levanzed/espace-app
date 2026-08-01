import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../courses/data/courses_repository.dart';
import '../data/activity_repository.dart';

/// Teacher Assignment Editor (Sprint A authoring).
///
/// Create: [cmid] is null. Edit: [cmid] set; loads GET /activities/{cmid}.
class AssignmentEditorScreen extends StatefulWidget {
  const AssignmentEditorScreen({
    super.key,
    required this.courseId,
    required this.sectionId,
    this.cmid,
  });

  final int courseId;
  final int sectionId;
  final int? cmid;

  bool get isEdit => cmid != null;

  @override
  State<AssignmentEditorScreen> createState() => _AssignmentEditorScreenState();
}

class _AssignmentEditorScreenState extends State<AssignmentEditorScreen> {
  final _courses = CoursesRepository();
  final _activity = ActivityRepository();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _introController = TextEditingController();
  final _maxGradeController = TextEditingController(text: '100');
  final _maxFilesController = TextEditingController(text: '20');
  final _maxSizeController = TextEditingController(text: '0');
  final _scaleIdController = TextEditingController();
  final _gradeCatController = TextEditingController();

  bool _loading = false;
  bool _saving = false;
  String? _error;

  DateTime? _allowFrom;
  DateTime? _due;
  DateTime? _cutoff;
  DateTime? _gradingDue;

  bool _onlineText = true;
  bool _fileSubmit = true;
  bool _visible = true;
  String _gradeType = 'point';

  int? _introAttachmentsItemid;
  final List<String> _attachedNames = [];
  final List<String> _existingAttachmentNames = [];

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      _loadExisting();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _introController.dispose();
    _maxGradeController.dispose();
    _maxFilesController.dispose();
    _maxSizeController.dispose();
    _scaleIdController.dispose();
    _gradeCatController.dispose();
    super.dispose();
  }

  bool _asEnabled(dynamic value, {bool fallback = true}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    return text == '1' || text == 'true';
  }

  Future<void> _loadExisting() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await _courses.getActivityAuthoring(
        widget.courseId,
        widget.cmid!,
      );
      final settings = Map<String, dynamic>.from(
        payload['settings'] as Map? ?? const {},
      );
      _nameController.text = settings['name']?.toString() ?? '';
      _introController.text = settings['intro']?.toString() ?? '';
      _allowFrom = _fromUnix(settings['allowsubmissionsfromdate']);
      _due = _fromUnix(settings['duedate']);
      _cutoff = _fromUnix(settings['cutoffdate']);
      _gradingDue = _fromUnix(settings['gradingduedate']);
      _onlineText = _asEnabled(settings['onlinetext_enabled']);
      _fileSubmit = _asEnabled(settings['file_enabled']);
      _visible = _asEnabled(settings['visible']);
      _gradeType = settings['grade_type']?.toString() ?? 'point';
      if (settings['grade'] != null) {
        _maxGradeController.text = settings['grade'].toString();
      }
      if (settings['maxfiles'] != null) {
        _maxFilesController.text = settings['maxfiles'].toString();
      }
      if (settings['maxsizebytes'] != null) {
        _maxSizeController.text = settings['maxsizebytes'].toString();
      }
      if (settings['scaleid'] != null) {
        _scaleIdController.text = settings['scaleid'].toString();
      }
      if (settings['gradecat'] != null) {
        _gradeCatController.text = settings['gradecat'].toString();
      }

      _existingAttachmentNames.clear();
      final existing = payload['introattachments'];
      if (existing is List) {
        for (final item in existing) {
          if (item is Map && item['filename'] != null) {
            _existingAttachmentNames.add(item['filename'].toString());
          }
        }
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  DateTime? _fromUnix(dynamic value) {
    final seconds = int.tryParse(value?.toString() ?? '') ?? 0;
    if (seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  int _toUnix(DateTime? value) {
    if (value == null) return 0;
    return value.millisecondsSinceEpoch ~/ 1000;
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime?> onPicked,
  }) async {
    final now = DateTime.now();
    final initial = current ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      onPicked(DateTime(date.year, date.month, date.day));
      return;
    }
    onPicked(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Not set';
    return DateFormat('dd MMM yyyy HH:mm').format(value);
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final draft = await _activity.getDraftItemId();
      final itemid = int.parse(draft['itemid'].toString());
      final contextid = int.parse(draft['contextid'].toString());
      final component = draft['component']?.toString() ?? 'user';
      final filearea = draft['filearea']?.toString() ?? 'draft';

      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null || file.name.isEmpty) continue;
        await _activity.uploadDraftFile(
          filecontentBase64: base64Encode(bytes),
          filename: file.name,
          contextid: contextid,
          itemid: itemid,
          component: component,
          filearea: filearea,
        );
        _attachedNames.add(file.name);
      }
      _introAttachmentsItemid = itemid;
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Map<String, dynamic> _buildSettings() {
    final settings = <String, dynamic>{
      'name': _nameController.text.trim(),
      'intro': _introController.text,
      'introformat': 1,
      'allowsubmissionsfromdate': _toUnix(_allowFrom),
      'duedate': _toUnix(_due),
      'cutoffdate': _toUnix(_cutoff),
      'gradingduedate': _toUnix(_gradingDue),
      'onlinetext_enabled': _onlineText ? 1 : 0,
      'file_enabled': _fileSubmit ? 1 : 0,
      'visible': _visible ? 1 : 0,
      'grade_type': _gradeType,
    };

    if (_fileSubmit) {
      settings['maxfiles'] = int.tryParse(_maxFilesController.text.trim()) ?? 20;
      settings['maxsizebytes'] =
          int.tryParse(_maxSizeController.text.trim()) ?? 0;
    }

    if (_gradeType == 'point') {
      settings['grade'] = double.tryParse(_maxGradeController.text.trim()) ?? 100;
    } else if (_gradeType == 'scale') {
      settings['scaleid'] = int.tryParse(_scaleIdController.text.trim());
    } else {
      settings['grade'] = 0;
    }

    final gradecat = int.tryParse(_gradeCatController.text.trim());
    if (gradecat != null && gradecat > 0) {
      settings['gradecat'] = gradecat;
    }

    if (_introAttachmentsItemid != null) {
      settings['introattachments'] = _introAttachmentsItemid;
    }

    return settings;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_onlineText && !_fileSubmit) {
      setState(() {
        _error = 'Enable at least one submission type (online text or file).';
      });
      return;
    }
    if (_gradeType == 'scale' &&
        (int.tryParse(_scaleIdController.text.trim()) ?? 0) <= 0) {
      setState(() => _error = 'Scale id is required for scale grading.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final settings = _buildSettings();
      if (widget.isEdit) {
        await _courses.updateActivity(
          widget.courseId,
          widget.cmid!,
          settings: settings,
        );
      } else {
        await _courses.createActivity(
          widget.courseId,
          sectionId: widget.sectionId,
          modname: 'assign',
          settings: settings,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit assignment' : 'New assignment'),
        actions: [
          TextButton(
            onPressed: _saving || _loading ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) ...[
                    Material(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Assignment name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _introController,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_existingAttachmentNames.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Existing attachments: ${_existingAttachmentNames.join(', ')}',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickAttachments,
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                      _attachedNames.isEmpty
                          ? (widget.isEdit
                              ? 'Replace / add attachments (optional)'
                              : 'Add attachments (optional)')
                          : 'Add more attachments (${_attachedNames.length})',
                    ),
                  ),
                  if (_attachedNames.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'New uploads this session: ${_attachedNames.join(', ')}',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    'Availability',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  _dateTile(
                    'Allow submissions from',
                    _allowFrom,
                    (value) => setState(() => _allowFrom = value),
                  ),
                  _dateTile(
                    'Due date',
                    _due,
                    (value) => setState(() => _due = value),
                  ),
                  _dateTile(
                    'Cut-off date',
                    _cutoff,
                    (value) => setState(() => _cutoff = value),
                  ),
                  _dateTile(
                    'Remind me to grade by',
                    _gradingDue,
                    (value) => setState(() => _gradingDue = value),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Submission types',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  SwitchListTile(
                    title: const Text('Online text'),
                    value: _onlineText,
                    onChanged: (value) => setState(() => _onlineText = value),
                  ),
                  SwitchListTile(
                    title: const Text('File submissions'),
                    value: _fileSubmit,
                    onChanged: (value) => setState(() => _fileSubmit = value),
                  ),
                  if (_fileSubmit) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _maxFilesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Maximum number of uploaded files',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _maxSizeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Maximum submission size (bytes)',
                        helperText: '0 = course / site default',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Grade',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Grade type',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final type in const ['none', 'point', 'scale'])
                        ChoiceChip(
                          label: Text(type[0].toUpperCase() + type.substring(1)),
                          selected: _gradeType == type,
                          onSelected: (_) => setState(() => _gradeType = type),
                        ),
                    ],
                  ),
                  if (_gradeType == 'point') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _maxGradeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Maximum grade',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (_gradeType == 'scale') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _scaleIdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Scale id',
                        helperText: 'Moodle scale id (from site/course scales)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _gradeCatController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Grade category id (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Visible on course page'),
                    value: _visible,
                    onChanged: (value) => setState(() => _visible = value),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(widget.isEdit ? 'Save changes' : 'Create assignment'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _dateTile(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onChanged,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(_formatDate(value)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            IconButton(
              tooltip: 'Clear',
              onPressed: () => onChanged(null),
              icon: const Icon(Icons.clear),
            ),
          IconButton(
            tooltip: 'Pick date',
            onPressed: () => _pickDate(current: value, onPicked: onChanged),
            icon: const Icon(Icons.event),
          ),
        ],
      ),
    );
  }
}
