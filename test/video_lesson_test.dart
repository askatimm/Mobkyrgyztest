import 'package:flutter_test/flutter_test.dart';
import 'package:kyrgyztestapp/models/video_lesson.dart';
import 'package:kyrgyztestapp/models/video_taxonomy.dart';

void main() {
  group('VideoLesson', () {
    test('parses metadata and localized values', () {
      final lesson = VideoLesson.fromMap({
        'level': 'a1',
        'sphere': 'private',
        'section': 'greeting',
        'title': 'Саламдашуу',
        'titleRu': 'Приветствие',
        'description': 'Кыргызча сүрөттөмө',
        'descriptionRu': 'Описание на русском',
        'videoUrl':
            'https://media.kyrgyztest.kg/videos/A1/private/greeting/001.mp4',
        'thumbnailUrl':
            'https://media.kyrgyztest.kg/videos/A1/private/greeting/001.jpg',
        'duration': 180,
        'order': 1,
        'isActive': true,
      }, id: 'lesson-1');

      expect(lesson.id, 'lesson-1');
      expect(lesson.level, 'A1');
      expect(lesson.localizedTitle('ru'), 'Приветствие');
      expect(lesson.localizedTitle('ky'), 'Саламдашуу');
      expect(lesson.duration, 180);
      expect(lesson.hasRequiredMedia, isTrue);
    });

    test('rejects media outside the configured MinIO host', () {
      final lesson = VideoLesson.fromMap({
        'level': 'A1',
        'sphere': 'private',
        'section': 'greeting',
        'title': 'Саламдашуу',
        'description': '',
        'videoUrl': 'https://example.com/001.mp4',
        'thumbnailUrl': 'https://media.kyrgyztest.kg/001.jpg',
        'duration': 180,
        'order': 1,
        'isActive': true,
      });

      expect(lesson.hasRequiredMedia, isFalse);
    });
  });

  test('private sphere contains the six required sections', () {
    final sections = VideoTaxonomy.knownSections['private']!;

    expect(
      sections.map((section) => section.code),
      containsAll(<String>[
        'greeting',
        'farewell',
        'address',
        'congratulations',
        'wishes',
        'acquaintance',
      ]),
    );
    expect(sections, hasLength(6));
  });
}
