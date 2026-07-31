import 'package:go_router/go_router.dart';

import '../features/academic/presentation/academic_screens.dart';
import '../features/authentication/presentation/login_screen.dart';
import '../features/courses/presentation/course_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/course/:id',
      builder: (context, state) => CourseScreen(
        courseId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/grades',
      builder: (context, state) => const GradesScreen(),
    ),
    GoRoute(
      path: '/calendar',
      builder: (context, state) => const CalendarScreen(),
    ),
  ],
);
