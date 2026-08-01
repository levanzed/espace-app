import '../../../core/api/authenticated_api.dart';

class CoursesRepository {
  CoursesRepository({AuthenticatedApi? api}) : _api = api ?? AuthenticatedApi();

  final AuthenticatedApi _api;

  Future<List<dynamic>> getCourses() async {
    final response = await _api.get('/courses');
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getCourseContents(int courseId) async {
    final response = await _api.get('/courses/$courseId');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getAdministration(int courseId) async {
    final response = await _api.get('/courses/$courseId/administration');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<dynamic>> getCategories() async {
    final response = await _api.get('/courses/categories');
    return response.data as List<dynamic>;
  }

  Future<dynamic> createCourse({
    required String fullname,
    required String shortname,
    int categoryid = 1,
    String summary = '',
  }) async {
    final response = await _api.post('/courses', data: {
      'fullname': fullname,
      'shortname': shortname,
      'categoryid': categoryid,
      'summary': summary,
    });
    return response.data;
  }

  Future<dynamic> updateCourse(
    int courseId, {
    String? fullname,
    String? shortname,
    String? summary,
    int? visible,
  }) async {
    final response = await _api.patch('/courses/$courseId', data: {
      if (fullname != null) 'fullname': fullname,
      if (shortname != null) 'shortname': shortname,
      if (summary != null) 'summary': summary,
      if (visible != null) 'visible': visible,
    });
    return response.data;
  }

  Future<dynamic> deleteCourse(int courseId) async {
    final response = await _api.delete('/courses/$courseId');
    return response.data;
  }

  Future<dynamic> duplicateCourse(
    int courseId, {
    required String fullname,
    required String shortname,
  }) async {
    final response = await _api.post('/courses/$courseId/duplicate', data: {
      'fullname': fullname,
      'shortname': shortname,
    });
    return response.data;
  }

  Future<dynamic> sectionAction(
    int courseId, {
    required String action,
    List<int> sectionIds = const [],
    int? targetSectionId,
    String? name,
    String? summary,
    int summaryformat = 1,
  }) async {
    final response = await _api.post('/courses/$courseId/sections', data: {
      'action': action,
      'section_ids': sectionIds,
      'target_section_id': targetSectionId,
      if (name != null) 'name': name,
      if (summary != null) 'summary': summary,
      'summaryformat': summaryformat,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> renameSection(
    int courseId,
    int sectionId, {
    String? name,
    String? summary,
    int summaryformat = 1,
  }) async {
    final response = await _api.post(
      '/courses/$courseId/sections/$sectionId/rename',
      data: {
        if (name != null) 'name': name,
        if (summary != null) 'summary': summary,
        'summaryformat': summaryformat,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<dynamic> moduleAction(
    int courseId, {
    required String action,
    required int cmid,
    int? targetSectionId,
    int? targetCmid,
  }) async {
    final response = await _api.post('/courses/$courseId/modules/actions', data: {
      'action': action,
      'cmid': cmid,
      'target_section_id': targetSectionId,
      'target_cmid': targetCmid,
    });
    return response.data;
  }

  Future<dynamic> createModule(
    int courseId, {
    required String modname,
    required int sectionId,
  }) async {
    final response = await _api.post('/courses/$courseId/modules', data: {
      'modname': modname,
      'section_id': sectionId,
    });
    return response.data;
  }

  /// Create an activity via Activities API (Sprint A: assign).
  Future<Map<String, dynamic>> createActivity(
    int courseId, {
    required int sectionId,
    required String modname,
    required Map<String, dynamic> settings,
  }) async {
    final response = await _api.post(
      '/courses/$courseId/sections/$sectionId/activities',
      data: {
        'modname': modname,
        'settings': settings,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Update activity authoring settings.
  Future<Map<String, dynamic>> updateActivity(
    int courseId,
    int cmid, {
    required Map<String, dynamic> settings,
  }) async {
    final response = await _api.put(
      '/courses/$courseId/activities/$cmid',
      data: {'settings': settings},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Load authoring settings for the editor.
  Future<Map<String, dynamic>> getActivityAuthoring(
    int courseId,
    int cmid,
  ) async {
    final response = await _api.get('/courses/$courseId/activities/$cmid');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<dynamic>> getParticipants(int courseId) async {
    final response = await _api.get('/courses/$courseId/participants');
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getGroups(int courseId) async {
    final response = await _api.get('/courses/$courseId/groups');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getCompletion(int courseId) async {
    final response = await _api.get('/courses/$courseId/completion');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getGrades(int courseId) async {
    final response = await _api.get('/courses/$courseId/grades');
    return Map<String, dynamic>.from(response.data as Map);
  }
}
