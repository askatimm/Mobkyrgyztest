import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'models/video_lesson.dart';
import 'models/video_taxonomy.dart';
import 'preview/design_preview.dart';
import 'preview/video_preview_catalog.dart';
import 'screens/login_screen.dart';
import 'services/video_lessons_service.dart';
import 'video_player_screen.dart';
import 'widgets/video_design.dart';
import 'widgets/premium_feedback.dart';

class VideoLessonsScreen extends StatefulWidget {
  const VideoLessonsScreen({super.key});
  @override
  State<VideoLessonsScreen> createState() => _VideoLessonsScreenState();
}

class _VideoLessonsScreenState extends State<VideoLessonsScreen> {
  VideoLessonsService? _service;
  String _level = VideoTaxonomy.levels.first;
  String _sphere = VideoTaxonomy.spheres.first.code;
  String? _section;
  late Future<VideoLessonCatalog> _lessonsFuture;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  void _loadLessons() {
    _lessonsFuture = _fetchLessons();
  }

  Future<VideoLessonCatalog> _fetchLessons() async {
    if (DesignPreview.enabled) {
      return VideoLessonCatalog(
        lessons: VideoPreviewCatalog.lessons(level: 'A1', sphere: _sphere),
        availableLevels: const ['A1'],
      );
    }
    final selectedLevel = _level;
    final selectedSphere = _sphere;
    final service = _service ??= VideoLessonsService();
    var catalog = await service.fetchActiveLessons(
      level: selectedLevel, sphere: selectedSphere);
    if (catalog.availableLevels.isNotEmpty &&
        !catalog.availableLevels.contains(selectedLevel)) {
      final nextLevel = catalog.availableLevels.first;
      catalog = await service.fetchActiveLessons(
        level: nextLevel, sphere: selectedSphere);
      if (mounted && _level == selectedLevel && _sphere == selectedSphere) {
        setState(() {
          _level = nextLevel;
          _section = null;
        });
      }
    }
    return catalog;
  }

  void _changeFilter({String? level, String? sphere}) {
    setState(() {
      _level = level ?? _level;
      _sphere = sphere ?? _sphere;
      _section = null;
      _loadLessons();
    });
  }

  Future<void> _refresh() async {
    setState(_loadLessons);
    try {
      await _lessonsFuture;
    } catch (_) {
      // FutureBuilder owns the visible error/retry state.
    }
  }

  Future<void> _showPaywall() async {
    await openPremiumPaywall(context);
    if (mounted) await _refresh();
  }

