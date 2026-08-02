import '../models/activity.dart';
import '../../../core/api/authenticated_api.dart';

class ActivityRepository {
  ActivityRepository({AuthenticatedApi? api}) : _api = api ?? AuthenticatedApi();

  final AuthenticatedApi _api;

  Future<Activity> getActivity(int cmid) async {
    final response = await _api.get('/activity/$cmid');
    return Activity.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<Map<String, dynamic>> getForumDiscussions(int cmid) async {
    final response = await _api.get('/activity/$cmid/forum/discussions');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getForumDiscussionPosts(
    int cmid,
    int discussionId,
  ) async {
    final response = await _api.get(
      '/activity/$cmid/forum/discussions/$discussionId/posts',
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> createForumDiscussion(
    int cmid, {
    required String subject,
    required String message,
  }) async {
    final response = await _api.post(
      '/activity/$cmid/forum/discussions',
      data: {'subject': subject, 'message': message},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> replyForumPost(
    int cmid,
    int postId, {
    required String subject,
    required String message,
  }) async {
    final response = await _api.post(
      '/activity/$cmid/forum/posts/$postId/reply',
      data: {'subject': subject, 'message': message},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> deleteForumPost(int cmid, int postId) async {
    await _api.delete('/activity/$cmid/forum/posts/$postId');
  }

  Future<Map<String, dynamic>> getAssignStatus(int cmid) async {
    final response = await _api.get('/activity/$cmid/assign/status');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getAssignParticipants(int cmid) async {
    final response = await _api.get('/activity/$cmid/assign/participants');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getAssignStatusForUser(
    int cmid,
    int userid,
  ) async {
    final response = await _api.get(
      '/activity/$cmid/assign/status',
      queryParameters: {'userid': userid},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> saveAssignGrade(
    int cmid, {
    required int userid,
    required double grade,
    String feedbackText = '',
    int? feedbackDraftitemid,
    int attemptnumber = -1,
  }) async {
    await _api.post(
      '/activity/$cmid/assign/grades',
      data: {
        'userid': userid,
        'grade': grade,
        'attemptnumber': attemptnumber,
        'feedback_text': feedbackText,
        if (feedbackDraftitemid != null)
          'feedback_draftitemid': feedbackDraftitemid,
      },
    );
  }

  Future<dynamic> saveAssignSubmission(
    int cmid, {
    String? onlinetext,
    int? draftitemid,
  }) async {
    final response = await _api.post(
      '/activity/$cmid/assign/submission',
      data: {
        if (onlinetext != null) 'onlinetext': onlinetext,
        if (draftitemid != null) 'draftitemid': draftitemid,
      },
    );
    return response.data;
  }

  Future<dynamic> submitAssign(
    int cmid, {
    bool acceptSubmissionStatement = false,
  }) async {
    final response = await _api.post(
      '/activity/$cmid/assign/submit',
      data: {
        'accept_submission_statement': acceptSubmissionStatement,
      },
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getQuizAttempts(int cmid) async {
    final response = await _api.get('/activity/$cmid/quiz/attempts');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> startQuizAttempt(int cmid) async {
    final response = await _api.post('/activity/$cmid/quiz/attempts');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getQuizAttemptData(
    int cmid,
    int attemptId, {
    int page = 0,
  }) async {
    final response = await _api.get(
      '/activity/$cmid/quiz/attempts/$attemptId',
      queryParameters: {'page': page},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> processQuizAttempt(
    int cmid,
    int attemptId, {
    List<Map<String, dynamic>> data = const [],
    int finishattempt = 0,
  }) async {
    final response = await _api.post(
      '/activity/$cmid/quiz/attempts/$attemptId/process',
      data: {
        'data': data,
        'finishattempt': finishattempt,
        'timeup': 0,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> reviewQuizAttempt(
    int cmid,
    int attemptId,
  ) async {
    final response =
        await _api.get('/activity/$cmid/quiz/attempts/$attemptId/review');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getChoiceOptions(int cmid) async {
    final response = await _api.get('/activity/$cmid/choice/options');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<dynamic> submitChoice(int cmid, List<int> responses) async {
    final response = await _api.post(
      '/activity/$cmid/choice/submit',
      data: {'responses': responses},
    );
    return response.data;
  }

  Future<dynamic> markCompletion(int cmid, {bool completed = true}) async {
    final response = await _api.post(
      '/activity/$cmid/completion',
      data: {'completed': completed},
    );
    return response.data;
  }

  // ---- Teacher authoring file helpers (Activity subsystem) ----

  /// Moodle user draft area descriptor from GET /files/draft-itemid.
  Future<Map<String, dynamic>> getDraftItemId() async {
    final response = await _api.get('/files/draft-itemid');
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Upload base64 content into a Moodle draft (or other) file area.
  Future<Map<String, dynamic>> uploadDraftFile({
    required String filecontentBase64,
    required String filename,
    required int contextid,
    required int itemid,
    String component = 'user',
    String filearea = 'draft',
    String filepath = '/',
  }) async {
    final response = await _api.post(
      '/files/upload',
      data: {
        'filecontent_base64': filecontentBase64,
        'filename': filename,
        'contextid': contextid,
        'component': component,
        'filearea': filearea,
        'itemid': itemid,
        'filepath': filepath,
      },
    );
    return Map<String, dynamic>.from(response.data as Map? ?? {});
  }
}
