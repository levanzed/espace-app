import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/quiz_draft.dart';

/// Device-local question bank (Phase 1B). Not Moodle's question bank.
class LocalQuestionBank {
  LocalQuestionBank();

  static const _key = 'quiz_studio_local_bank_v1';

  Future<List<QuizQuestionDraft>> list({String query = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    final list = (jsonDecode(raw) as List)
        .map((e) => QuizQuestionDraft.fromDraftJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list
        .where((item) => item.stem.toLowerCase().contains(q))
        .toList();
  }

  Future<void> saveQuestion(QuizQuestionDraft question) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await list();
    final copy = question.duplicate();
    // Keep a stable bank id separate from canvas instance.
    final updated = [
      copy,
      ...existing.where((e) => e.stem != copy.stem || e.type != copy.type),
    ];
    await prefs.setString(
      _key,
      jsonEncode(updated.map((e) => e.toDraftJson()).toList()),
    );
  }

  Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await list();
    final updated = existing.where((e) => e.id != id).toList();
    await prefs.setString(
      _key,
      jsonEncode(updated.map((e) => e.toDraftJson()).toList()),
    );
  }
}
