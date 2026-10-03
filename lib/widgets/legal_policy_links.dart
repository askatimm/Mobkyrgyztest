import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/legal_config.dart';

class LegalPolicyLinks extends StatelessWidget {
  const LegalPolicyLinks({super.key});

  Future<void> _open(BuildContext context, String value) async {
    try {
      final uri = LegalConfig.httpsUri(value);
      if (uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Show a localized, actionable message instead of SDK error details.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('legal_link_unavailable'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    children: [
      TextButton(onPressed: () => _open(context, LegalConfig.privacyUrl),
        child: Text('privacy_policy'.tr())),
      TextButton(onPressed: () => _open(context, LegalConfig.termsUrl),
        child: Text('terms_of_use'.tr())),
    ],
  );
}
