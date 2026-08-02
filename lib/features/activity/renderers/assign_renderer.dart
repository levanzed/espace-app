import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../grading/assign_participants_screen.dart';
import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'assign_submission_helpers.dart';
import 'widgets/activity_layout.dart';
import 'widgets/activity_utils.dart';
import 'widgets/content_file_list.dart';
import 'widgets/html_content.dart';

class AssignRenderer extends ActivityRenderer {
  const AssignRenderer();

  @override
  Widget build(
    BuildContext context,
    Activity activity, {
    ActivityRepository? repository,
  }) {
    return _AssignView(
      activity: activity,
      repository: repository ?? ActivityRepository(),
    );
  }
}

class _AssignView extends StatefulWidget {
  const _AssignView({
    required this.activity,
    required this.repository,
  });

  final Activity activity;
  final ActivityRepository repository;

  @override
  State<_AssignView> createState() => _AssignViewState();
}

class _AssignViewState extends State<_AssignView> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  late Map<String, dynamic> _assignment;
  late Map<String, dynamic> _status;

  int? _pendingDraftItemId;
  final List<String> _pendingFileNames = [];

  List<dynamic> get _introAttachmentFiles {
    final intro = _assignment['introattachments'];
    if (intro is List && intro.isNotEmpty) {
      return intro;
    }
    return widget.activity.contents;
  }

  bool get _onlineTextEnabled => assignConfigEnabled(_assignment, 'onlinetext');
  bool get _fileSubmitEnabled => assignConfigEnabled(_assignment, 'file');

  @override
  void initState() {
    super.initState();
    _applyActivity(widget.activity);
  }

  @override
  void didUpdateWidget(covariant _AssignView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity.id != widget.activity.id) {
      _applyActivity(widget.activity);
    }
  }

  void _applyActivity(Activity activity) {
    _assignment = Map<String, dynamic>.from(
      activity.details['assignment'] as Map? ?? const {},
    );
    _status = Map<String, dynamic>.from(
      activity.details['submission_status'] as Map? ?? const {},
    );
    final existingText = extractOnlineTextHtml(_status);
    if (existingText != null && _controller.text.isEmpty) {
      _controller.text = _stripHtmlForField(existingText);
    }
  }

  String _stripHtmlForField(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final activity = await widget.repository.getActivity(widget.activity.id);
      if (!mounted) return;
      setState(() {
        _applyActivity(activity);
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error.toString();
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _pickSubmissionFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _busy = true;
      _message = null;
      _messageIsError = false;
    });

    try {
      final draft = await widget.repository.getDraftItemId();
      _pendingDraftItemId ??= int.parse(draft['itemid'].toString());
      final itemid = _pendingDraftItemId!;
      final contextid = int.parse(draft['contextid'].toString());
      final component = draft['component']?.toString() ?? 'user';
      final filearea = draft['filearea']?.toString() ?? 'draft';

      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null || file.name.isEmpty) continue;
        await widget.repository.uploadDraftFile(
          filecontentBase64: base64Encode(bytes),
          filename: file.name,
          contextid: contextid,
          itemid: itemid,
          component: component,
          filearea: filearea,
        );
        _pendingFileNames.add(file.name);
      }
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error.toString();
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmSubmissionStatement() async {
    if (!assignmentRequiresSubmissionStatement(_assignment)) {
      return true;
    }
    final statement = _assignment['submissionstatement']?.toString() ??
        'You must agree to the submission statement before submitting.';

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Submission statement'),
          content: SingleChildScrollView(
            child: HtmlContent(html: statement),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('I agree'),
            ),
          ],
        );
      },
    );
    return accepted == true;
  }

  Future<void> _save({required bool submit}) async {
    if (submit) {
      final ok = await _confirmSubmissionStatement();
      if (!ok) return;
    }

    final text = _controller.text.trim();
    final hasText = _onlineTextEnabled && text.isNotEmpty;
    final hasFiles = _fileSubmitEnabled && _pendingDraftItemId != null;
    final submittedFiles = collectSubmissionFiles(_status);
    final submittedText = extractOnlineTextHtml(_status);
    final hasExistingWork = submittedFiles.isNotEmpty ||
        (submittedText != null && submittedText.trim().isNotEmpty) ||
        submissionStatusKey(_status) == 'draft';

    if (submit) {
      if (!hasText && !hasFiles && !hasExistingWork) {
        setState(() {
          _message = 'Add online text or files before submitting.';
          _messageIsError = true;
        });
        return;
      }
    } else if (!hasText && !hasFiles) {
      setState(() {
        _message = 'Nothing to save. Add text or upload files.';
        _messageIsError = true;
      });
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
      _messageIsError = false;
    });

    try {
      if (hasText || hasFiles) {
        await widget.repository.saveAssignSubmission(
          widget.activity.id,
          onlinetext: hasText ? text : null,
          draftitemid: hasFiles ? _pendingDraftItemId : null,
        );
      }
      if (submit) {
        await widget.repository.submitAssign(
          widget.activity.id,
          acceptSubmissionStatement:
              assignmentRequiresSubmissionStatement(_assignment),
        );
      }
      _pendingDraftItemId = null;
      _pendingFileNames.clear();
      await _refresh();
      if (!mounted) return;
      setState(() {
        _message = submit
            ? 'Submitted for grading. You can review your submission below.'
            : 'Draft saved.';
        _messageIsError = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error.toString();
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = submissionStatusLabel(_status);
    final statusKey = submissionStatusKey(_status);
    final modified = submissionTimeModified(_status);
    final submittedFiles = collectSubmissionFiles(_status);
    final submittedText = extractOnlineTextHtml(_status);
    final canEdit = canEditSubmission(_status);
    final canSubmit = canSubmitForGrading(_status);
    final blockMessage = submissionBlockingMessage(_status, _assignment);
    final showEditor = canEdit || canSubmit;

    return ActivityLayout(
      activity: widget.activity,
      children: [
        HtmlContent(
          html: _assignment['intro']?.toString() ?? widget.activity.description,
        ),
        const SizedBox(height: 16),
        _InfoCard(
          icon: Icons.schedule_rounded,
          title: 'Opens',
          value: formatTimestamp(_assignment['allowsubmissionsfromdate'] as int?),
        ),
        _InfoCard(
          icon: Icons.event_rounded,
          title: 'Due date',
          value: formatTimestamp(_assignment['duedate'] as int?),
        ),
        _StatusCard(label: statusLabel, statusKey: statusKey),
        if (canOpenGradingInbox(_status)) ...[
          const SizedBox(height: 4),
          FilledButton.tonalIcon(
            onPressed: _busy
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AssignParticipantsScreen(
                          cmid: widget.activity.id,
                          activityName: widget.activity.name,
                          repository: widget.repository,
                        ),
                      ),
                    );
                  },
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Grade submissions'),
          ),
          const SizedBox(height: 12),
        ],
        if (blockMessage != null)
          Card(
            color: Colors.amber.shade50,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(Icons.info_outline, color: Colors.amber.shade900),
              title: Text(blockMessage),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh status'),
          ),
        ),
        const _SectionTitle('Assignment materials'),
        ContentFileList(
          contents: _introAttachmentFiles,
          emptyMessage: 'No assignment files attached',
        ),
        const SizedBox(height: 8),
        const _SectionTitle('Your submission'),
        if (modified != null && modified > 0)
          _InfoCard(
            icon: Icons.update_rounded,
            title: 'Last saved',
            value: formatTimestamp(modified),
          ),
        if (submittedText != null && submittedText.trim().isNotEmpty) ...[
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Online text',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  HtmlContent(html: submittedText),
                ],
              ),
            ),
          ),
        ],
        if (submittedFiles.isNotEmpty)
          ContentFileList(
            contents: submittedFiles,
            emptyMessage: 'No files submitted',
          )
        else if (!_fileSubmitEnabled)
          const SizedBox.shrink()
        else
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.attach_file_outlined),
              title: const Text('No files submitted yet'),
            ),
          ),
        if (statusKey == 'submitted' && !canEdit)
          Card(
            color: Colors.green.shade50,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(Icons.check_circle_outline, color: Colors.green.shade800),
              title: const Text('Submission received'),
              subtitle: Text(
                modified != null
                    ? 'Submitted ${formatTimestamp(modified)}'
                    : 'Your work has been submitted for grading.',
              ),
            ),
          ),
        if (hasReleasedFeedback(_status)) ...[
          const _SectionTitle('Grade and feedback'),
          if (gradeForDisplay(_status) != null)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.grade_rounded),
                title: const Text('Grade'),
                subtitle: HtmlContent(html: gradeForDisplay(_status)!),
              ),
            ),
          if (extractFeedbackCommentHtml(_status) != null)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Feedback',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    HtmlContent(html: extractFeedbackCommentHtml(_status)!),
                  ],
                ),
              ),
            ),
          if (collectFeedbackFiles(_status).isNotEmpty)
            ContentFileList(
              contents: collectFeedbackFiles(_status),
              emptyMessage: 'No feedback files',
            ),
          const SizedBox(height: 8),
        ],
        if (showEditor) ...[
          const SizedBox(height: 8),
          const _SectionTitle('Add or update your work'),
          if (_onlineTextEnabled) ...[
            TextField(
              controller: _controller,
              maxLines: 8,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Online text',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_fileSubmitEnabled) ...[
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickSubmissionFiles,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Choose files'),
            ),
            if (_pendingFileNames.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Text(
                  'Files to save: ${_pendingFileNames.join(', ')}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            if (submittedFiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Saving new files replaces your previous file submission.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
          ],
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _message!,
                style: TextStyle(
                  color: _messageIsError ? Colors.red.shade700 : Colors.green.shade800,
                ),
              ),
            ),
          Row(
            children: [
              if (canEdit)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _save(submit: false),
                    child: const Text('Save draft'),
                  ),
                ),
              if (canEdit && canSubmit) const SizedBox(width: 12),
              if (canSubmit)
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _save(submit: true),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit'),
                  ),
                ),
            ],
          ),
        ] else if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _message!,
              style: TextStyle(
                color: _messageIsError ? Colors.red.shade700 : Colors.green.shade800,
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.label,
    required this.statusKey,
  });

  final String label;
  final String statusKey;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (statusKey) {
      'submitted' => (Colors.green, Icons.task_alt_rounded),
      'draft' => (Colors.orange, Icons.edit_note_rounded),
      'reopened' => (Colors.blue, Icons.replay_rounded),
      _ => (Colors.blueGrey, Icons.assignment_outlined),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color.shade700),
        title: const Text('Submission status'),
        subtitle: Text(label),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }
}
