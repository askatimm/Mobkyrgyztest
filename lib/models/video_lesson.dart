class VideoLesson {
  final String id;
  final String level;
  final String sphere;
  final String section;
  final String title;
  final String description;
  final String thumbnailUrl;
  final int duration;
  final int order;
  final bool isActive;
  final String? titleKy;
  final String? titleRu;
  final String? descriptionKy;
  final String? descriptionRu;
  final String? sectionTitle;
  final String? sectionTitleKy;
  final String? sectionTitleRu;

  const VideoLesson({
    required this.id,
    required this.level,
    required this.sphere,
    required this.section,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.duration,
    required this.order,
    required this.isActive,
    this.titleKy,
    this.titleRu,
    this.descriptionKy,
    this.descriptionRu,
    this.sectionTitle,
    this.sectionTitleKy,
    this.sectionTitleRu,
  });

  factory VideoLesson.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return VideoLesson(
      id: id,
      level: _readString(data['level']).toUpperCase(),
      sphere: _readString(data['sphere']).toLowerCase(),
      section: _readString(data['section']).toLowerCase(),
      title: _readString(data['title']),
      description: _readString(data['description']),
      thumbnailUrl: _readString(data['thumbnailUrl']),
      duration: _readInt(data['duration']),
      order: _readInt(data['order']),
      isActive: data['isActive'] == true,
      titleKy: _readNullableString(data['titleKy']),
      titleRu: _readNullableString(data['titleRu']),
      descriptionKy: _readNullableString(data['descriptionKy']),
      descriptionRu: _readNullableString(data['descriptionRu']),
      sectionTitle: _readNullableString(data['sectionTitle']),
      sectionTitleKy: _readNullableString(data['sectionTitleKy']),
      sectionTitleRu: _readNullableString(data['sectionTitleRu']),
    );
  }

  String localizedTitle(String languageCode) {
    return _localizedValue(
      languageCode: languageCode,
      ky: titleKy,
      ru: titleRu,
      fallback: title,
    );
  }

  String localizedDescription(String languageCode) {
    return _localizedValue(
      languageCode: languageCode,
      ky: descriptionKy,
      ru: descriptionRu,
      fallback: description,
    );
  }

  String localizedSectionTitle(String languageCode) {
    return _localizedValue(
      languageCode: languageCode,
      ky: sectionTitleKy,
      ru: sectionTitleRu,
      fallback: sectionTitle ?? '',
    );
  }

  bool get hasRequiredMedia {
    return level.isNotEmpty &&
        sphere.isNotEmpty &&
        section.isNotEmpty &&
        title.isNotEmpty &&
        id.isNotEmpty &&
        _isSecureMediaUrl(thumbnailUrl);
  }

  static bool _isSecureMediaUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.toLowerCase() == 'media.kyrgyztest.kg';
  }

  static String _localizedValue({
    required String languageCode,
    required String? ky,
    required String? ru,
    required String fallback,
  }) {
    final localized = languageCode == 'ru' ? ru : ky;
    if (localized != null && localized.isNotEmpty) return localized;

    final alternate = languageCode == 'ru' ? ky : ru;
    if (fallback.isNotEmpty) return fallback;
    return alternate ?? '';
  }

  static String _readString(Object? value) {
    return value is String ? value.trim() : '';
  }

  static String? _readNullableString(Object? value) {
    final result = _readString(value);
    return result.isEmpty ? null : result;
  }

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
