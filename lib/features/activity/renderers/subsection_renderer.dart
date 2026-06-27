import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'detail_renderer.dart';

class SubsectionRenderer extends ActivityRenderer {
  const SubsectionRenderer();

  @override
  Widget build(
    BuildContext context,
    Activity activity, {
    ActivityRepository? repository,
  }) {
    return const DetailRenderer(
      detailKey: 'subsection',
      introField: 'name',
      actionLabel: 'View subsection',
      actionIcon: Icons.view_agenda_rounded,
    ).build(context, activity, repository: repository);
  }
}
