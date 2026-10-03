/// Public SDK configuration only. Server API keys belong in Secret Manager.
class PremiumConfig {
  static const androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_KEY',
    defaultValue: 'goog_jAlsAgpZXlSPVxckpWjzBFPoNRR',
  );
  static const iosApiKey = String.fromEnvironment('REVENUECAT_IOS_KEY');
  static const entitlementId = String.fromEnvironment(
    'REVENUECAT_ENTITLEMENT_ID',
    defaultValue: 'KyrgyzTest Pro',
  );
  static const offeringId = String.fromEnvironment('REVENUECAT_OFFERING_ID');

  static bool isValidSdkKey(String key, String platformPrefix, {
    required bool release,
  }) {
    if (key.contains('REPLACE') || key.contains('ТВОЙ') || key.length < 12) {
      return false;
    }
    return key.startsWith(platformPrefix) || (!release && key.startsWith('test_'));
  }
}
