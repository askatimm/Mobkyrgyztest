class VideoSphereOption {
  final String code;
  final String ky;
  final String ru;

  const VideoSphereOption({
    required this.code,
    required this.ky,
    required this.ru,
  });

  String label(String languageCode) => languageCode == 'ru' ? ru : ky;

  String secondaryLabel(String languageCode) =>
      languageCode == 'ru' ? ky : ru;
}

class VideoSectionOption {
  final String code;
  final String ky;
  final String ru;

  const VideoSectionOption({
    required this.code,
    required this.ky,
    required this.ru,
  });

  String label(String languageCode) => languageCode == 'ru' ? ru : ky;
}

class VideoTaxonomy {
  static const levels = <String>['A1', 'A2', 'B1', 'B2', 'C1'];

  static const spheres = <VideoSphereOption>[
    VideoSphereOption(
      code: 'personal',
      ky: 'Жеке чөйрө',
      ru: 'Личная сфера',
    ),
    VideoSphereOption(
      code: 'professional',
      ky: 'Кесиптик чөйрө',
      ru: 'Профессиональная сфера',
    ),
    VideoSphereOption(
      code: 'social_cultural',
      ky: 'Социалдык-маданий чөйрө',
      ru: 'Социально-культурная сфера',
    ),
    VideoSphereOption(
      code: 'educational',
      ky: 'Окуу чөйрөсү',
      ru: 'Учебная сфера',
    ),
  ];

  static const Map<String, List<VideoSectionOption>> knownSections = {
    'personal': [
      VideoSectionOption(
        code: 'greeting',
        ky: 'Саламдашуу',
        ru: 'Приветствие',
      ),
      VideoSectionOption(
        code: 'farewell',
        ky: 'Коштошуу',
        ru: 'Прощание',
      ),
      VideoSectionOption(
        code: 'address',
        ky: 'Кайрылуу',
        ru: 'Обращение',
      ),
      VideoSectionOption(
        code: 'congratulations',
        ky: 'Куттуктоо',
        ru: 'Поздравление',
      ),
      VideoSectionOption(
        code: 'wishes',
        ky: 'Каалоо-тилек',
        ru: 'Пожелание',
      ),
      VideoSectionOption(
        code: 'introduction',
        ky: 'Таанышуу',
        ru: 'Знакомство',
      ),
    ],
  };

  static VideoSphereOption sphere(String code) {
    return spheres.firstWhere(
      (item) => item.code == code,
      orElse: () => VideoSphereOption(code: code, ky: code, ru: code),
    );
  }

  static VideoSectionOption? knownSection(String sphere, String code) {
    final sections = knownSections[sphere] ?? const <VideoSectionOption>[];
    for (final section in sections) {
      if (section.code == code) return section;
    }
    return null;
  }

  static String sectionLabel({
    required String sphere,
    required String section,
    required String languageCode,
    String metadataLabel = '',
  }) {
    if (metadataLabel.trim().isNotEmpty) return metadataLabel.trim();

    final known = knownSection(sphere, section);
    if (known != null) return known.label(languageCode);

    return section
        .split(RegExp(r'[_-]+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) => part.length == 1
              ? part.toUpperCase()
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }
}
