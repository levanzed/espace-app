import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/academic/data/academic_repository.dart';
import '../../features/activity/data/activity_repository.dart';
import '../../features/courses/data/courses_repository.dart';
import '../api/authenticated_api.dart';

final authenticatedApiProvider = Provider<AuthenticatedApi>((ref) {
  return AuthenticatedApi();
});

final coursesRepositoryProvider = Provider<CoursesRepository>((ref) {
  return CoursesRepository(api: ref.watch(authenticatedApiProvider));
});

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository(api: ref.watch(authenticatedApiProvider));
});

final academicRepositoryProvider = Provider<AcademicRepository>((ref) {
  return AcademicRepository(api: ref.watch(authenticatedApiProvider));
});
