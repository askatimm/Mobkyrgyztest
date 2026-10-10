import 'package:cloud_functions/cloud_functions.dart';

import '../models/video_lesson.dart';

class VideoLessonsService {
  VideoLessonsService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<VideoLessonCatalog> fetchActiveLessons({
    required String level,
    required String sphere,
  }) async {
    try {
      final result = await _functions.httpsCallable('getVideoLessons').call({
        'level': level,
        'sphere': sphere,
      });
      final payload = Map<String, dynamic>.from(result.data as Map);
      final rows = (payload['lessons'] as List? ?? const <Object>[]);

      final lessons = rows
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map(
            (row) => VideoLesson.fromMap(
              row,
              id: row['id']?.toString() ?? '',
            ),
          )
          .where((lesson) => lesson.hasRequiredMedia)
          .toList();
      final levels = (payload['availableLevels'] as List? ?? const <Object>[])
          .map((value) => value.toString())
          .where((value) => const ['A1', 'A2', 'B1', 'B2', 'C1'].contains(value))
          .toList();
      // Older deployments do not send availableLevels yet.
      if (levels.isEmpty && lessons.isNotEmpty) levels.add(level);
      return VideoLessonCatalog(lessons: lessons, availableLevels: levels);
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'unauthenticated') {
        throw const VideoSignInRequiredException();
      }
      if (error.code == 'permission-denied') {
        throw const VideoPremiumRequiredException();
      }
      rethrow;
    }
  }

  Future<Uri> fetchPlaybackUri(String videoId) async {
    try {
      final result = await _functions
          .httpsCallable('getVideoPlaybackUrl')
          .call({'videoId': videoId});
      final payload = Map<String, dynamic>.from(result.data as Map);
      final uri = Uri.tryParse(payload['url']?.toString() ?? '');

      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.toLowerCase() != 'media.kyrgyztest.kg') {
        throw const FormatException('Invalid video playback URL');
      }
      return uri;
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'unauthenticated') {
        throw const VideoSignInRequiredException();
      }
      if (error.code == 'permission-denied') {
        throw const VideoPremiumRequiredException();
      }
      rethrow;
    }
  }
}

class VideoPremiumRequiredException implements Exception {
  const VideoPremiumRequiredException();
}

class VideoSignInRequiredException implements Exception {
  const VideoSignInRequiredException();
}

class VideoLessonCatalog {
  const VideoLessonCatalog({required this.lessons, required this.availableLevels});

  final List<VideoLesson> lessons;
  final List<String> availableLevels;
}
