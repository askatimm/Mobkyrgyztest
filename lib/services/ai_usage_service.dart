import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/ai_usage.dart';

class AiUsageService {
  static const int maxChecksPerTopic = 4;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _usageRef({
    required String userId,
    required String topicId,
  }) {
    return _firestore.collection('ai_usage').doc('${userId}_$topicId');
  }

  AiUsage _usageFromData({
    required String userId,
    required String topicId,
    Map<String, dynamic>? data,
  }) {
    final rawUsedChecks = data?['usedChecks'];
    final usedChecks = rawUsedChecks is num ? rawUsedChecks.toInt() : 0;

    return AiUsage(
      usedChecks: usedChecks.clamp(0, maxChecksPerTopic).toInt(),
      maxChecks: maxChecksPerTopic,
      isPremium: data?['isPremium'] == true,
      topicId: topicId,
      userId: userId,
    );
  }

  Future<AiUsage> getUsage({required String topicId}) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final doc = await _usageRef(userId: userId, topicId: topicId).get();

    return _usageFromData(
      userId: userId,
      topicId: topicId,
      data: doc.data(),
    );
  }

  Future<bool> canUseAi({required String topicId}) async {
    final usage = await getUsage(topicId: topicId);
    return usage.usedChecks < maxChecksPerTopic;
  }

  /// Атомарно резервирует одну AI-проверку.
  /// Возвращает обновлённый счётчик или null, если лимит уже исчерпан.
  Future<AiUsage?> tryConsumeCheck({required String topicId}) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final ref = _usageRef(userId: userId, topicId: topicId);

    return _firestore.runTransaction<AiUsage?>((transaction) async {
      final snapshot = await transaction.get(ref);
      final current = _usageFromData(
        userId: userId,
        topicId: topicId,
        data: snapshot.data(),
      );

      if (current.usedChecks >= maxChecksPerTopic) {
        return null;
      }

      final updated = current.copyWith(
        usedChecks: current.usedChecks + 1,
        maxChecks: maxChecksPerTopic,
      );

      transaction.set(ref, {
        ...updated.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return updated;
    });
  }

  Future<void> increaseUsage({required String topicId}) async {
    await tryConsumeCheck(topicId: topicId);
  }
}
