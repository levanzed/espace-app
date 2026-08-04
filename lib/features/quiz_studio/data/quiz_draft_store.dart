import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/quiz_draft.dart';

/// Local persistence for Quiz Studio drafts (Phase 1B).
///
/// Drafts never round-trip through Moodle. Keys are scoped per device.
class QuizDraftStore {
  QuizDraftStore();

  static const _indexKey = 'quiz_studio_draft_ids_v1';
  static String _draftKey(String id) => 'quiz_studio_draft_v1_$id';

  Future<List<QuizDraft>> listDrafts({int? courseId}) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_indexKey) ?? const [];
    final drafts = <QuizDraft>[];
    for (final id in ids) {
      final raw = prefs.getString(_draftKey(id));
      if (raw == null) continue;
      try {
        final draft = QuizDraft.fromDraftJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
        if (courseId != null && draft.courseId != null && draft.courseId != courseId) {
          continue;
        }
        drafts.add(draft);
      } catch (_) {
        // Skip corrupt entries.
      }
    }
    drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return drafts;
  }

  Future<QuizDraft?> load(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey(id));
    if (raw == null) return null;
    return QuizDraft.fromDraftJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  Future<void> save(QuizDraft draft) async {
    draft.touch();
    final prefs = await SharedPreferences.getInstance();
    final ids = List<String>.from(prefs.getStringList(_indexKey) ?? const []);
    if (!ids.contains(draft.id)) {
      ids.insert(0, draft.id);
      await prefs.setStringList(_indexKey, ids);
    }
    await prefs.setString(_draftKey(draft.id), jsonEncode(draft.toDraftJson()));
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = List<String>.from(prefs.getStringList(_indexKey) ?? const []);
    ids.remove(id);
    await prefs.setStringList(_indexKey, ids);
    await prefs.remove(_draftKey(id));
  }
}
