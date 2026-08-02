import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import 'assign_grade_screen.dart';

class AssignParticipantsScreen extends StatefulWidget {
  const AssignParticipantsScreen({
    super.key,
    required this.cmid,
    required this.activityName,
    this.repository,
  });

  final int cmid;
  final String activityName;
  final ActivityRepository? repository;

  @override
  State<AssignParticipantsScreen> createState() =>
      _AssignParticipantsScreenState();
}

class _AssignParticipantsScreenState extends State<AssignParticipantsScreen> {
  late final ActivityRepository _repository =
      widget.repository ?? ActivityRepository();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _repository.getAssignParticipants(widget.cmid);
  }

  Future<void> _openStudent(Map<String, dynamic> participant) async {
    final userId = int.tryParse(participant['id']?.toString() ?? '');
    if (userId == null) return;
    final name = participant['fullname']?.toString() ?? 'Student';

    final refreshed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AssignGradeScreen(
          cmid: widget.cmid,
          userid: userId,
          studentName: name,
          repository: _repository,
        ),
      ),
    );
    if (refreshed == true && mounted) {
      setState(_reload);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F8FA),
      appBar: AppBar(
        title: Text(widget.activityName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final data = snapshot.data ?? const {};
          final participants = List<dynamic>.from(data['participants'] ?? const []);

          if (participants.isEmpty) {
            return const Center(child: Text('No participants found'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              await _future;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: participants.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = Map<String, dynamic>.from(
                  participants[index] as Map,
                );
                final name = row['fullname']?.toString() ?? 'User ${row['id']}';
                final status = row['submissionstatus']?.toString() ?? '';
                final grading = row['gradingstatus']?.toString() ?? '';
                final modified = int.tryParse(row['timemodified']?.toString() ?? '');

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                      ),
                    ),
                    title: Text(name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (status.isNotEmpty)
                          Text('Submission: ${status.replaceAll('_', ' ')}'),
                        if (grading.isNotEmpty) Text('Grading: $grading'),
                        if (modified != null && modified > 0)
                          Text('Submitted: ${_formatTs(modified)}'),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openStudent(row),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatTs(int ts) {
    final date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
