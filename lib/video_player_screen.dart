import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'models/video_lesson.dart';
import 'models/video_taxonomy.dart';

class VideoPlayerScreen extends StatefulWidget {
  final VideoLesson lesson;

  const VideoPlayerScreen({super.key, required this.lesson});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  String? _errorMessage;
  bool _isFullscreen = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final uri = Uri.tryParse(widget.lesson.videoUrl);
    if (uri == null || uri.scheme != 'https') {
      setState(() => _errorMessage = 'video_invalid_source'.tr());
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    controller.addListener(_handleVideoUpdate);

    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'video_playback_error'.tr());
    }
  }

  void _handleVideoUpdate() {
    if (mounted && _controller?.value.isInitialized == true) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _controller?.pause();
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      await controller.pause();
      return;
    }

    if (controller.value.position >= controller.value.duration) {
      await controller.seekTo(Duration.zero);
    }
    await controller.play();
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;

    final nextValue = !_isMuted;
    await controller.setVolume(nextValue ? 0 : 1);
    if (mounted) setState(() => _isMuted = nextValue);
  }

  Future<void> _setFullscreen(bool value) async {
    if (value) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await _restoreSystemUi();
    }

    if (mounted) setState(() => _isFullscreen = value);
  }

  Future<void> _restoreSystemUi() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Future<bool> _handleBack() async {
    if (_isFullscreen) {
      await _setFullscreen(false);
      return false;
    }
    return true;
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
    final languageCode = context.locale.languageCode;

    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        backgroundColor: _isFullscreen
            ? Colors.black
            : const Color(0xFFF5FBFF),
        appBar: _isFullscreen
            ? null
            : AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
              ),
        body: _isFullscreen
            ? Center(child: _buildVideoSurface())
            : SafeArea(
                top: false,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    _buildVideoSurface(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.lesson.localizedTitle(languageCode),
                            style: const TextStyle(
                              fontSize: 24,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0C1733),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              _MetaChip(label: widget.lesson.level),
                              _MetaChip(
                                label: VideoTaxonomy.sphere(
                                  widget.lesson.sphere,
                                ).label(languageCode),
                              ),
                              _MetaChip(
                                label: VideoTaxonomy.sectionLabel(
                                  sphere: widget.lesson.sphere,
                                  section: widget.lesson.section,
                                  languageCode: languageCode,
                                  metadataLabel: widget.lesson
                                      .localizedSectionTitle(languageCode),
                                ),
                              ),
                            ],
                          ),
                          if (widget.lesson
                              .localizedDescription(languageCode)
                              .isNotEmpty) ...[
                            const SizedBox(height: 28),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFDCEEFF),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'video_description'.tr(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0C1733),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.lesson.localizedDescription(
                                      languageCode,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      height: 1.55,
                                      color: Color(0xFF5F6E8D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildVideoSurface() {
    final controller = _controller;
    final initialized = controller != null && controller.value.isInitialized;

    if (_errorMessage != null || !initialized) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: const Color(0xFF080C13),
          child: _errorMessage != null
              ? _buildVideoError()
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
        ),
      );
    }

    final activeController = controller!;
    final aspectRatio = activeController.value.aspectRatio;

    return AspectRatio(
      aspectRatio: aspectRatio > 0 ? aspectRatio : 16 / 9,
      child: ColoredBox(
        color: const Color(0xFF080C13),
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(activeController),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlayback,
            ),
            Center(
              child: AnimatedOpacity(
                opacity: activeController.value.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 180),
                child: _RoundControlButton(
                  icon: Icons.play_arrow_rounded,
                  size: _isFullscreen ? 86 : 64,
                  onPressed: _togglePlayback,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildControls(activeController),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 40),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(VideoPlayerController controller) {
    final duration = controller.value.duration;
    final position = controller.value.position;
    final durationMs = math.max(duration.inMilliseconds, 1);
    final positionMs = math.min(position.inMilliseconds, durationMs);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 28, 8, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xCC000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white38,
              thumbColor: Colors.white,
              overlayColor: Colors.white24,
            ),
            child: Slider(
              value: positionMs.toDouble(),
              max: durationMs.toDouble(),
              onChanged: (value) {
                controller.seekTo(Duration(milliseconds: value.round()));
              },
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _togglePlayback,
                icon: Icon(
                  controller.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
              ),
              Text(
                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _toggleMute,
                icon: Icon(
                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: () => _setFullscreen(!_isFullscreen),
                icon: Icon(
                  _isFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _RoundControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onPressed;

  const _RoundControlButton({
    required this.icon,
    required this.size,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.48),
      shape: CircleBorder(side: BorderSide(color: Colors.white, width: 3)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white, size: size * 0.56),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F3FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF32517C),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
