import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/premium_service.dart';
import '../services/premium_session.dart';

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
