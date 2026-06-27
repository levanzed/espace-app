import 'package:flutter/material.dart';
import '../../activity/presentation/activity_screen.dart';
import '../data/courses_repository.dart';

class CourseScreen extends StatefulWidget {
  final int courseId;

  const CourseScreen({super.key, required this.courseId});

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  final CoursesRepository _repository = CoursesRepository();

  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.getCourseContents(widget.courseId);
  }

  IconData _icon(String type) {
    switch (type) {
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

      default:
        return Icons.description_rounded;
    }
  }

  Color _color(String type) {
    switch (type) {
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
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F8FA),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),

      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final sections = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: sections.length,
            itemBuilder: (context, index) {
              final section = sections[index];

              final modules = (section["modules"] as List<dynamic>? ?? []);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),

                  Text(
                    (section["name"] == null ||
                            section["name"].toString().trim().isEmpty)
                        ? "GENERAL"
                        : section["name"].toString().toUpperCase(),

                    style: const TextStyle(
                      fontSize: 14,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 14),

                  ...modules.map((module) {
                    final type = module["modname"];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        elevation: .4,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),

                          onTap: () {
                            final cmid = module["id"];

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ActivityScreen(cmid: cmid),
                              ),
                            );
                          },

                          child: Padding(
                            padding: const EdgeInsets.all(18),

                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,

                                  decoration: BoxDecoration(
                                    color: _color(type).withOpacity(.12),
                                    borderRadius: BorderRadius.circular(16),
                                  ),

                                  child: Icon(_icon(type), color: _color(type)),
                                ),

                                const SizedBox(width: 18),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,

                                    children: [
                                      Text(
                                        module["name"],

                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 17,
                                        ),
                                      ),

                                      const SizedBox(height: 5),

                                      Text(
                                        type.toUpperCase(),

                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                          letterSpacing: .5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 22),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
