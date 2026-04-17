import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/ai_usage.dart';

class AiUsageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<AiUsage> getUsage({
    required String topicId,
  }) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    final doc = await _firestore
        .collection('ai_usage')
        .doc('${userId}_$topicId')
        .get();

    if (!doc.exists) {
      return AiUsage(
        usedChecks: 0,
        maxChecks: 5,
        isPremium: false,
        topicId: topicId,
        userId: userId,
      );
    }

    return AiUsage.fromMap(doc.data()!);
  }

  Future<bool> canUseAi({
    required String topicId,
  }) async {
    final usage = await getUsage(topicId: topicId);
    return usage.canUseAi;
  }

  Future<void> increaseUsage({
    required String topicId,
  }) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    final usage = await getUsage(topicId: topicId);

    final updated = usage.copyWith(
      usedChecks: usage.usedChecks + 1,
    );

    await _firestore
        .collection('ai_usage')
        .doc('${userId}_$topicId')
        .set(updated.toMap());
  }
}