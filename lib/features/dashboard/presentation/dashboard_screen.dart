import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Courses")),
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

          return ListView.builder(
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.school),
                  title: Text(course["name"]),
                  subtitle: Text(course["shortname"]),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/course/${course["id"]}');
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
