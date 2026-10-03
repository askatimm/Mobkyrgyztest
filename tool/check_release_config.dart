import 'dart:convert';
import 'dart:io';

List<String> validateReleaseConfig(Map<String, dynamic> config) {
  final errors = <String>[];
  String value(String key) => config[key]?.toString().trim() ?? '';
  bool placeholder(String input) => input.toUpperCase().contains('REPLACE') ||
      input.contains('example.com') || input.contains('ТВОЙ');

  final sdkKey = value('REVENUECAT_ANDROID_KEY');
  if (!sdkKey.startsWith('goog_') || sdkKey.length < 12 || placeholder(sdkKey)) {
    errors.add('REVENUECAT_ANDROID_KEY: use your Google Play public SDK key (goog_), never a test_ or secret key.');
  }
  if (value('REVENUECAT_ENTITLEMENT_ID').isEmpty || placeholder(value('REVENUECAT_ENTITLEMENT_ID'))) {
    errors.add('REVENUECAT_ENTITLEMENT_ID: enter the exact RevenueCat identifier.');
  }
  for (final key in ['PRIVACY_POLICY_URL', 'TERMS_URL', 'ACCOUNT_DELETION_URL']) {
    final uri = Uri.tryParse(value(key));
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.host == 'localhost' || uri.host == '127.0.0.1' || placeholder(value(key))) {
      errors.add('$key: enter a working public HTTPS page.');
    }
  }
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value('SUPPORT_EMAIL')) ||
      placeholder(value('SUPPORT_EMAIL'))) {
    errors.add('SUPPORT_EMAIL: enter the monitored support mailbox.');
  }
  if (value('DESIGN_PREVIEW').toLowerCase() == 'true') {
    errors.add('Remove DESIGN_PREVIEW from the release configuration.');
  }
  const allowedKeys = {
    'REVENUECAT_ANDROID_KEY', 'REVENUECAT_ENTITLEMENT_ID', 'REVENUECAT_OFFERING_ID',
    'PRIVACY_POLICY_URL', 'TERMS_URL', 'ACCOUNT_DELETION_URL', 'SUPPORT_EMAIL',
  };
  if (config.keys.any((key) => !allowedKeys.contains(key))) {
    errors.add('Use only public mobile configuration fields. Server credentials must never be compiled into the app.');
  }
  return errors;
}

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run tool/check_release_config.dart config/release.json');
    exitCode = 1;
    return;
  }
  try {
    final config = jsonDecode(File(arguments.single).readAsStringSync()) as Map<String, dynamic>;
    final errors = validateReleaseConfig(config);
    if (errors.isNotEmpty) {
      for (final error in errors) { stderr.writeln(error); }
      exitCode = 1;
    } else {
      stdout.writeln('Public configuration validated. Verify that the pages work and run store purchase tests before publishing.');
    }
  } catch (_) {
    stderr.writeln('Unable to read the release JSON configuration.');
    exitCode = 1;
  }
}
