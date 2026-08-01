import 'package:flutter/material.dart';

/// Minimal Activity registry entry for teacher authoring (Sprint A+).
///
/// Separate from student [RendererRegistry] (viewers).
class ActivityTypeEntry {
  const ActivityTypeEntry({
    required this.modname,
    required this.label,
    required this.icon,
    required this.enabled,
    this.comingSoonMessage = 'Coming soon',
  });

  final String modname;
  final String label;
  final IconData icon;
  final bool enabled;
  final String comingSoonMessage;
}

/// Registry of Moodle activity types shown in the Activity Picker.
class ActivityRegistry {
  ActivityRegistry._();

  static const List<ActivityTypeEntry> entries = [
    ActivityTypeEntry(
      modname: 'assign',
      label: 'Assignment',
      icon: Icons.assignment_rounded,
      enabled: true,
    ),
    ActivityTypeEntry(
      modname: 'quiz',
      label: 'Quiz',
      icon: Icons.quiz_rounded,
      enabled: false,
    ),
    ActivityTypeEntry(
      modname: 'page',
      label: 'Page',
      icon: Icons.article_rounded,
      enabled: false,
    ),
    ActivityTypeEntry(
      modname: 'forum',
      label: 'Forum',
      icon: Icons.forum_rounded,
      enabled: false,
    ),
    ActivityTypeEntry(
      modname: 'resource',
      label: 'File',
      icon: Icons.insert_drive_file_rounded,
      enabled: false,
    ),
    ActivityTypeEntry(
      modname: 'url',
      label: 'URL',
      icon: Icons.language_rounded,
      enabled: false,
    ),
    ActivityTypeEntry(
      modname: 'folder',
      label: 'Folder',
      icon: Icons.folder_rounded,
      enabled: false,
    ),
    ActivityTypeEntry(
      modname: 'label',
      label: 'Text and media',
      icon: Icons.label_outline_rounded,
      enabled: false,
    ),
    ActivityTypeEntry(
      modname: 'book',
      label: 'Book',
      icon: Icons.menu_book_rounded,
      enabled: false,
    ),
  ];

  static ActivityTypeEntry? byModname(String modname) {
    for (final entry in entries) {
      if (entry.modname == modname) {
        return entry;
      }
    }
    return null;
  }
}