  Future<void> _signIn() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const LoginScreen(),
    ));
    if (mounted) await _refresh();
  }

  void _openLesson(VideoLesson lesson, List<VideoLesson> playlist) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => VideoPlayerScreen(lesson: lesson, playlist: playlist),
    ));
  }

  List<VideoSectionOption> _sections(List<VideoLesson> lessons) {
    final result = <String, VideoSectionOption>{
      for (final item in VideoTaxonomy.knownSections[_sphere] ??
          const <VideoSectionOption>[]) item.code: item,
    };
    for (final lesson in lessons) {
      result.putIfAbsent(lesson.section, () => VideoSectionOption(
        code: lesson.section,
        ky: VideoTaxonomy.sectionLabel(sphere: _sphere, section: lesson.section,
            languageCode: 'ky', metadataLabel: lesson.localizedSectionTitle('ky')),
        ru: VideoTaxonomy.sectionLabel(sphere: _sphere, section: lesson.section,
            languageCode: 'ru', metadataLabel: lesson.localizedSectionTitle('ru')),
      ));
    }
    return result.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final language = context.locale.languageCode;
    return Scaffold(
      backgroundColor: LearningColors.background,
      body: SafeArea(bottom: false, child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: FutureBuilder<VideoLessonCatalog>(
            future: _lessonsFuture,
            builder: (context, snapshot) {
              final loading = snapshot.connectionState == ConnectionState.waiting;
              final lessons = (snapshot.data?.lessons ?? const <VideoLesson>[])
                  .where((item) => item.level == _level && item.sphere == _sphere)
                  .toList()
                ..sort((a, b) {
                  final order = a.order.compareTo(b.order);
                  return order != 0 ? order : a.id.compareTo(b.id);
                });
              final sections = _sections(lessons);
              final selected = sections.any((item) => item.code == _section)
                  ? _section : sections.firstOrNull?.code;
              final visible = lessons.where((item) => item.section == selected).toList();
              final title = selected == null ? 'video_section'.tr()
                  : sections.firstWhere((item) => item.code == selected).label(language);
              final minutes = (visible.fold<int>(0, (sum, item) => sum + item.duration) / 60).ceil();
              return RefreshIndicator(
                onRefresh: _refresh, color: LearningColors.blue,
                child: CustomScrollView(
                  key: const PageStorageKey('video-library'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                      sliver: SliverToBoxAdapter(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.auto_stories_rounded, size: 20, color: LearningColors.blue),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('Кыргызтест', maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w700,
                                    color: LearningColors.ink, fontSize: 15))),
                            const SizedBox(width: 8), const PremiumBadge(),
                          ]),
                          const SizedBox(height: 22),
                          Text('video_lessons_title'.tr(), style: const TextStyle(
                              fontSize: 30, height: 1.15, letterSpacing: -0.8,
                              fontWeight: FontWeight.w800, color: LearningColors.ink)),
                          const SizedBox(height: 8),
                          Text('video_lessons_subtitle'.tr(), style: const TextStyle(
                              fontSize: 14, height: 1.5, color: LearningColors.muted)),
                          if (DesignPreview.enabled) ...[
                            const SizedBox(height: 16), const DesignPreviewNotice(),
                          ],
                          const SizedBox(height: 22),
                          _buildFilters(sections, selected, language,
                              snapshot.data?.availableLevels ?? const <String>[]),
                          const SizedBox(height: 24),
                          Text(title, style: const TextStyle(fontSize: 22, height: 1.2,
                              fontWeight: FontWeight.w700, color: LearningColors.ink)),
                          const SizedBox(height: 6),
                          if (!loading && visible.isNotEmpty)
                            Text('${'video_lesson_count'.tr(namedArgs: {'count': '${visible.length}'})}'
                                ' · ${'video_total_minutes'.tr(namedArgs: {'minutes': '$minutes'})}',
                                style: const TextStyle(color: LearningColors.muted, fontSize: 13)),
                          const SizedBox(height: 16),
                        ],
                      )),
                    ),
                    if (loading)
                      const SliverPadding(padding: EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverToBoxAdapter(child: _LoadingLessons()))
                    else if (snapshot.error is VideoSignInRequiredException)
                      SliverToBoxAdapter(child: _LibraryMessage(
                        icon: Icons.person_outline_rounded,
                        title: 'premium_sign_in'.tr(),
                        description: 'premium_sign_in_required'.tr(),
                        action: 'premium_sign_in'.tr(), onAction: _signIn,
                      ))
                    else if (snapshot.error is VideoPremiumRequiredException)
                      SliverToBoxAdapter(child: _LibraryMessage(
                        icon: Icons.workspace_premium_rounded, title: 'video_premium_title'.tr(),
                        description: 'video_premium_required'.tr(), action: 'video_open_paywall'.tr(),
                        onAction: _showPaywall, premium: true,
                      ))
                    else if (snapshot.hasError)
                      SliverToBoxAdapter(child: _LibraryMessage(
                        icon: Icons.wifi_off_rounded, title: 'video_loading_error'.tr(),
                        description: 'video_loading_error_detail'.tr(), action: 'retry'.tr(), onAction: _refresh,
                      ))
                    else if (visible.isEmpty)
                      SliverToBoxAdapter(child: _LibraryMessage(
                        icon: Icons.video_library_outlined, title: 'video_no_lessons'.tr(),
                        description: 'video_empty_detail'.tr(),
                      ))
                    else
                      SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final lesson = visible[index];
                            return Padding(padding: const EdgeInsets.only(bottom: 14),
                              child: index == 0
                                  ? _FeaturedLesson(lesson: lesson, language: language,
                                      onTap: () => _openLesson(lesson, visible))
                                  : _CompactLesson(lesson: lesson, language: language,
                                      onTap: () => _openLesson(lesson, visible)),
                            );
                          }, childCount: visible.length,
                        )),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 125)),
                  ],
                ),
              );
            },
          ),
        ),
      )),
    );
  }

  Widget _buildFilters(List<VideoSectionOption> sections, String? selected,
      String language, List<String> availableLevels) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22),
          border: Border.all(color: LearningColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (availableLevels.isNotEmpty) ...[
        Text('level'.tr(), style: const TextStyle(fontSize: 12,
            fontWeight: FontWeight.w600, color: LearningColors.muted)),
        const SizedBox(height: 10),
        Row(children: [for (final level in availableLevels) ...[
          if (level != availableLevels.first) const SizedBox(width: 6),
          Expanded(child: Semantics(
            selected: level == _level, button: true,
            label: 'levels.${level.toLowerCase()}'.tr(),
            child: Material(
              color: level == _level ? LearningColors.navy : LearningColors.background,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(key: ValueKey('video-level-$level'),
                borderRadius: BorderRadius.circular(12),
                onTap: () { if (level != _level) _changeFilter(level: level); },
                child: Padding(padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Text(level, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: level == _level ? Colors.white : LearningColors.muted)),
                ),
              ),
            ),
          )),
        ]]),
        const SizedBox(height: 16),
        ],
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _FilterPicker(fieldKey: 'video-sphere', label: 'video_sphere'.tr(),
            value: _sphere, icon: Icons.public_rounded,
            choices: [for (final sphere in VideoTaxonomy.spheres)
              _FilterChoice(sphere.code, sphere.label(language), sphere.secondaryLabel(language))],
            onChanged: (value) => _changeFilter(sphere: value),
          )),
          const SizedBox(width: 10),
          Expanded(child: _FilterPicker(fieldKey: 'video-section', label: 'video_section'.tr(),
            value: selected, icon: Icons.bookmark_border_rounded,
            choices: [for (final section in sections)
              _FilterChoice(section.code, section.label(language),
                  section.label(language == 'ru' ? 'ky' : 'ru'))],
            onChanged: (value) => setState(() => _section = value),
          )),
        ]),
      ]),
    );
  }
}

