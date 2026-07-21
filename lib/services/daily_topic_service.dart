import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DailyTopicService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<String>> getTodayTaskIds({
    required String levelId,
    required String subTestId,
  }) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    final dailyDocRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('daily_topics')
        .doc('${levelId}_$subTestId');

    final dailyDoc = await dailyDocRef.get();

    // ✅ Проверка по серверному времени
    if (dailyDoc.exists) {
      final data = dailyDoc.data()!;
      final Timestamp? createdAt = data['createdAt'];

      if (createdAt != null) {
        final last = createdAt.toDate().toUtc();
        final now = DateTime.now().toUtc();

        final isSameDay =
            now.year == last.year &&
            now.month == last.month &&
            now.day == last.day;

        if (isSameDay) {
          return List<String>.from(data['taskIds'] ?? []);
        }
      }
    }

    // 🔹 Загружаем все задания
    final tasksSnapshot = await _firestore
        .collection('levels')
        .doc(levelId)
        .collection('sub_tests')
        .doc(subTestId)
        .collection('tasks')
        .where('isActive', isEqualTo: true)
        .get();

    // 🔹 Загружаем ВСЕ stats одним запросом (быстро)
    final statsSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('topic_stats')
        .get();

    final statsMap = {
      for (var doc in statsSnapshot.docs) doc.id: doc.data()['shownCount'] ?? 0,
    };

    // 🔹 Фильтр по лимитам
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> availableDocs = [];

    for (final doc in tasksSnapshot.docs) {
      final data = doc.data();
      final maxShows = data['maxShows'] ?? 3;

      final shownCount = statsMap[doc.id] ?? 0;

      if (shownCount < maxShows) {
        availableDocs.add(doc);
      }
    }

    List<QueryDocumentSnapshot<Map<String, dynamic>>> usableDocs =
        availableDocs;

    // 🔁 Если все лимиты закончились — сброс
    if (usableDocs.isEmpty) {

      final statsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('topic_stats')
          .get();

      for (final statDoc in statsSnapshot.docs) {

        await statDoc.reference.set({'shownCount': 0}, SetOptions(merge: true));
      }

      usableDocs = tasksSnapshot.docs;
    }

    // 🎲 Случайные 5 тем
    usableDocs.shuffle(Random());
    final selectedDocs = usableDocs.take(5).toList();

    // 🔢 Увеличиваем счетчики
    for (final doc in selectedDocs) {
      final statRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('topic_stats')
          .doc(doc.id);

      final currentCount = statsMap[doc.id] ?? 0;

      await statRef.set({
        'shownCount': currentCount + 1,
        'lastShownAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final taskIds = selectedDocs.map((doc) => doc.id).toList();

    // ✅ Сохраняем с serverTimestamp (ключевой момент)
    await dailyDocRef.set({
      'taskIds': taskIds,
      'completedTaskIds': [], // 👈 добавили
      'createdAt': FieldValue.serverTimestamp(),
    });

    return taskIds;
  }
}
