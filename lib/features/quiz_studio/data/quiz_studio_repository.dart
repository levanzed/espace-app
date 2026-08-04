import 'package:dio/dio.dart';

import '../../../core/api/authenticated_api.dart';

/// Publish quizzes via the Phase 0 ESPACE API (no local persistence).
class QuizStudioRepository {
  QuizStudioRepository({AuthenticatedApi? api}) : _api = api ?? AuthenticatedApi();

  final AuthenticatedApi _api;

  /// Moodle quiz create + question bank writes can exceed the default 10s timeout.
  static const Duration _publishReceiveTimeout = Duration(seconds: 60);

  Future<Map<String, dynamic>> publishQuiz({
    required int courseId,
    required int sectionId,
    required Map<String, dynamic> body,
  }) async {
    final response = await _api.dio.post<dynamic>(
      '/courses/$courseId/sections/$sectionId/quiz/publish',
      data: body,
      options: await _api.authOptions(
        options: Options(receiveTimeout: _publishReceiveTimeout),
      ),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