class _FilterChoice {
  const _FilterChoice(this.value, this.title, this.secondary);
  final String value;
  final String title;
  final String secondary;
}

/// A combobox-style picker with a full-width menu so long bilingual titles fit.
class _FilterPicker extends StatelessWidget {
  const _FilterPicker({required this.fieldKey, required this.label, required this.value,
    required this.icon, required this.choices, required this.onChanged});
  final String fieldKey;
  final String label;
  final String? value;
  final IconData icon;
  final List<_FilterChoice> choices;
  final ValueChanged<String> onChanged;

  Future<void> _pick(BuildContext context) async {
    final next = await showModalBottomSheet<String>(
      context: context, isScrollControlled: true, showDragHandle: true, backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (context) => SafeArea(top: false, child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
              child: Text(label, style: const TextStyle(fontSize: 22,
                  fontWeight: FontWeight.w700, color: LearningColors.ink))),
          Flexible(child: ListView.separated(shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20), itemCount: choices.length,
            separatorBuilder: (_, index) => const Divider(height: 1, indent: 12,
                endIndent: 12, color: LearningColors.border),
            itemBuilder: (context, index) {
              final option = choices[index];
              return ListTile(key: ValueKey('$fieldKey-option-${option.value}'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                title: Text(option.title, style: const TextStyle(color: LearningColors.ink,
                    fontWeight: FontWeight.w600)),
                subtitle: Text(option.secondary, style: const TextStyle(color: LearningColors.muted)),
                trailing: Icon(option.value == value ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: option.value == value ? LearningColors.blue : LearningColors.border),
                onTap: () => Navigator.pop(context, option.value),
              );
            },
          )),
        ]),
      )),
    );
    if (next != null && context.mounted && next != value) onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final selected = choices.where((item) => item.value == value).firstOrNull;
    return Semantics(button: true, enabled: choices.isNotEmpty,
      label: '$label: ${selected?.title ?? 'video_no_sections_short'.tr()}',
      child: Material(color: LearningColors.background, borderRadius: BorderRadius.circular(13),
        child: InkWell(key: ValueKey(fieldKey), borderRadius: BorderRadius.circular(13),
          onTap: choices.isEmpty ? null : () => _pick(context),
          child: Container(constraints: const BoxConstraints(minHeight: 92),
            padding: const EdgeInsets.all(11),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(icon, size: 14, color: LearningColors.muted),
                const SizedBox(width: 5),
                Expanded(child: Text(label, style: const TextStyle(fontSize: 11,
                    color: LearningColors.muted))),
                const Icon(Icons.expand_more_rounded, size: 16, color: LearningColors.muted),
              ]),
              const SizedBox(height: 7),
              Text(selected?.title ?? 'video_no_sections_short'.tr(), style: const TextStyle(
                  fontSize: 13, height: 1.35, fontWeight: FontWeight.w600, color: LearningColors.ink)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FeaturedLesson extends StatelessWidget {
  const _FeaturedLesson({required this.lesson, required this.language, required this.onTap});
  final VideoLesson lesson;
  final String language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white, borderRadius: BorderRadius.circular(22), clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AspectRatio(aspectRatio: 16 / 9,
          child: Stack(fit: StackFit.expand, children: [
            LessonThumbnail(lesson: lesson),
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0x44102C4E), Color(0x0A102C4E), Color(0xF5102C4E)], stops: [0, 0.3, 1],
            ))),
            Positioned(top: 14, left: 14, right: 14, child: Row(children: [
              Flexible(child: _PosterTag(
                  label: '${lesson.level} · ${'video_lesson_number'.tr(namedArgs: {'number': '${lesson.order}'})}')),
              const Spacer(),
              _PosterTag(label: videoDuration(lesson.duration)),
            ])),
            const Align(alignment: Alignment(0, -0.2), child: DecoratedBox(
              decoration: BoxDecoration(color: Color(0xCCFFFFFF), shape: BoxShape.circle),
              child: Padding(padding: EdgeInsets.all(10),
                child: Icon(Icons.play_arrow_rounded, color: LearningColors.navy, size: 34)),
            )),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(lesson.localizedTitle(language), maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: LearningColors.ink, fontSize: 21,
                    fontWeight: FontWeight.w700, height: 1.25)),
            const SizedBox(height: 9),
            if (lesson.localizedDescription(language).isNotEmpty) ...[
              Text(lesson.localizedDescription(language), maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, height: 1.5, color: LearningColors.muted)),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(onPressed: onTap,
              style: FilledButton.styleFrom(backgroundColor: LearningColors.blue,
                  foregroundColor: Colors.white, minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: Text('video_start_lesson'.tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ]),
    ),
  );
}

