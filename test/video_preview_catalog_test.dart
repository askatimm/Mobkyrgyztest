import 'package:flutter_test/flutter_test.dart';
import 'package:kyrgyztestapp/models/video_taxonomy.dart';
import 'package:kyrgyztestapp/preview/video_preview_catalog.dart';
import 'package:kyrgyztestapp/widgets/video_design.dart';

void main() {
  test('preview covers all five levels and all four spheres', () {
    final ids = <String>{};
    for (final level in VideoTaxonomy.levels) {
      for (final sphere in VideoTaxonomy.spheres) {
        final lessons = VideoPreviewCatalog.lessons(level: level, sphere: sphere.code);
        expect(lessons, isNotEmpty);
        for (final lesson in lessons) {
          expect(lesson.level, level);
          expect(lesson.sphere, sphere.code);
          expect(lesson.id, startsWith('preview-'));
          expect(ids.add(lesson.id), isTrue);
          expect(lesson.thumbnailUrl, isEmpty);
          expect(lesson.hasRequiredMedia, isFalse);
          expect(lesson.localizedTitle('ru'), isNotEmpty);
          expect(lesson.localizedTitle('ky'), isNotEmpty);
          expect(VideoPreviewCatalog.thumbnailFor(lesson), startsWith('assets/'));
        }
      }
    }
  });

  test('every preview section has an ordered playlist', () {
    for (final sphere in VideoTaxonomy.spheres) {
      final lessons = VideoPreviewCatalog.lessons(level: 'A1', sphere: sphere.code);
      for (final section in lessons.map((item) => item.section).toSet()) {
        expect(lessons.where((item) => item.section == section).map((item) => item.order), [1, 2, 3]);
      }
    }
  });

  test('durations support long lessons and invalid negative metadata', () {
    expect(videoDuration(234), '3:54');
    expect(videoDuration(3605), '1:00:05');
    expect(videoDuration(-1), '0:00');
  });
}
