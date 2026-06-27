import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'widgets/activity_layout.dart';
import 'widgets/activity_utils.dart';
import 'widgets/content_file_list.dart';
import 'widgets/html_content.dart';

class GenericRenderer extends ActivityRenderer {
  const GenericRenderer();

  @override
  Widget build(
    BuildContext context,
    Activity activity, {
    ActivityRepository? repository,
  }) {
    return ActivityLayout(
      activity: activity,
      children: [
        HtmlContent(html: activity.description),
        const SizedBox(height: 20),
        ContentFileList(
          contents: activity.contents,
          emptyMessage: 'No downloadable content for this activity',
        ),
        if (activity.url != null && activity.url!.isNotEmpty) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => openExternalUrl(activity.url),
            icon: const Icon(Icons.open_in_browser_rounded),
            label: const Text('Open activity'),
          ),
        ],
      ],
    );
  }
}
