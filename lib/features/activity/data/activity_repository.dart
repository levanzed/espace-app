import 'package:dio/dio.dart';

import '../models/activity.dart';
import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_storage.dart';

class ActivityRepository {
  final ApiClient _api = ApiClient();
  final SecureStorage _storage = SecureStorage();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {'Authorization': 'Bearer $token'};
  }

  Future<Activity> getActivity(int cmid) async {
    final response = await _api.dio.get(
      '/activity/$cmid',
      options: Options(headers: await _authHeaders()),
    );

    return Activity.fromJson(
      Map<String, dynamic>.from(response.data),
    );
  }

  Future<Map<String, dynamic>> getForumDiscussions(int cmid) async {
    final response = await _api.dio.get(
      '/activity/$cmid/forum/discussions',
      options: Options(headers: await _authHeaders()),
    );

    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> getForumDiscussionPosts(
    int cmid,
    int discussionId,
  ) async {
    final response = await _api.dio.get(
      '/activity/$cmid/forum/discussions/$discussionId/posts',
      options: Options(headers: await _authHeaders()),
    );

    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> getAssignStatus(int cmid) async {
    final response = await _api.dio.get(
      '/activity/$cmid/assign/status',
      options: Options(headers: await _authHeaders()),
    );

    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> getQuizAttempts(int cmid) async {
    final response = await _api.dio.get(
      '/activity/$cmid/quiz/attempts',
      options: Options(headers: await _authHeaders()),
    );

    return Map<String, dynamic>.from(response.data);
  }
}
