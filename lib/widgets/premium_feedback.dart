import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../preview/design_preview.dart';
import '../screens/login_screen.dart';
import '../services/premium_service.dart';
import '../services/premium_session.dart';

/// Opens the purchase screen from the current page, without an intermediate
/// membership page. The SDK is only called after a Firebase user signs in.
Future<bool> openPremiumPaywall(BuildContext context) async {
  if (DesignPreview.enabled) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('design_preview_action'.tr())),
    );
    return false;
  }

  var user = FirebaseAuth.instance.currentUser;
  if (user == null || user.isAnonymous) {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const LoginScreen(),
    ));
    if (!context.mounted) return false;
    user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return false;
  }

  try {
    return await PremiumService.showPaywall();
  } catch (error) {
    if (context.mounted) showPremiumError(context, error);
    return false;
  }
}

void showPremiumError(BuildContext context, Object error) {
  final key = switch (error) {
    PremiumSignInRequiredException() => 'premium_sign_in_required',
    PremiumAccountChangedException() => 'premium_account_changed',
    PremiumProductsUnavailableException() => 'premium_products_unavailable',
    PremiumBusyException() => 'premium_busy',
    _ => 'premium_unavailable',
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(key.tr())));
}
