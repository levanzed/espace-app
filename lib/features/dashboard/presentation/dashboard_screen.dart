import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../courses/data/courses_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final CoursesRepository _repository = CoursesRepository();

  late Future<List<dynamic>> _courses;

  @override
  void initState() {
    super.initState();
    _courses = _repository.getCourses();
  }

  Future<void> _createCourseDialog() async {
    final nameController = TextEditingController();
    final shortController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create course'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              TextField(
                controller: shortController,
                decoration: const InputDecoration(labelText: 'Short name'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (created != true) return;

    try {
      await _repository.createCourse(
        fullname: nameController.text.trim(),
        shortname: shortController.text.trim(),
      );
      setState(() => _courses = _repository.getCourses());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Courses'),
        actions: [
          IconButton(
            tooltip: 'Calendar',
            onPressed: () => context.push('/calendar'),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          IconButton(
            tooltip: 'Grades',
            onPressed: () => context.push('/grades'),
            icon: const Icon(Icons.grade_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCourseDialog,
        icon: const Icon(Icons.add),
        label: const Text('Course'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _courses,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final courses = snapshot.data!;

          if (courses.isEmpty) {
            return const Center(child: Text('No enrolled courses'));
          }

          return ListView.builder(
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.school),
                  title: Text(course['name']?.toString() ?? ''),
                  subtitle: Text(course['shortname']?.toString() ?? ''),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      final id = course['id'] as int;
                      try {
                        if (value == 'duplicate') {
                          await _repository.duplicateCourse(
                            id,
                            fullname: '${course['name']} (copy)',
                            shortname: '${course['shortname']}_copy',
                          );
                          setState(() => _courses = _repository.getCourses());
                        } else if (value == 'delete') {
                          await _repository.deleteCourse(id);
                          setState(() => _courses = _repository.getCourses());
                        }
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                  onTap: () {
                    context.push('/course/${course['id']}');
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
