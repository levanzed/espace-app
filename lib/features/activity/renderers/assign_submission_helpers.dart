/// Parses Moodle assign assignment + mod_assign_get_submission_status payloads.
library;

bool assignConfigEnabled(Map<String, dynamic> assignment, String plugin) {
  final configs = assignment['configs'];
  if (configs is! List) return false;
  for (final row in configs) {
    if (row is! Map) continue;
    final map = Map<String, dynamic>.from(row);
    if (map['subtype'] == 'assignsubmission' &&
        map['plugin'] == plugin &&
        map['name'] == 'enabled') {
      final value = map['value']?.toString() ?? '';
      return value == '1' || value.toLowerCase() == 'true';
    }
  }
  return false;
}

bool assignmentRequiresSubmissionStatement(Map<String, dynamic> assignment) {
  final raw = assignment['requiresubmissionstatement'];
  return raw == 1 || raw == true || raw?.toString() == '1';
}

Map<String, dynamic>? _lastAttempt(Map<String, dynamic> status) {
  final last = status['lastattempt'];
  if (last is Map) {
    return Map<String, dynamic>.from(last);
  }
  return null;
}

Map<String, dynamic>? _submission(Map<String, dynamic> status) {
  final last = _lastAttempt(status);
  final submission = last?['submission'];
  if (submission is Map) {
    return Map<String, dynamic>.from(submission);
  }
  return null;
}

void _walkPlugins(dynamic plugins, void Function(Map<String, dynamic> plugin) visit) {
  if (plugins is! List) return;
  for (final entry in plugins) {
    if (entry is Map) {
      visit(Map<String, dynamic>.from(entry));
    }
  }
}

List<Map<String, dynamic>> collectFilesFromPlugins(dynamic plugins) {
  final files = <Map<String, dynamic>>[];
  _walkPlugins(plugins, (plugin) {
    final areas = plugin['fileareas'];
    if (areas is! List) return;
    for (final area in areas) {
      if (area is! Map) continue;
      final areaFiles = area['files'];
      if (areaFiles is! List) continue;
      for (final file in areaFiles) {
        if (file is Map) {
          files.add(Map<String, dynamic>.from(file));
        }
      }
    }
  });
  return files;
}

List<Map<String, dynamic>> collectSubmissionFiles(Map<String, dynamic> status) {
  final files = <Map<String, dynamic>>[];
  final last = _lastAttempt(status);
  if (last == null) return files;
  if (last['submission'] is Map) {
    files.addAll(
      collectFilesFromPlugins((last['submission'] as Map)['plugins']),
    );
  }
  if (last['teamsubmission'] is Map) {
    files.addAll(
      collectFilesFromPlugins((last['teamsubmission'] as Map)['plugins']),
    );
  }
  return files;
}

String? extractOnlineTextHtml(Map<String, dynamic> status) {
  final submission = _submission(status);
  if (submission == null) return null;

  String? fromPlugins(dynamic plugins) {
    String? found;
    _walkPlugins(plugins, (plugin) {
      if (found != null) return;
      final name = plugin['name']?.toString() ?? '';
      final type = plugin['type']?.toString() ?? '';
      if (name != 'onlinetext' && type != 'onlinetext') return;
      final fields = plugin['editorfields'];
      if (fields is! List) return;
      for (final field in fields) {
        if (field is! Map) continue;
        final fieldMap = Map<String, dynamic>.from(field);
        if (fieldMap['name']?.toString() == 'onlinetext') {
          final text = fieldMap['text']?.toString();
          if (text != null && text.trim().isNotEmpty) {
            found = text;
          }
        }
      }
    });
    return found;
  }

  return fromPlugins(submission['plugins']);
}

int? submissionTimeModified(Map<String, dynamic> status) {
  final submission = _submission(status);
  final raw = submission?['timemodified'];
  if (raw is int) return raw;
  return int.tryParse(raw?.toString() ?? '');
}

String submissionStatusKey(Map<String, dynamic> status) {
  final submission = _submission(status);
  final raw = submission?['status']?.toString();
  if (raw != null && raw.isNotEmpty) return raw;
  return 'new';
}

String submissionStatusLabel(Map<String, dynamic> status) {
  switch (submissionStatusKey(status)) {
    case 'submitted':
      return 'Submitted';
    case 'draft':
      return 'Draft';
    case 'reopened':
      return 'Reopened';
    case 'new':
      return 'Not started';
    default:
      return submissionStatusKey(status).replaceAll('_', ' ');
  }
}

