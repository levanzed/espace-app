import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'widgets/activity_layout.dart';
import 'widgets/content_file_list.dart';
import 'widgets/html_content.dart';

class FolderRenderer extends ActivityRenderer {
  const FolderRenderer();

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
          emptyMessage: 'This folder is empty',
        ),
      ],
    );
  }
}
