import '../models/video_lesson.dart';
import '../models/video_taxonomy.dart';

/// Illustrative content only; never saved to Firestore or served in production.
abstract final class VideoPreviewCatalog {
  static const Map<String, List<VideoSectionOption>> sections = {
    'professional': [
      VideoSectionOption(code: 'workplace', ky: 'Жумуш ордунда', ru: 'На работе'),
      VideoSectionOption(code: 'meeting', ky: 'Иш жолугушуусу', ru: 'Деловая встреча'),
    ],
    'social_cultural': [
      VideoSectionOption(code: 'traditions', ky: 'Каада-салттар', ru: 'Традиции'),
      VideoSectionOption(code: 'culture', ky: 'Маданият', ru: 'Культура'),
    ],
    'educational': [
      VideoSectionOption(code: 'classroom', ky: 'Сабакта', ru: 'На занятии'),
      VideoSectionOption(code: 'learning', ky: 'Билим алуу', ru: 'Обучение'),
    ],
  };

  static List<VideoLesson> lessons({
    required String level,
    required String sphere,
  }) {
    final topics = VideoTaxonomy.knownSections[sphere] ?? sections[sphere] ?? [];
    return [
      for (final topic in topics)
        for (var index = 0; index < 3; index++)
          VideoLesson(
            id: 'preview-$level-$sphere-${topic.code}-$index',
            level: level,
            sphere: sphere,
            section: topic.code,
            title: topic.ky,
            titleKy: index == 0
                ? '${topic.ky}: алгачкы кадам'
                : index == 1
                    ? '${topic.ky}: диалог'
                    : '${topic.ky}: өз алдынча машыгуу',
            titleRu: index == 0
                ? '${topic.ru}: первые шаги'
                : index == 1
                    ? '${topic.ru}: диалог'
                    : '${topic.ru}: самостоятельная практика',
            description: 'Бул — дизайнды текшерүү үчүн үлгү сабак.',
            descriptionKy: 'Бул — дизайнды текшерүү үчүн үлгү сабак. '
                'Сөздөрдү угуп, сүйлөмдөрдү кайталап, аларды күнүмдүк '
                'баарлашууда колдонуп үйрөнүңүз.',
            descriptionRu: 'Это пример урока для проверки дизайна. '
                'В настоящем уроке вы сможете слушать речь, повторять '
                'фразы и применять их в повседневном общении.',
            sectionTitleKy: topic.ky,
            sectionTitleRu: topic.ru,
            thumbnailUrl: '',
            duration: [234, 318, 186][index],
            order: index + 1,
            isActive: true,
          ),
    ];
  }

  static String thumbnailFor(VideoLesson lesson) {
    return switch (lesson.sphere) {
      'professional' => 'assets/images/level_b2.webp',
      'social_cultural' => 'assets/images/level_b1.webp',
      'educational' => 'assets/images/level_a2.webp',
      _ => lesson.order == 2
          ? 'assets/images/level_c1.webp'
          : 'assets/images/level_a1.webp',
    };
  }
}
