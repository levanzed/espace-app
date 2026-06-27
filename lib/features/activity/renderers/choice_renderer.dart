import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'detail_renderer.dart';

class ChoiceRenderer extends ActivityRenderer {
  const ChoiceRenderer();

  static const _delegate = DetailRenderer(
    detailKey: 'choice',
    actionLabel: 'Open choice activity',
    actionIcon: Icons.ballot_rounded,
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
