import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'models/video_lesson.dart';
import 'models/video_taxonomy.dart';
import 'services/video_lessons_service.dart';
import 'video_player_screen.dart';

class VideoLessonsScreen extends StatefulWidget {
  const VideoLessonsScreen({super.key});

  @override
  State<VideoLessonsScreen> createState() => _VideoLessonsScreenState();
}

class _VideoLessonsScreenState extends State<VideoLessonsScreen> {
  final VideoLessonsService _service = VideoLessonsService();

  String _selectedLevel = VideoTaxonomy.levels.first;
  String _selectedSphere = VideoTaxonomy.spheres.first.code;
  String? _selectedSection;
  late Stream<List<VideoLesson>> _lessonsStream;

  @override
  void initState() {
    super.initState();
    _replaceLessonsStream();
  }

  void _replaceLessonsStream() {
    _lessonsStream = _service.watchActiveLessons(
      level: _selectedLevel,
      sphere: _selectedSphere,
    );
  }

  void _selectLevel(String level) {
    if (level == _selectedLevel) return;
    setState(() {
      _selectedLevel = level;
      _selectedSection = null;
      _replaceLessonsStream();
    });
  }

  void _selectSphere(String sphere) {
    if (sphere == _selectedSphere) return;
    setState(() {
      _selectedSphere = sphere;
      _selectedSection = null;
      _replaceLessonsStream();
    });
  }

  void _retry() {
    setState(_replaceLessonsStream);
  }

  @override
  Widget build(BuildContext context) {
    final languageCode = context.locale.languageCode;

    return Scaffold(
      backgroundColor: const Color(0xFFF2FAFF),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE2F8FF), Color(0xFFF7FBFF)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: StreamBuilder<List<VideoLesson>>(
            stream: _lessonsStream,
            builder: (context, snapshot) {
              final lessons = (snapshot.data ?? const <VideoLesson>[])
                  .where(
                    (lesson) =>
                        lesson.level == _selectedLevel &&
                        lesson.sphere == _selectedSphere,
                  )
                  .toList();
              final sections = _buildSectionChoices(
                lessons,
                languageCode,
              );
              final effectiveSection = _effectiveSection(sections);
              final visibleLessons = effectiveSection == null
                  ? const <VideoLesson>[]
                  : lessons
                        .where((lesson) => lesson.section == effectiveSection)
                        .toList();

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(
                      context,
                      sections: sections,
                      effectiveSection: effectiveSection,
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _MessagePanel(
                        icon: Icons.cloud_off_rounded,
                        title: 'video_loading_error'.tr(),
                        actionLabel: 'retry'.tr(),
                        onAction: _retry,
                      ),
                    )
                  else if (sections.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _MessagePanel(
                        icon: Icons.video_library_outlined,
                        title: 'video_no_sections'.tr(),
                      ),
                    )
                  else if (visibleLessons.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _MessagePanel(
                        icon: Icons.ondemand_video_outlined,
                        title: 'video_no_lessons'.tr(),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index.isOdd) {
                              return const SizedBox(height: 12);
                            }
                            final lessonIndex = index ~/ 2;
                            return _VideoLessonCard(
                              lesson: visibleLessons[lessonIndex],
                              languageCode: languageCode,
                              onTap: () =>
                                  _openLesson(visibleLessons[lessonIndex]),
                            );
                          },
                          childCount: (visibleLessons.length * 2) - 1,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 135)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required List<_SectionChoice> sections,
    required String? effectiveSection,
  }) {
    final languageCode = context.locale.languageCode;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'video_lessons_title'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF0C1733),
              fontSize: 32,
              height: 1.1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'video_lessons_subtitle'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF71809E),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5FA7D7).withValues(alpha: 0.1),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LabeledDropdown(
                    label: 'video_sphere'.tr(),
                    value: _selectedSphere,
                    icon: _sphereIcon(_selectedSphere),
                    items: VideoTaxonomy.spheres
                        .map(
                          (sphere) => _DropdownChoice(
                            value: sphere.code,
                            primary: sphere.label(languageCode),
                            secondary: sphere.secondaryLabel(languageCode),
                            icon: _sphereIcon(sphere.code),
                          ),
                        )
                        .toList(),
                    onChanged: _selectSphere,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LabeledDropdown(
                    label: 'video_section'.tr(),
                    value: effectiveSection,
                    icon: Icons.chat_bubble_outline_rounded,
                    items: sections
                        .map(
                          (section) => _DropdownChoice(
                            value: section.code,
                            primary: section.primary,
                            secondary: section.secondary,
                            icon: Icons.chat_bubble_outline_rounded,
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedSection = value);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var index = 0;
                  index < VideoTaxonomy.levels.length;
                  index++) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(
                  child: _LevelButton(
                    level: VideoTaxonomy.levels[index],
                    selected:
                        VideoTaxonomy.levels[index] == _selectedLevel,
                    onTap: () => _selectLevel(VideoTaxonomy.levels[index]),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  List<_SectionChoice> _buildSectionChoices(
    List<VideoLesson> lessons,
    String languageCode,
  ) {
    final choices = <String, _SectionChoice>{};
    final alternateLanguage = languageCode == 'ru' ? 'ky' : 'ru';

    for (final section
        in VideoTaxonomy.knownSections[_selectedSphere] ??
            const <VideoSectionOption>[]) {
      choices[section.code] = _SectionChoice(
        code: section.code,
        primary: section.label(languageCode),
        secondary: section.label(alternateLanguage),
      );
    }

    for (final lesson in lessons) {
      choices.putIfAbsent(
        lesson.section,
        () => _SectionChoice(
          code: lesson.section,
          primary: VideoTaxonomy.sectionLabel(
            sphere: lesson.sphere,
            section: lesson.section,
            languageCode: languageCode,
            metadataLabel: lesson.localizedSectionTitle(languageCode),
          ),
          secondary: VideoTaxonomy.sectionLabel(
            sphere: lesson.sphere,
            section: lesson.section,
            languageCode: alternateLanguage,
            metadataLabel: lesson.localizedSectionTitle(alternateLanguage),
          ),
        ),
      );
    }

    return choices.values.toList();
  }

  String? _effectiveSection(List<_SectionChoice> sections) {
    if (sections.isEmpty) return null;
    if (_selectedSection != null &&
        sections.any((section) => section.code == _selectedSection)) {
      return _selectedSection;
    }
    return sections.first.code;
  }

  void _openLesson(VideoLesson lesson) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(lesson: lesson),
      ),
    );
  }

  IconData _sphereIcon(String sphere) {
    switch (sphere) {
      case 'professional':
        return Icons.business_center_outlined;
      case 'social_cultural':
        return Icons.groups_outlined;
      case 'education':
        return Icons.school_outlined;
      case 'private':
      default:
        return Icons.person_outline_rounded;
    }
  }
}

