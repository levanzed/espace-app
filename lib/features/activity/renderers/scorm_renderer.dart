import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'detail_renderer.dart';

class ScormRenderer extends ActivityRenderer {
  const ScormRenderer();

  static const _delegate = DetailRenderer(
    detailKey: 'scorm',
    actionLabel: 'Launch SCORM package',
    actionIcon: Icons.play_lesson_rounded,
  );

  @override
  Widget build(
    BuildContext context,
    Activity activity, {
    ActivityRepository? repository,
  }) {
    return _delegate.build(context, activity, repository: repository);
  }
}
