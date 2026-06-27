import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'widgets/activity_layout.dart';
import 'widgets/html_content.dart';

class PageRenderer extends ActivityRenderer {
  const PageRenderer();

  @override
  Widget build(
    BuildContext context,
    Activity activity, {
    ActivityRepository? repository,
  }) {
    final page = Map<String, dynamic>.from(
      activity.details['page'] as Map? ?? const {},
    );
    final content = page['content']?.toString() ??
        activity.details['content']?.toString() ??
        activity.description;

    return ActivityLayout(
      activity: activity,
      children: [
        HtmlContent(html: content),
      ],
    );
  }
}
