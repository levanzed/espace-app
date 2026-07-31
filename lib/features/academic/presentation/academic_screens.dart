import 'package:flutter/material.dart';

import '../data/academic_repository.dart';

class GradesScreen extends StatelessWidget {
  const GradesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = AcademicRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Grades overview')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: repository.getGradesOverview(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final grades = List<dynamic>.from(snapshot.data?['grades'] ?? const []);
          if (grades.isEmpty) {
            return const Center(child: Text('No course grades yet'));
          }

          return ListView.builder(
            itemCount: grades.length,
            itemBuilder: (context, index) {
              final grade = Map<String, dynamic>.from(grades[index] as Map);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.grade_outlined),
                  title: Text(grade['courseid']?.toString() ?? 'Course'),
                  subtitle: Text(grade['grade']?.toString() ?? '-'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = AcademicRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: repository.getUpcomingCalendar(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final events = List<dynamic>.from(
            snapshot.data?['events'] ?? const [],
          );
          if (events.isEmpty) {
            return const Center(child: Text('No upcoming events'));
          }

          return ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = Map<String, dynamic>.from(events[index] as Map);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text(event['name']?.toString() ?? 'Event'),
                  subtitle: Text(event['description']?.toString() ?? ''),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
