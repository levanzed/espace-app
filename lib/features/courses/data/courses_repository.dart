import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_storage.dart';

class CoursesRepository {
  final ApiClient _api = ApiClient();
  final SecureStorage _storage = SecureStorage();

  Future<List<dynamic>> getCourses() async {
    final token = await _storage.getToken();

    final response = await _api.dio.get(
      '/courses',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getCourseContents(int courseId) async {
    final token = await _storage.getToken();

    final response = await _api.dio.get(
      '/courses/$courseId',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    return response.data as List<dynamic>;
  }
}