import '../../../core/api/authenticated_api.dart';

class AcademicRepository {
  AcademicRepository({AuthenticatedApi? api}) : _api = api ?? AuthenticatedApi();

  final AuthenticatedApi _api;

  Future<Map<String, dynamic>> getGradesOverview() async {
    final response = await _api.get('/grades/overview');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getCourseGrades(int courseId) async {
    final response = await _api.get('/courses/$courseId/grades');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getUpcomingCalendar() async {
    final response = await _api.get('/calendar/upcoming');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getNotifications() async {
    final response = await _api.get('/messages/notifications');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getConversations() async {
    final response = await _api.get('/messages/conversations');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getDraftItemId() async {
    final response = await _api.get('/files/draft-itemid');
    return Map<String, dynamic>.from(response.data as Map);
  }
}
