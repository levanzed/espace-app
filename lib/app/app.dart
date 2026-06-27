import 'package:flutter/material.dart';

import '../core/theme/theme.dart';
import 'router.dart';

class EspaceApp extends StatelessWidget {
  const EspaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LevanzEd',
      debugShowCheckedModeBanner: false,
      theme: espaceLightTheme,
      routerConfig: appRouter,
    );
  }
}