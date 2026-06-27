import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';

abstract class ActivityRenderer {
  const ActivityRenderer();

  Widget build(
    BuildContext context,
    Activity activity, {
    ActivityRepository? repository,
  });
}
