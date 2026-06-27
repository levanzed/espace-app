import 'package:flutter/material.dart';

class ActivityScreen extends StatelessWidget {
  final int cmid;

  const ActivityScreen({
    super.key,
    required this.cmid,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Activity $cmid"),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}