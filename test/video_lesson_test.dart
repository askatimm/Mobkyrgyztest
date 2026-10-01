import 'package:flutter_test/flutter_test.dart';
import 'package:kyrgyztestapp/models/video_lesson.dart';
import 'package:kyrgyztestapp/models/video_taxonomy.dart';

void main() {
  group('VideoLesson', () {
    test('parses metadata and localized values', () {
      final lesson = VideoLesson.fromMap({
        'level': 'a1',
        'sphere': 'personal',
        'section': 'greeting',
        'title': 'Саламдашуу',
        'titleRu': 'Приветствие',
        'description': 'Кыргызча сүрөттөмө',
        'descriptionRu': 'Описание на русском',
        'thumbnailUrl':
            'https://media.kyrgyztest.kg/videos/A1/personal/greeting/001.jpg?X-Amz-Signature=test',
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

    test('rejects thumbnails outside the configured MinIO host', () {
      final lesson = VideoLesson.fromMap({
        'level': 'A1',
        'sphere': 'personal',
        'section': 'greeting',
        'title': 'Саламдашуу',
        'description': '',
        'thumbnailUrl': 'https://example.com/001.jpg',
        'duration': 180,
        'order': 1,
        'isActive': true,
      });

      expect(lesson.hasRequiredMedia, isFalse);
    });
  });

  test('personal sphere contains the six required sections', () {
    final sections = VideoTaxonomy.knownSections['personal']!;

    expect(
      sections.map((section) => section.code),
      containsAll(<String>[
        'greeting',
        'farewell',
        'address',
        'congratulations',
        'wishes',
        'introduction',
      ]),
    );
    expect(sections, hasLength(6));
  });
}
