import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openExternalUrl(String? url) async {
  if (url == null || url.isEmpty) {
    return;
  }

  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw Exception('Could not open $url');
  }
}

String formatTimestamp(int? timestamp) {
  if (timestamp == null || timestamp == 0) {
    return 'Not set';
  }

  final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

IconData modnameIcon(String modname) {
  switch (modname) {
    case 'assign':
      return Icons.assignment_rounded;
    case 'quiz':
      return Icons.quiz_rounded;
    case 'forum':
      return Icons.forum_rounded;
    case 'resource':
      return Icons.picture_as_pdf_rounded;
    case 'folder':
      return Icons.folder_rounded;
    case 'url':
      return Icons.language_rounded;
    case 'page':
      return Icons.article_rounded;
    case 'book':
      return Icons.menu_book_rounded;
    case 'label':
      return Icons.label_outline_rounded;
    case 'choice':
      return Icons.ballot_rounded;
    case 'feedback':
      return Icons.rate_review_rounded;
    case 'glossary':
      return Icons.menu_book_outlined;
    case 'lesson':
      return Icons.school_rounded;
    case 'wiki':
      return Icons.edit_note_rounded;
    case 'workshop':
      return Icons.groups_rounded;
    case 'scorm':
      return Icons.play_lesson_rounded;
    case 'h5pactivity':
      return Icons.widgets_rounded;
    case 'chat':
      return Icons.chat_rounded;
    case 'data':
      return Icons.table_chart_rounded;
    case 'lti':
    case 'ltiexternaltool':
      return Icons.extension_rounded;
    case 'bigbluebuttonbn':
      return Icons.videocam_rounded;
    case 'imscp':
      return Icons.inventory_2_rounded;
    case 'subsection':
      return Icons.view_agenda_rounded;
    default:
      return Icons.description_rounded;
  }
}

Color modnameColor(String modname) {
  switch (modname) {
    case 'assign':
      return Colors.orange;
    case 'quiz':
      return Colors.deepPurple;
    case 'forum':
      return Colors.green;
    case 'resource':
      return Colors.red;
    case 'folder':
      return Colors.amber.shade800;
    case 'url':
      return Colors.cyan;
    case 'page':
      return Colors.blue;
    case 'book':
      return Colors.indigo;
    default:
      return Colors.blueGrey;
  }
}
