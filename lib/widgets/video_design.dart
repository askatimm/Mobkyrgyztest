import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/video_lesson.dart';
import '../preview/design_preview.dart';
import '../preview/video_preview_catalog.dart';

abstract final class LearningColors {
  static const background = Color(0xFFF5F7FB);
  static const ink = Color(0xFF142B48);
  static const muted = Color(0xFF66758B);
  static const blue = Color(0xFF227CE1);
  static const border = Color(0xFFE3EAF3);
  static const gold = Color(0xFF926522);
  static const navy = Color(0xFF102C4E);
}

class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: onDark ? const Color(0xFF284562) : const Color(0xFFFFF4DF),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: 16,
            color: onDark ? const Color(0xFFFFDDA5) : LearningColors.gold,
          ),
          const SizedBox(width: 5),
          Text(
            'Premium',
            style: TextStyle(
              color: onDark ? const Color(0xFFFFDDA5) : LearningColors.gold,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class DesignPreviewNotice extends StatelessWidget {
  const DesignPreviewNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4DF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.design_services_outlined,
              size: 16, color: LearningColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'design_preview_notice'.tr(),
              style: const TextStyle(
                fontSize: 12,
                color: LearningColors.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LessonThumbnail extends StatelessWidget {
  const LessonThumbnail({super.key, required this.lesson});

  final VideoLesson lesson;

  @override
  Widget build(BuildContext context) {
    if (DesignPreview.enabled) {
      return Image.asset(
        VideoPreviewCatalog.thumbnailFor(lesson),
        fit: BoxFit.cover,
        excludeFromSemantics: true,
      );
    }
    return Image.network(
      lesson.thumbnailUrl,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const _ThumbnailPlaceholder(loading: true);
      },
      errorBuilder: (context, error, stackTrace) =>
          const _ThumbnailPlaceholder(),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE3EDF7),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.ondemand_video_outlined,
                color: LearningColors.muted, size: 36),
      ),
    );
  }
}

String videoDuration(int seconds) {
  final duration = Duration(seconds: seconds < 0 ? 0 : seconds);
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final remainder = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (duration.inHours > 0) return '${duration.inHours}:$minutes:$remainder';
  return '${duration.inMinutes}:$remainder';
}
