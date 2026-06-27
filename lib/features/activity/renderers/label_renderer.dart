import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'widgets/activity_layout.dart';
import 'widgets/html_content.dart';

class LabelRenderer extends ActivityRenderer {
  const LabelRenderer();

  @override
  Widget build(
    BuildContext context,
    Activity activity, {
    ActivityRepository? repository,
  }) {
    final label = Map<String, dynamic>.from(
      activity.details['label'] as Map? ?? const {},
    );
    final intro = label['intro']?.toString() ?? activity.description;

    return ActivityLayout(
      activity: activity,
      children: [
        HtmlContent(html: intro),
      ],
    );
  }
}
