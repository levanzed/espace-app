import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'detail_renderer.dart';

class LtiRenderer extends ActivityRenderer {
  const LtiRenderer();

  static const _delegate = DetailRenderer(
    detailKey: 'lti',
    actionLabel: 'Launch external tool',
    actionIcon: Icons.extension_rounded,
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
