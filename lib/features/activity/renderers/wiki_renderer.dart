import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'detail_renderer.dart';

class WikiRenderer extends ActivityRenderer {
  const WikiRenderer();

  static const _delegate = DetailRenderer(
    detailKey: 'wiki',
    actionLabel: 'Open wiki',
    actionIcon: Icons.edit_note_rounded,
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
