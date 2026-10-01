import 'package:flutter/foundation.dart';

/// Opt-in, local-only design preview. Never enables access to private media.
/// The flag is ignored in profile/release builds, including store builds.
abstract final class DesignPreview {
  static const bool enabled =
      kDebugMode && bool.fromEnvironment('DESIGN_PREVIEW');

  static const int initialTab = int.fromEnvironment(
    'PREVIEW_TAB',
    defaultValue: 1,
  );
}
