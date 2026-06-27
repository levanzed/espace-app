import 'package:flutter/material.dart';

import '../../models/activity.dart';
import 'activity_utils.dart';

class ActivityLayout extends StatelessWidget {
  final Activity activity;
  final List<Widget> children;

  const ActivityLayout({
    super.key,
    required this.activity,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final color = modnameColor(activity.modname);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                modnameIcon(activity.modname),
                color: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activity.modname.toUpperCase(),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ...children,
      ],
    );
  }
}
