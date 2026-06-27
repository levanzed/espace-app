import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'detail_renderer.dart';

class FeedbackRenderer extends ActivityRenderer {
  const FeedbackRenderer();

  static const _delegate = DetailRenderer(
    detailKey: 'feedback',
    actionLabel: 'Open feedback form',
    actionIcon: Icons.rate_review_rounded,
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
