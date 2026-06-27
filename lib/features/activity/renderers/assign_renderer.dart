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
    final assignment = Map<String, dynamic>.from(
      activity.details['assignment'] as Map? ?? const {},
    );
    final status = Map<String, dynamic>.from(
      activity.details['submission_status'] as Map? ?? const {},
    );

    final dueDate = assignment['duedate'] as int?;
    final allowFrom = assignment['allowsubmissionsfromdate'] as int?;
    final submission = Map<String, dynamic>.from(
      status['lastattempt']?['submission'] as Map? ?? const {},
    );
    final submissionStatus = status['status']?.toString() ?? 'unknown';

    return ActivityLayout(
      activity: activity,
      children: [
        HtmlContent(
          html: assignment['intro']?.toString() ?? activity.description,
        ),
        const SizedBox(height: 20),
        _InfoCard(
          icon: Icons.schedule_rounded,
          title: 'Opens',
          value: formatTimestamp(allowFrom),
        ),
        _InfoCard(
          icon: Icons.event_rounded,
          title: 'Due date',
          value: formatTimestamp(dueDate),
        ),
        _InfoCard(
          icon: Icons.upload_file_rounded,
          title: 'Submission status',
          value: submissionStatus.replaceAll('_', ' ').toUpperCase(),
        ),
        if (submission.isNotEmpty) ...[
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.task_alt_rounded),
              title: const Text('Latest submission'),
              subtitle: Text(
                'Status: ${submission['status'] ?? submissionStatus}',
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        ContentFileList(
          contents: activity.contents,
          emptyMessage: 'No assignment files attached',
        ),
        if (activity.url != null && activity.url!.isNotEmpty) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => openExternalUrl(activity.url),
            icon: const Icon(Icons.open_in_browser_rounded),
            label: const Text('Open in Moodle'),
          ),
        ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

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
