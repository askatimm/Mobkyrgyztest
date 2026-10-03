import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/legal_config.dart';
import '../preview/design_preview.dart';
import 'membership_screen.dart';

class AccountPrivacyScreen extends StatelessWidget {
  const AccountPrivacyScreen({super.key});

  void _notice(BuildContext context, String key) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(key.tr())));
  }

  Future<void> _open(BuildContext context, Uri? uri) async {
    if (DesignPreview.enabled) { _notice(context, 'design_preview_action'); return; }
    try {
      if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) _notice(context, 'legal_link_unavailable');
      }
    } catch (_) {
      if (context.mounted) _notice(context, 'legal_link_unavailable');
    }
  }

  Future<void> _requestDeletion(BuildContext context) async {
    if (DesignPreview.enabled) { _notice(context, 'design_preview_action'); return; }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      _notice(context, 'premium_sign_in_required');
      return;
    }
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text('account_delete_request'.tr()),
      content: Text('account_delete_notice'.tr()),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr())),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text('account_delete_continue'.tr())),
      ],
    ));
    if (confirmed != true || !context.mounted) return;
    // Opens the public request form. The app never silently sends a message or
    // claims that data has already been erased.
    await _open(context, LegalConfig.httpsUri(LegalConfig.deletionUrl));
  }

  Future<void> _draftEmail(BuildContext context) async {
    if (DesignPreview.enabled) { _notice(context, 'design_preview_action'); return; }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      _notice(context, 'premium_sign_in_required');
      return;
    }
    final subject = 'account_delete_email_subject'.tr();
    final body = 'account_delete_email_body'.tr(namedArgs: {
      'uid': user.uid, 'email': user.email ?? '',
    });
    final query = 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
    await _open(context, Uri(scheme: 'mailto', path: LegalConfig.supportEmail, query: query));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('account_privacy'.tr())),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      ListTile(leading: const Icon(Icons.privacy_tip_outlined),
        title: Text('privacy_policy'.tr()), trailing: const Icon(Icons.open_in_new),
        onTap: () => _open(context, LegalConfig.httpsUri(LegalConfig.privacyUrl))),
      ListTile(leading: const Icon(Icons.description_outlined),
        title: Text('terms_of_use'.tr()), trailing: const Icon(Icons.open_in_new),
        onTap: () => _open(context, LegalConfig.httpsUri(LegalConfig.termsUrl))),
      const Divider(height: 32),
      Text('account_delete_request'.tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Text('account_delete_notice'.tr(), style: const TextStyle(height: 1.5)),
      const SizedBox(height: 16),
      OutlinedButton.icon(onPressed: () => _requestDeletion(context),
        icon: const Icon(Icons.person_remove_outlined), label: Text('account_delete_request'.tr())),
      TextButton(onPressed: () => _draftEmail(context), child: Text('account_delete_email'.tr())),
      SelectableText(LegalConfig.supportEmail, textAlign: TextAlign.center),
      const SizedBox(height: 20),
      TextButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const MembershipScreen(),
      )), icon: const Icon(Icons.manage_accounts_outlined), label: Text('premium_manage'.tr())),
    ]),
  );
}
