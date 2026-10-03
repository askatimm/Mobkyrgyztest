import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/legal_config.dart';
import '../preview/design_preview.dart';
import '../services/premium_service.dart';
import '../widgets/premium_feedback.dart';
import '../widgets/video_design.dart';
import 'login_screen.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _statusUnavailable = false;

  bool get _signedIn => !DesignPreview.enabled &&
      FirebaseAuth.instance.currentUser != null &&
      !FirebaseAuth.instance.currentUser!.isAnonymous;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!DesignPreview.enabled) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy && !DesignPreview.enabled) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await PremiumService.refreshStatus(forceRefresh: true);
      if (mounted) setState(() => _statusUnavailable = false);
    } catch (_) {
      if (mounted) setState(() => _statusUnavailable = _signedIn);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _billing({bool restore = false}) async {
    if (_busy) return;
    if (DesignPreview.enabled) {
      _notice('design_preview_action');
      return;
    }
    if (!_signedIn) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(),
      ));
      if (mounted) await _refresh();
      return;
    }
    setState(() => _busy = true);
    try {
      final active = restore
          ? await PremiumService.restorePurchases()
          : await PremiumService.showPaywall();
      if (!mounted) return;
      setState(() => _statusUnavailable = false);
      if (restore) _notice(active ? 'premium_restored' : 'premium_no_purchases');
      if (!restore && active) _notice('premium_purchase_success');
    } catch (error) {
      if (mounted) showPremiumError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String key) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(key.tr())));
  }

  Future<void> _openUrl(Uri? uri) async {
    if (DesignPreview.enabled) { _notice('design_preview_action'); return; }
    try {
      if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) _notice('legal_link_unavailable');
      }
    } catch (_) {
      if (mounted) _notice('legal_link_unavailable');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('premium_membership'.tr())),
      body: SafeArea(child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620),
          child: ValueListenableBuilder<bool>(
            valueListenable: PremiumService.premiumStatus,
            builder: (context, active, _) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (DesignPreview.enabled) ...[
                  const DesignPreviewNotice(), const SizedBox(height: 16),
                ],
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: LearningColors.ink,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PremiumBadge(), const SizedBox(height: 20),
                      Text('premium_membership_title'.tr(), style: const TextStyle(
                        fontSize: 26, height: 1.2, color: Colors.white,
                        fontWeight: FontWeight.w800,
                      )),
                      const SizedBox(height: 12),
                      Text('premium_membership_detail'.tr(), style: const TextStyle(
                        color: Colors.white70, height: 1.5,
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text((_busy ? 'premium_checking' : _statusUnavailable
                    ? 'premium_status_unavailable' : active
                    ? 'premium_active' : 'premium_inactive').tr(),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                const SizedBox(height: 12),
                if (_statusUnavailable)
                  TextButton.icon(onPressed: _busy ? null : _refresh,
                    icon: const Icon(Icons.refresh_rounded), label: Text('retry'.tr())),
                if (!_signedIn && !DesignPreview.enabled) ...[
                  Text('premium_sign_in_required'.tr()), const SizedBox(height: 12),
                ],
                if (!active)
                  FilledButton(
                    onPressed: _busy ? null : () => _billing(),
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text((_signedIn || DesignPreview.enabled
                          ? 'video_open_paywall' : 'premium_sign_in').tr())),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _billing(restore: true),
                  icon: const Icon(Icons.restore_rounded),
                  label: Text('premium_restore'.tr()),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : () => _openUrl(Uri.parse(
                    'https://play.google.com/store/account/subscriptions')),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text('premium_manage'.tr()),
                ),
                const SizedBox(height: 12),
                Text('premium_store_notice'.tr(), style: const TextStyle(
                  color: LearningColors.muted, height: 1.5, fontSize: 13)),
                const SizedBox(height: 12),
                Wrap(spacing: 12, children: [
                  TextButton(onPressed: () => _openUrl(LegalConfig.httpsUri(LegalConfig.privacyUrl)),
                    child: Text('privacy_policy'.tr())),
                  TextButton(onPressed: () => _openUrl(LegalConfig.httpsUri(LegalConfig.termsUrl)),
                    child: Text('terms_of_use'.tr())),
                ]),
              ],
            ),
          ),
        ),
      )),
    );
  }
}
