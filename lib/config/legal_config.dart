class LegalConfig {
  static const privacyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
  static const termsUrl = String.fromEnvironment('TERMS_URL');
  static const deletionUrl = String.fromEnvironment('ACCOUNT_DELETION_URL');
  static const supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL', defaultValue: 'info@kyrgyztest.gov.kg',
  );

  static Uri? httpsUri(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty ? uri : null;
  }
}
