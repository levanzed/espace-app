import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'detail_renderer.dart';

class DataRenderer extends ActivityRenderer {
  const DataRenderer();

  static const _delegate = DetailRenderer(
    detailKey: 'data',
    actionLabel: 'Open database activity',
    actionIcon: Icons.table_chart_rounded,
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
