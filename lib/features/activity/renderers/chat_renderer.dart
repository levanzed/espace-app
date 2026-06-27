import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'detail_renderer.dart';

class ChatRenderer extends ActivityRenderer {
  const ChatRenderer();

  static const _delegate = DetailRenderer(
    detailKey: 'chat',
    actionLabel: 'Join chat session',
    actionIcon: Icons.chat_rounded,
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