class _PosterTag extends StatelessWidget {
  const _PosterTag({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: const Color(0xB3102C4E), borderRadius: BorderRadius.circular(8)),
    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

class _CompactLesson extends StatelessWidget {
  const _CompactLesson({required this.lesson, required this.language, required this.onTap});
  final VideoLesson lesson;
  final String language;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white, borderRadius: BorderRadius.circular(18), clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        SizedBox(width: 96, height: 82, child: ClipRRect(borderRadius: BorderRadius.circular(11),
          child: Stack(fit: StackFit.expand, children: [LessonThumbnail(lesson: lesson),
            const ColoredBox(color: Color(0x18102C4E)),
            const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 30)),
          ]))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('video_lesson_number'.tr(namedArgs: {'number': '${lesson.order}'}),
              style: const TextStyle(fontSize: 11, color: LearningColors.muted)),
          const SizedBox(height: 5),
          Text(lesson.localizedTitle(language), maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  height: 1.3, color: LearningColors.ink)),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.schedule_rounded, size: 13, color: LearningColors.muted),
            const SizedBox(width: 4),
            Text(videoDuration(lesson.duration), style: const TextStyle(fontSize: 12, color: LearningColors.muted)),
          ]),
        ])),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right_rounded, size: 20, color: LearningColors.muted),
      ])),
    ),
  );
}

class _LibraryMessage extends StatelessWidget {
  const _LibraryMessage({required this.icon, required this.title, required this.description,
    this.action, this.onAction, this.premium = false});
  final IconData icon;
  final String title;
  final String description;
  final String? action;
  final VoidCallback? onAction;
  final bool premium;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20), padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(color: premium ? LearningColors.navy : Colors.white,
        borderRadius: BorderRadius.circular(22)),
    child: Column(children: [
      Icon(icon, size: 40, color: premium ? const Color(0xFFFFDDA5) : LearningColors.blue),
      const SizedBox(height: 18),
      Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 21,
          fontWeight: FontWeight.w700, color: premium ? Colors.white : LearningColors.ink)),
      const SizedBox(height: 10),
      Text(description, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.5,
          color: premium ? const Color(0xFFCEDCED) : LearningColors.muted)),
      if (action != null && onAction != null) ...[
        const SizedBox(height: 24),
        FilledButton(onPressed: onAction,
          style: FilledButton.styleFrom(
              backgroundColor: premium ? const Color(0xFFFFDDA5) : LearningColors.blue,
              foregroundColor: premium ? LearningColors.navy : Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
          child: Text(action!, style: const TextStyle(fontWeight: FontWeight.w700))),
      ],
    ]),
  );
}

class _LoadingLessons extends StatelessWidget {
  const _LoadingLessons();
  @override
  Widget build(BuildContext context) => Semantics(label: 'video_loading'.tr(),
    child: Container(height: 230,
      decoration: BoxDecoration(color: const Color(0xFFE5ECF4), borderRadius: BorderRadius.circular(22)),
      child: const Center(child: SizedBox(width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2))),
    ),
  );
}
