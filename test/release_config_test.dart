import 'package:flutter_test/flutter_test.dart';
import 'package:kyrgyztestapp/config/premium_config.dart';

import '../tool/check_release_config.dart';

void main() {
  Map<String, dynamic> configuration() => {
    'REVENUECAT_ANDROID_KEY': 'goog_public_sdk_key_for_test',
    'REVENUECAT_ENTITLEMENT_ID': 'KyrgyzTest Pro',
    'PRIVACY_POLICY_URL': 'https://kyrgyztest.kg/privacy',
    'TERMS_URL': 'https://kyrgyztest.kg/terms',
    'ACCOUNT_DELETION_URL': 'https://kyrgyztest.kg/delete-account',
    'SUPPORT_EMAIL': 'info@kyrgyztest.gov.kg',
  };

  test('Test Store keys are restricted to development builds', () {
    expect(PremiumConfig.isValidSdkKey('test_public_sdk_key', 'goog_', release: false), isTrue);
    expect(PremiumConfig.isValidSdkKey('test_public_sdk_key', 'goog_', release: true), isFalse);
    expect(PremiumConfig.isValidSdkKey('sk_secret_api_key', 'goog_', release: false), isFalse);
  });

  test('Android release cannot use a Test Store key', () {
    final config = configuration()..['REVENUECAT_ANDROID_KEY'] = 'test_public_sdk_key';
    expect(validateReleaseConfig(config), isNotEmpty);
  });

  test('server secrets and preview flags cannot enter the mobile release config', () {
    final config = configuration()..['MINIO_SECRET_KEY'] = 'dummy';
    expect(validateReleaseConfig(config), isNotEmpty);
    config.remove('MINIO_SECRET_KEY');
    config['DESIGN_PREVIEW'] = 'true';
    expect(validateReleaseConfig(config), isNotEmpty);
  });

  test('missing or placeholder legal pages block release validation', () {
    final config = configuration()..remove('ACCOUNT_DELETION_URL');
    expect(validateReleaseConfig(config), isNotEmpty);
    config['ACCOUNT_DELETION_URL'] = 'https://REPLACE_WITH_YOUR_DOMAIN/delete';
    expect(validateReleaseConfig(config), isNotEmpty);
  });

  test('complete public configuration passes without proving external setup', () {
    expect(validateReleaseConfig(configuration()), isEmpty);
  });
}
