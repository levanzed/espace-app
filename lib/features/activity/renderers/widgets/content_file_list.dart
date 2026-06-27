import 'package:flutter/material.dart';

import 'activity_utils.dart';

class ContentFileList extends StatelessWidget {
  final List<dynamic> contents;
  final String emptyMessage;

  const ContentFileList({
    super.key,
    required this.contents,
    this.emptyMessage = 'No files available',
  });

  @override
  Widget build(BuildContext context) {
    if (contents.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(emptyMessage),
        ),
      );
    }

    return Column(
      children: contents.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final filename = map['filename']?.toString() ?? 'Open file';
        final fileurl = map['fileurl']?.toString();
        final mimetype = map['mimetype']?.toString() ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(_iconForMime(mimetype)),
            title: Text(filename),
            subtitle: mimetype.isNotEmpty ? Text(mimetype) : null,
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: fileurl == null ? null : () => openExternalUrl(fileurl),
          ),
        );
      }).toList(),
    );
  }

  IconData _iconForMime(String mimetype) {
    if (mimetype.contains('pdf')) {
      return Icons.picture_as_pdf_rounded;
    }
    if (mimetype.startsWith('video/')) {
      return Icons.play_circle_outline_rounded;
    }
    if (mimetype.startsWith('audio/')) {
      return Icons.audiotrack_rounded;
    }
    if (mimetype.startsWith('image/')) {
      return Icons.image_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }
}
