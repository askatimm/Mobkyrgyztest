import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'models/video_lesson.dart';
import 'models/video_taxonomy.dart';
import 'preview/design_preview.dart';
import 'screens/membership_screen.dart';
import 'screens/login_screen.dart';
import 'services/video_lessons_service.dart';
import 'widgets/video_design.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.lesson, this.playlist = const []});
  final VideoLesson lesson;
  final List<VideoLesson> playlist;
  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> with WidgetsBindingObserver {
  VideoLessonsService? _service;
  VideoPlayerController? _controller;
  String? _errorMessage;
  bool _initializing = false;
  bool _premiumRequired = false;
  bool _signInRequired = false;
  bool _isFullscreen = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!DesignPreview.enabled) _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    if (_initializing || DesignPreview.enabled) return;
    _initializing = true;
    setState(() { _errorMessage = null; _premiumRequired = false; _signInRequired = false; });
    try {
      final previous = _controller;
      _controller = null;
      previous?.removeListener(_handleVideoUpdate);
      await previous?.dispose();
      final uri = await (_service ??= VideoLessonsService()).fetchPlaybackUri(widget.lesson.id);
      if (!mounted) return;
      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;
      controller.addListener(_handleVideoUpdate);
      await controller.initialize();
      if (!mounted) return;
      await controller.setVolume(_isMuted ? 0 : 1);
      if (mounted) setState(() {});
    } on VideoSignInRequiredException {
      if (mounted) setState(() {
        _signInRequired = true;
        _errorMessage = 'premium_sign_in_required'.tr();
      });
    } on VideoPremiumRequiredException {
      if (mounted) setState(() {
        _premiumRequired = true;
        _errorMessage = 'video_premium_required'.tr();
      });
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'video_playback_error'.tr());
    } finally {
      _initializing = false;
    }
  }

  void _handleVideoUpdate() {
    if (mounted && _controller?.value.hasError == true && _errorMessage == null) {
      setState(() => _errorMessage = 'video_playback_error'.tr());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _controller?.pause();
  }

  void _showPreviewNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('design_preview_playback'.tr())),
    );
  }

  Future<void> _togglePlayback() async {
    if (DesignPreview.enabled) { _showPreviewNotice(); return; }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) { await controller.pause(); return; }
    if (controller.value.position >= controller.value.duration) {
      await controller.seekTo(Duration.zero);
    }
    await controller.play();
  }

  Future<void> _toggleMute() async {
    final next = !_isMuted;
    await _controller?.setVolume(next ? 0 : 1);
    if (mounted) setState(() => _isMuted = next);
  }

  Future<void> _setFullscreen(bool value) async {
    if (value) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
      ]);
    } else {
      await _restoreSystemUi();
    }
    if (mounted) setState(() => _isFullscreen = value);
  }

  Future<void> _restoreSystemUi() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp, DeviceOrientation.portraitDown,
    ]);
  }

  Future<void> _openLesson(VideoLesson lesson) async {
    if (lesson.id == widget.lesson.id) return;
    await _controller?.pause();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => VideoPlayerScreen(lesson: lesson, playlist: widget.playlist),
    ));
  }

  Future<void> _openPaywall() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const MembershipScreen(),
    ));
    if (mounted) await _initializeVideo();
  }

  Future<void> _signIn() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const LoginScreen(),
    ));
    if (mounted) await _initializeVideo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_handleVideoUpdate);
    _controller?.dispose();
    if (_isFullscreen) _restoreSystemUi();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = context.locale.languageCode;
    final section = VideoTaxonomy.sectionLabel(sphere: widget.lesson.sphere,
        section: widget.lesson.section, languageCode: language,
        metadataLabel: widget.lesson.localizedSectionTitle(language));
    final currentIndex = widget.playlist.indexWhere((item) => item.id == widget.lesson.id);
    final next = currentIndex >= 0 && currentIndex + 1 < widget.playlist.length
        ? widget.playlist[currentIndex + 1] : null;
    return PopScope<void>(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isFullscreen) _setFullscreen(false);
      },
      child: Scaffold(
        backgroundColor: _isFullscreen ? Colors.black : LearningColors.background,
        appBar: _isFullscreen ? null : AppBar(
          backgroundColor: LearningColors.background, surfaceTintColor: Colors.transparent,
          foregroundColor: LearningColors.ink, elevation: 0,
          title: Text('video_lesson_number'.tr(namedArgs: {'number': '${widget.lesson.order}'}),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          actions: const [Padding(padding: EdgeInsets.only(right: 20),
              child: Center(child: PremiumBadge()))],
        ),
        body: _isFullscreen ? Center(child: _buildVideoSurface())
            : SafeArea(top: false, child: Align(alignment: Alignment.topCenter,
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 36), children: [
                  if (DesignPreview.enabled) ...[
                    const DesignPreviewNotice(), const SizedBox(height: 16),
                  ],
                  ClipRRect(borderRadius: BorderRadius.circular(20), child: _buildVideoSurface()),
                  const SizedBox(height: 24),
                  Wrap(spacing: 7, runSpacing: 7, children: [
                    _MetaChip(label: widget.lesson.level),
                    _MetaChip(label: section),
                    _MetaChip(label: videoDuration(widget.lesson.duration), icon: Icons.schedule_rounded),
                  ]),
                  const SizedBox(height: 14),
                  Text(widget.lesson.localizedTitle(language), style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800, height: 1.2,
                      letterSpacing: -0.5, color: LearningColors.ink)),
                  const SizedBox(height: 10),
                  Text(VideoTaxonomy.sphere(widget.lesson.sphere).label(language),
                      style: const TextStyle(color: LearningColors.muted, fontSize: 14)),
                  if (widget.lesson.localizedDescription(language).isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white,
                          borderRadius: BorderRadius.circular(18)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.notes_rounded, size: 18, color: LearningColors.blue),
                          const SizedBox(width: 8),
                          Text('video_description'.tr(), style: const TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w700, color: LearningColors.ink)),
                        ]),
                        const SizedBox(height: 12),
                        Text(widget.lesson.localizedDescription(language), style: const TextStyle(
                            fontSize: 15, height: 1.65, color: LearningColors.muted)),
                      ]),
                    ),
                  ],
                  if (widget.playlist.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Text('video_in_this_section'.tr(), style: const TextStyle(fontSize: 19,
                        fontWeight: FontWeight.w700, color: LearningColors.ink)),
                    const SizedBox(height: 14),
                    for (final lesson in widget.playlist) ...[
                      _PlaylistRow(lesson: lesson, language: language,
                          current: lesson.id == widget.lesson.id,
                          onTap: () => _openLesson(lesson)),
                      const SizedBox(height: 8),
                    ],
                  ],
                  if (next != null) ...[
                    const SizedBox(height: 18),
                    FilledButton.icon(onPressed: () => _openLesson(next),
                      style: FilledButton.styleFrom(backgroundColor: LearningColors.blue,
                          foregroundColor: Colors.white, minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                      label: Text('video_next_lesson'.tr()),
                    ),
                  ],
                ]),
              ),
            )),
      ),
    );
  }

  Widget _buildVideoSurface() {
    if (DesignPreview.enabled) return _buildPreviewSurface();
    final controller = _controller;
    if (_errorMessage != null || controller == null || !controller.value.isInitialized) {
      return AspectRatio(aspectRatio: 16 / 9, child: ColoredBox(
        color: LearningColors.navy,
        child: _errorMessage != null ? _buildVideoError() : const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
      ));
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) => AspectRatio(
        aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
        child: ColoredBox(color: Colors.black, child: Stack(fit: StackFit.expand, children: [
          VideoPlayer(controller),
          GestureDetector(behavior: HitTestBehavior.opaque, onTap: _togglePlayback),
          Center(child: IgnorePointer(ignoring: value.isPlaying,
            child: AnimatedOpacity(opacity: value.isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 160),
              child: _PlayButton(onTap: _togglePlayback),
            ),
          )),
          if (value.isBuffering) const Center(child: SizedBox(width: 24, height: 24,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildControls(controller)),
        ])),
      ),
    );
  }

  Widget _buildPreviewSurface() => AspectRatio(aspectRatio: 16 / 9,
    child: Stack(fit: StackFit.expand, children: [
      LessonThumbnail(lesson: widget.lesson),
      const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0x30102C4E), Color(0x66102C4E), Color(0xF5102C4E)],
      ))),
      Center(child: _PlayButton(onTap: _showPreviewNotice)),
      Positioned(top: 12, left: 14, child: Text('video_preview'.tr(),
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
      Positioned(left: 8, right: 8, bottom: 4, child: Row(children: [
        IconButton(tooltip: 'video_play'.tr(), onPressed: _showPreviewNotice,
            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white)),
        Expanded(child: Text('0:00 / ${videoDuration(widget.lesson.duration)}',
            style: const TextStyle(color: Colors.white, fontSize: 12))),
        IconButton(tooltip: 'video_fullscreen'.tr(),
            onPressed: () => _setFullscreen(!_isFullscreen),
            icon: Icon(_isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                color: Colors.white)),
      ])),
    ]),
  );

  Widget _buildVideoError() => Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(_premiumRequired ? Icons.lock_outline_rounded : Icons.error_outline_rounded,
          color: Colors.white, size: 28),
      const SizedBox(height: 8),
      Text(_errorMessage!, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
      const SizedBox(height: 4),
      TextButton(onPressed: _signInRequired ? _signIn : _premiumRequired ? _openPaywall : _initializeVideo,
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFFFDDA5)),
          child: Text(_signInRequired ? 'premium_sign_in'.tr() : _premiumRequired ? 'video_open_paywall'.tr() : 'retry'.tr())),
    ]),
  ));

  Widget _buildControls(VideoPlayerController controller) {
    final duration = controller.value.duration;
    final position = controller.value.position;
    final durationMs = math.max(duration.inMilliseconds, 1);
    final positionMs = position.inMilliseconds.clamp(0, durationMs);
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 2),
      decoration: const BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.transparent, Color(0xD9102C4E)],
      )),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            activeTrackColor: LearningColors.blue, inactiveTrackColor: Colors.white30,
            thumbColor: Colors.white),
          child: Slider(value: positionMs.toDouble(), max: durationMs.toDouble(),
            onChanged: (value) => controller.seekTo(Duration(milliseconds: value.round())),
          ),
        ),
        Row(children: [
          IconButton(tooltip: controller.value.isPlaying ? 'video_pause'.tr() : 'video_play'.tr(),
            onPressed: _togglePlayback,
            icon: Icon(controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white)),
          Expanded(child: Text('${videoDuration(position.inSeconds)} / ${videoDuration(duration.inSeconds)}',
              style: const TextStyle(color: Colors.white, fontSize: 12))),
          IconButton(tooltip: _isMuted ? 'video_unmute'.tr() : 'video_mute'.tr(), onPressed: _toggleMute,
              icon: Icon(_isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white)),
          IconButton(tooltip: 'video_fullscreen'.tr(), onPressed: () => _setFullscreen(!_isFullscreen),
              icon: Icon(_isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  color: Colors.white)),
        ]),
      ]),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(color: const Color(0xDEFFFFFF),
    shape: const CircleBorder(),
    child: InkWell(customBorder: const CircleBorder(), onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(10),
        child: Icon(Icons.play_arrow_rounded, color: LearningColors.navy,
            size: MediaQuery.sizeOf(context).width < 360 ? 32 : 40)),
    ),
  );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.icon});
  final String label;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(color: const Color(0xFFE7EFF9), borderRadius: BorderRadius.circular(9)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 13, color: LearningColors.muted), const SizedBox(width: 4)],
      Flexible(child: Text(label, style: const TextStyle(fontSize: 12,
          color: LearningColors.ink, fontWeight: FontWeight.w600))),
    ]),
  );
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({required this.lesson, required this.language, required this.current, required this.onTap});
  final VideoLesson lesson;
  final String language;
  final bool current;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: current ? const Color(0xFFE7EFF9) : Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(onTap: current ? null : onTap, borderRadius: BorderRadius.circular(14),
      child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
        Container(width: 34, height: 34, alignment: Alignment.center,
          decoration: BoxDecoration(color: current ? LearningColors.blue : LearningColors.background,
              borderRadius: BorderRadius.circular(9)),
          child: current ? const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22)
              : Text('${lesson.order}'.padLeft(2, '0'), style: const TextStyle(
                  color: LearningColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(lesson.localizedTitle(language), style: TextStyle(
            fontSize: 13, height: 1.4, color: current ? LearningColors.blue : LearningColors.ink,
            fontWeight: FontWeight.w600))),
        const SizedBox(width: 8),
        Text(videoDuration(lesson.duration), style: const TextStyle(fontSize: 12, color: LearningColors.muted)),
      ])),
    ),
  );
}
