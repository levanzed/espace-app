import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../renderers/assign_submission_helpers.dart';
import '../renderers/widgets/activity_utils.dart';
import '../renderers/widgets/content_file_list.dart';
import '../renderers/widgets/html_content.dart';

class AssignGradeScreen extends StatefulWidget {
  const AssignGradeScreen({
    super.key,
    required this.cmid,
    required this.userid,
    required this.studentName,
    this.repository,
  });

  final int cmid;
  final int userid;
  final String studentName;
  final ActivityRepository? repository;

  @override
  State<AssignGradeScreen> createState() => _AssignGradeScreenState();
}

class _AssignGradeScreenState extends State<AssignGradeScreen> {
  late final ActivityRepository _repository =
      widget.repository ?? ActivityRepository();

  final _gradeController = TextEditingController();
  final _feedbackController = TextEditingController();

  bool _busy = false;
  String? _error;
  Map<String, dynamic> _status = const {};
  int? _feedbackDraftItemId;
  final List<String> _pendingFeedbackFiles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _gradeController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await _repository.getAssignStatusForUser(
        widget.cmid,
        widget.userid,
      );
      if (!mounted) return;
      setState(() {
        _status = status;
        _prefillFromStatus(status);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _prefillFromStatus(Map<String, dynamic> status) {
    final feedback = status['feedback'];
    if (feedback is! Map) return;

    final grade = feedback['grade'];
    if (grade is Map) {
      final raw = grade['grade'];
      if (raw != null && raw.toString() != '-1') {
        _gradeController.text = raw.toString();
      }
    }

    final comment = extractFeedbackCommentHtml(status);
    if (comment != null && _feedbackController.text.isEmpty) {
      _feedbackController.text = comment
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
  }

  Future<void> _pickFeedbackFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final draft = await _repository.getDraftItemId();
      _feedbackDraftItemId ??= int.parse(draft['itemid'].toString());
      final itemid = _feedbackDraftItemId!;
      final contextid = int.parse(draft['contextid'].toString());
      final component = draft['component']?.toString() ?? 'user';
      final filearea = draft['filearea']?.toString() ?? 'draft';

      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null || file.name.isEmpty) continue;
        await _repository.uploadDraftFile(
          filecontentBase64: base64Encode(bytes),
          filename: file.name,
          contextid: contextid,
          itemid: itemid,
          component: component,
          filearea: filearea,
        );
        _pendingFeedbackFiles.add(file.name);
      }
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final grade = double.tryParse(_gradeController.text.trim());
    if (grade == null) {
      setState(() => _error = 'Enter a valid numeric grade.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _repository.saveAssignGrade(
        widget.cmid,
        userid: widget.userid,
        grade: grade,
        feedbackText: _feedbackController.text.trim(),
        feedbackDraftitemid: _feedbackDraftItemId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final submittedText = extractOnlineTextHtml(_status);
    final submittedFiles = collectSubmissionFiles(_status);
    final modified = submissionTimeModified(_status);
    final previous = _status['previousattempts'];

    return Scaffold(
      backgroundColor: const Color(0xffF7F8FA),
      appBar: AppBar(
        title: Text(widget.studentName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _busy && _status.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                Text(
                  'Submission',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                if (modified != null && modified > 0)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded),
                    title: Text(formatTimestamp(modified)),
                    subtitle: const Text('Last modified'),
                  ),
                if (submittedText != null && submittedText.trim().isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: HtmlContent(html: submittedText),
                    ),
                  ),
                ContentFileList(
                  contents: submittedFiles,
                  emptyMessage: 'No submitted files',
                ),
                if (previous is List && previous.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Previous attempts',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  ...previous.map((attempt) {
                    final map = Map<String, dynamic>.from(attempt as Map);
                    final num = map['attemptnumber']?.toString() ?? '?';
                    return Card(
                      child: ListTile(
                        title: Text('Attempt $num'),
                        subtitle: Text(
                          map['submission'] != null
                              ? 'Has submission'
                              : 'No submission data',
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 24),
                Text(
                  'Grade and feedback',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _gradeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Grade',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _feedbackController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Feedback comment',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickFeedbackFiles,
                  icon: const Icon(Icons.attach_file_rounded),
                  label: const Text('Attach feedback files'),
                ),
                if (_pendingFeedbackFiles.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Feedback files to save: ${_pendingFeedbackFiles.join(', ')}',
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save grade'),
                ),
              ],
            ),
    );
  }
}
