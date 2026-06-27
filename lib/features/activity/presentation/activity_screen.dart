import 'package:flutter/material.dart';

import '../data/activity_repository.dart';
import '../models/activity.dart';
import '../renderers/renderer_registry.dart';

class ActivityScreen extends StatefulWidget {
  final int cmid;

  const ActivityScreen({
    super.key,
    required this.cmid,
  });

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final ActivityRepository _repository = ActivityRepository();

  late Future<Activity> _futureActivity;

  @override
  void initState() {
    super.initState();
    _futureActivity = _repository.getActivity(widget.cmid);
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
      body: FutureBuilder<Activity>(
        future: _futureActivity,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snapshot.error.toString()),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Activity not found'));
          }

          final activity = snapshot.data!;
          final renderer = RendererRegistry.get(activity.modname);

          return renderer.build(
            context,
            activity,
            repository: _repository,
          );
        },
      ),
    );
  }
}
