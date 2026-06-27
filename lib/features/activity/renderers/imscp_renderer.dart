import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'detail_renderer.dart';

class ImscpRenderer extends ActivityRenderer {
  const ImscpRenderer();

  static const _delegate = DetailRenderer(
    detailKey: 'imscp',
    actionLabel: 'Open IMS content package',
    actionIcon: Icons.inventory_2_rounded,
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
