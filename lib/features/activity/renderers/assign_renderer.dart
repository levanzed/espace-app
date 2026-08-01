import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
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

  Map<String, dynamic> get _assignment => Map<String, dynamic>.from(
        widget.activity.details['assignment'] as Map? ?? const {},
      );

  Map<String, dynamic> get _status => Map<String, dynamic>.from(
        widget.activity.details['submission_status'] as Map? ?? const {},
      );

  /// Intro attachments live on the assign WS record, not course-module contents.
  List<dynamic> get _introAttachmentFiles {
    final intro = _assignment['introattachments'];
    if (intro is List && intro.isNotEmpty) {
      return intro;
    }
    return widget.activity.contents;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save({bool submit = false}) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_controller.text.trim().isNotEmpty) {
        await widget.repository.saveAssignSubmission(
          widget.activity.id,
          onlinetext: _controller.text.trim(),
        );
      }
      if (submit) {
        await widget.repository.submitAssign(widget.activity.id);
      }
      setState(() {
        _message = submit ? 'Submitted for grading.' : 'Draft saved.';
      });
    } catch (error) {
      setState(() => _message = error.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedback = Map<String, dynamic>.from(
      _status['feedback'] as Map? ?? const {},
    );
    final submissionStatus = _status['status']?.toString() ?? 'unknown';

    return ActivityLayout(
      activity: widget.activity,
      children: [
        HtmlContent(
          html: _assignment['intro']?.toString() ?? widget.activity.description,
        ),
        const SizedBox(height: 20),
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
        _InfoCard(
          icon: Icons.upload_file_rounded,
          title: 'Submission status',
          value: submissionStatus.replaceAll('_', ' ').toUpperCase(),
        ),
        if (feedback.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.feedback_outlined),
              title: const Text('Feedback'),
              subtitle: HtmlContent(
                html: feedback['plugins'] != null
                    ? feedback.toString()
                    : (feedback['grade']?.toString() ?? 'Available'),
              ),
            ),
          ),
        ContentFileList(
          contents: _introAttachmentFiles,
          emptyMessage: 'No assignment files attached',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Online text submission',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_message!),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _save(submit: false),
                child: const Text('Save draft'),
              ),
            ),
            const SizedBox(width: 12),
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
      ],
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
