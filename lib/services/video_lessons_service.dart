import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/video_lesson.dart';

class VideoLessonsService {
  VideoLessonsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<VideoLesson>> watchActiveLessons({
    required String level,
    required String sphere,
  }) {
    return _firestore
        .collection('videos')
        .where('level', isEqualTo: level)
        .where('sphere', isEqualTo: sphere)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final lessons = snapshot.docs
              .map(
                (document) => VideoLesson.fromMap(
                  document.data(),
                  id: document.id,
                ),
              )
              .where((lesson) => lesson.hasRequiredMedia)
              .toList();

          lessons.sort((first, second) {
            final orderComparison = first.order.compareTo(second.order);
            if (orderComparison != 0) return orderComparison;
            return first.title.compareTo(second.title);
          });

          return lessons;
        });
  }
}
