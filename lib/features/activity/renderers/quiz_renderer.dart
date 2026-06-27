import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'widgets/activity_layout.dart';
import 'widgets/activity_utils.dart';
import 'widgets/html_content.dart';

class QuizRenderer extends ActivityRenderer {
  const QuizRenderer();

  @override
  Widget build(
    BuildContext context,
    Activity activity, {
    ActivityRepository? repository,
  }) {
    final quiz = Map<String, dynamic>.from(
      activity.details['quiz'] as Map? ?? const {},
    );
    final attemptsData = Map<String, dynamic>.from(
      activity.details['attempts'] as Map? ?? const {},
    );
    final attempts = List<dynamic>.from(attemptsData['attempts'] ?? const []);

    return ActivityLayout(
      activity: activity,
      children: [
        HtmlContent(
          html: quiz['intro']?.toString() ?? activity.description,
        ),
        const SizedBox(height: 20),
        _InfoCard(
          icon: Icons.schedule_rounded,
          title: 'Opens',
          value: formatTimestamp(quiz['timeopen'] as int?),
        ),
        _InfoCard(
          icon: Icons.timer_off_rounded,
          title: 'Closes',
          value: formatTimestamp(quiz['timeclose'] as int?),
        ),
        _InfoCard(
          icon: Icons.timelapse_rounded,
          title: 'Time limit',
          value: _formatTimeLimit(quiz['timelimit'] as int?),
        ),
        _InfoCard(
          icon: Icons.replay_rounded,
          title: 'Attempts allowed',
          value: quiz['attempts']?.toString() ?? 'Unlimited',
        ),
        const SizedBox(height: 8),
        Text(
          'Your attempts',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (attempts.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.quiz_outlined),
              title: Text('No attempts yet'),
            ),
          )
        else
          ...attempts.map((attempt) {
            final map = Map<String, dynamic>.from(attempt as Map);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.fact_check_rounded),
                title: Text('Attempt ${map['attempt'] ?? ''}'),
                subtitle: Text(
                  'State: ${map['state'] ?? 'unknown'} • Grade: ${map['sumgrades'] ?? '-'}',
                ),
              ),
            );
          }),
        if (activity.url != null && activity.url!.isNotEmpty) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => openExternalUrl(activity.url),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start quiz in Moodle'),
          ),
        ],
      ],
    );
  }

  String _formatTimeLimit(int? seconds) {
    if (seconds == null || seconds == 0) {
      return 'No limit';
    }
    final minutes = (seconds / 60).round();
    return '$minutes minutes';
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