bool submissionLocked(Map<String, dynamic> status) {
  final last = _lastAttempt(status);
  return last?['locked'] == true || last?['locked'] == 1;
}

bool canEditSubmission(Map<String, dynamic> status) {
  final last = _lastAttempt(status);
  if (last == null) return false;
  if (submissionLocked(status)) return false;
  return last['canedit'] == true || last['canedit'] == 1;
}

bool canSubmitForGrading(Map<String, dynamic> status) {
  final last = _lastAttempt(status);
  if (last == null) return false;
  if (submissionLocked(status)) return false;
  return last['cansubmit'] == true || last['cansubmit'] == 1;
}

bool submissionsEnabled(Map<String, dynamic> status, Map<String, dynamic> assignment) {
  final last = _lastAttempt(status);
  if (last != null) {
    final enabled = last['submissionsenabled'];
    if (enabled == false || enabled == 0) return false;
  }
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final allowFrom = assignment['allowsubmissionsfromdate'];
  if (allowFrom is int && allowFrom > 0 && now < allowFrom) {
    return false;
  }
  return true;
}

String? submissionBlockingMessage(
  Map<String, dynamic> status,
  Map<String, dynamic> assignment,
) {
  if (!submissionsEnabled(status, assignment)) {
    final allowFrom = assignment['allowsubmissionsfromdate'];
    if (allowFrom is int && allowFrom > 0) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now < allowFrom) {
        return 'Submissions are not open yet.';
      }
    }
    return 'Submissions are closed for this assignment.';
  }
  if (submissionLocked(status)) {
    return 'Your submission is locked. You cannot make changes.';
  }
  if (!canEditSubmission(status) &&
      !canSubmitForGrading(status) &&
      submissionStatusKey(status) == 'submitted') {
    return 'You have submitted this assignment for grading.';
  }
  if (!canEditSubmission(status) && !canSubmitForGrading(status)) {
    return 'You cannot edit or submit at this time.';
  }
  return null;
}

bool canOpenGradingInbox(Map<String, dynamic> status) {
  return status['gradingsummary'] != null;
}

String? gradeForDisplay(Map<String, dynamic> status) {
  final feedback = status['feedback'];
  if (feedback is! Map) return null;
  final display = feedback['gradefordisplay']?.toString();
  if (display != null && display.trim().isNotEmpty) {
    return display;
  }
  return null;
}

String? extractFeedbackCommentHtml(Map<String, dynamic> status) {
  final feedback = status['feedback'];
  if (feedback is! Map) return null;

  String? fromPlugins(dynamic plugins) {
    String? found;
    _walkPlugins(plugins, (plugin) {
      if (found != null) return;
      final name = plugin['name']?.toString() ?? '';
      final type = plugin['type']?.toString() ?? '';
      if (name != 'comments' && type != 'comments') return;
      final fields = plugin['editorfields'];
      if (fields is! List) return;
      for (final field in fields) {
        if (field is! Map) continue;
        final fieldMap = Map<String, dynamic>.from(field);
        final text = fieldMap['text']?.toString();
        if (text != null && text.trim().isNotEmpty) {
          found = text;
        }
      }
    });
    return found;
  }

  return fromPlugins(feedback['plugins']);
}

List<Map<String, dynamic>> collectFeedbackFiles(Map<String, dynamic> status) {
  final feedback = status['feedback'];
  if (feedback is! Map) return [];

  // Only assignfeedback_file uploads (ESPACE "Attach feedback files").
  // Exclude editpdf (combined.pdf, stamp PNGs) and other Moodle grader plugins.
  final files = <Map<String, dynamic>>[];
  _walkPlugins(feedback['plugins'], (plugin) {
    final name = plugin['name']?.toString() ?? '';
    final type = plugin['type']?.toString() ?? '';
    if (name != 'file' && type != 'file') return;
    files.addAll(collectFilesFromPlugins([plugin]));
  });
  return files;
}

bool hasReleasedFeedback(Map<String, dynamic> status) {
  if (gradeForDisplay(status) != null) return true;
  final comment = extractFeedbackCommentHtml(status);
  if (comment != null && comment.trim().isNotEmpty) return true;
  return collectFeedbackFiles(status).isNotEmpty;
}
