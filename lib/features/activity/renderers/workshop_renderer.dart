import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'detail_renderer.dart';

class WorkshopRenderer extends ActivityRenderer {
  const WorkshopRenderer();

  static const _delegate = DetailRenderer(
    detailKey: 'workshop',
    actionLabel: 'Open workshop',
    actionIcon: Icons.groups_rounded,
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
