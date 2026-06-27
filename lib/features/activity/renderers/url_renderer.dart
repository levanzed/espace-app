import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'widgets/activity_layout.dart';
import 'widgets/activity_utils.dart';
import 'widgets/html_content.dart';

class UrlRenderer extends ActivityRenderer {
  const UrlRenderer();

  @override
  Widget build(
    BuildContext context,
    Activity activity, {
    ActivityRepository? repository,
  }) {
    final urlData = Map<String, dynamic>.from(
      activity.details['url'] as Map? ?? const {},
    );
    final externalUrl =
        urlData['externalurl']?.toString() ?? activity.url ?? '';

    return ActivityLayout(
      activity: activity,
      children: [
        HtmlContent(html: activity.description),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.language_rounded),
            title: const Text('Open link'),
            subtitle: Text(
              externalUrl.isEmpty ? 'No URL configured' : externalUrl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: externalUrl.isEmpty
                ? null
                : () => openExternalUrl(externalUrl),
          ),
        ),
      ],
    );
  }
}
