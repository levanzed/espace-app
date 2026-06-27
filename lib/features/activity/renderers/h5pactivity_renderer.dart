import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'detail_renderer.dart';

class H5pActivityRenderer extends ActivityRenderer {
  const H5pActivityRenderer();

  static const _delegate = DetailRenderer(
    detailKey: 'h5pactivity',
    actionLabel: 'Launch H5P activity',
    actionIcon: Icons.widgets_rounded,
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
