import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'detail_renderer.dart';

class GlossaryRenderer extends ActivityRenderer {
  const GlossaryRenderer();

  static const _delegate = DetailRenderer(
    detailKey: 'glossary',
    actionLabel: 'Browse glossary',
    actionIcon: Icons.menu_book_outlined,
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
