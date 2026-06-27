import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'widgets/activity_layout.dart';
import 'widgets/activity_utils.dart';
import 'widgets/content_file_list.dart';
import 'widgets/html_content.dart';

class DetailRenderer extends ActivityRenderer {
  final String detailKey;
  final String introField;
  final String actionLabel;
  final IconData actionIcon;

  const DetailRenderer({
    required this.detailKey,
    this.introField = 'intro',
    this.actionLabel = 'Open in Moodle',
    this.actionIcon = Icons.open_in_browser_rounded,
  });

  @override
  Widget build(
    BuildContext context,
    Activity activity, {
    ActivityRepository? repository,
  }) {
    final detail = Map<String, dynamic>.from(
      activity.details[detailKey] as Map? ?? activity.detailForType ?? const {},
    );
    final intro = detail[introField]?.toString() ?? activity.description;

    return ActivityLayout(
      activity: activity,
      children: [
        HtmlContent(html: intro),
        const SizedBox(height: 20),
        ..._detailCards(detail),
        ContentFileList(contents: activity.contents),
        if (activity.url != null && activity.url!.isNotEmpty) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => openExternalUrl(activity.url),
            icon: Icon(actionIcon),
            label: Text(actionLabel),
          ),
        ],
      ],
    );
  }

  List<Widget> _detailCards(Map<String, dynamic> detail) {
    final cards = <Widget>[];

    for (final entry in detail.entries) {
      if (entry.key == introField || entry.key == 'content') {
        continue;
      }

      final value = entry.value;
      if (value == null || value == '' || value is Map || value is List) {
        continue;
      }

      cards.add(
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(entry.key.replaceAll('_', ' ').toUpperCase()),
            subtitle: Text(value.toString()),
          ),
        ),
      );
    }

    if (cards.isEmpty) {
      return const [];
    }

    return cards;
  }
}