class _SectionChoice {
  final String code;
  final String primary;
  final String secondary;

  const _SectionChoice({
    required this.code,
    required this.primary,
    required this.secondary,
  });
}

class _DropdownChoice {
  final String value;
  final String primary;
  final String secondary;
  final IconData icon;

  const _DropdownChoice({
    required this.value,
    required this.primary,
    required this.secondary,
    required this.icon,
  });
}

class _LabeledDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final List<_DropdownChoice> items;
  final ValueChanged<String> onChanged;

  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && items.any((item) => item.value == value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF263451),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFDFEFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasValue
                  ? const Color(0xFFC8D9F0)
                  : const Color(0xFFE3E9F2),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: hasValue ? value : null,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF315B9D),
              ),
              hint: Row(
                children: [
                  Icon(icon, size: 20, color: const Color(0xFF9AA7BC)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'video_no_sections_short'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF9AA7BC)),
                    ),
                  ),
                ],
              ),
              menuMaxHeight: 360,
              itemHeight: 64,
              items: items
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.value,
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 22,
                            color: const Color(0xFF5474A8),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.primary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF1E2941),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                if (item.secondary.isNotEmpty &&
                                    item.secondary != item.primary)
                                  Text(
                                    item.secondary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF8A96AC),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              selectedItemBuilder: (context) => items
                  .map(
                    (item) => Row(
                      children: [
                        Icon(item.icon, size: 20, color: const Color(0xFF2785DE)),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            item.primary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1E2941),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
              onChanged: items.isEmpty
                  ? null
                  : (nextValue) {
                      if (nextValue != null) onChanged(nextValue);
                    },
            ),
          ),
        ),
      ],
    );
  }
}

class _LevelButton extends StatelessWidget {
  final String level;
  final bool selected;
  final VoidCallback onTap;

  const _LevelButton({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF2499EA) : Colors.white70,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2499EA).withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            level,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF1D2942),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoLessonCard extends StatelessWidget {
  final VideoLesson lesson;
  final String languageCode;
  final VoidCallback onTap;

  const _VideoLessonCard({
    required this.lesson,
    required this.languageCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = lesson.localizedTitle(languageCode);
    final description = lesson.localizedDescription(languageCode);
    final orderPrefix = lesson.order > 0 ? '${lesson.order}. ' : '';

    return Semantics(
      button: true,
      label: '$orderPrefix$title',
      child: Material(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final thumbnailWidth = (constraints.maxWidth * 0.46)
                    .clamp(126.0, 170.0)
                    .toDouble();

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: thumbnailWidth,
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                lesson.thumbnailUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const ColoredBox(
                                    color: Color(0xFFE8F1F7),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (_, _, _) => const ColoredBox(
                                  color: Color(0xFFDCEAF4),
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Color(0xFF7890A7),
                                  ),
                                ),
                              ),
                              Center(
                                child: Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.38),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 5,
                                bottom: 5,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.78),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _formatDuration(lesson.duration),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 5, 4, 3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$orderPrefix$title',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF111A31),
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                height: 1.2,
                              ),
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF77849E),
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5F3FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                lesson.level,
                                style: const TextStyle(
                                  color: Color(0xFF147CD1),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    final remainingSeconds = safeSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

class _MessagePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessagePanel({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 20, 32, 130),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: const Color(0xFF7E9DB8)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF5E7188),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
