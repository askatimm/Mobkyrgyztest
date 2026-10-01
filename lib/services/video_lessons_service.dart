import 'package:cloud_functions/cloud_functions.dart';

import '../models/video_lesson.dart';

class VideoLessonsService {
  VideoLessonsService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<List<VideoLesson>> fetchActiveLessons({
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

      return rows
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map(
            (row) => VideoLesson.fromMap(
              row,
              id: row['id']?.toString() ?? '',
            ),
          )
          .where((lesson) => lesson.hasRequiredMedia)
          .toList();
    } on FirebaseFunctionsException catch (error) {
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
