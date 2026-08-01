import 'package:flutter/material.dart';

import 'activity_registry.dart';

/// Reusable Activity Picker sheet.
///
/// Returns the selected [ActivityTypeEntry] when an enabled type is tapped,
/// or null if dismissed.
Future<ActivityTypeEntry?> showActivityPicker(BuildContext context) {
  return showModalBottomSheet<ActivityTypeEntry>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Add activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ActivityRegistry.entries.length,
              itemBuilder: (context, index) {
                final entry = ActivityRegistry.entries[index];
                return ListTile(
                  leading: Icon(
                    entry.icon,
                    color: entry.enabled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  title: Text(entry.label),
                  subtitle: entry.enabled
                      ? null
                      : Text(entry.comingSoonMessage),
                  enabled: entry.enabled,
                  trailing: entry.enabled
                      ? const Icon(Icons.chevron_right)
                      : null,
                  onTap: entry.enabled
                      ? () => Navigator.pop(context, entry)
                      : null,
                );
              },
            ),
          ],
        ),
      );
    },
  );
}
