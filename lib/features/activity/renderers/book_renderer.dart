import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_renderer.dart';
import 'widgets/activity_layout.dart';
import 'widgets/html_content.dart';

class BookRenderer extends ActivityRenderer {
  const BookRenderer();

  @override
  Widget build(
    BuildContext context,
    Activity activity, {
    ActivityRepository? repository,
  }) {
    final chapters = List<dynamic>.from(
      activity.details['chapters'] as List? ?? const [],
    );

    return ActivityLayout(
      activity: activity,
      children: [
        HtmlContent(html: activity.description),
        const SizedBox(height: 20),
        if (chapters.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.menu_book_rounded),
              title: Text('No chapters available yet'),
            ),
          )
        else
          ...chapters.map((chapter) {
            final map = Map<String, dynamic>.from(chapter as Map);
            final title = map['title']?.toString() ??
                map['name']?.toString() ??
                'Chapter';
            final contents = map['contents'];
            final contentHtml = contents is List && contents.isNotEmpty
                ? Map<String, dynamic>.from(contents.first as Map)['content']
                        ?.toString() ??
                    ''
                : map['content']?.toString() ?? map['intro']?.toString() ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(title),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: HtmlContent(html: contentHtml),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
