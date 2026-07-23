import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

class PremiumService {
  static const String entitlementId = 'KyrgyzTest Pro';

  /// Инициализация RevenueCat. Для каждой платформы используется свой public SDK key.
  static Future<void> init() async {
    String apiKey;

    if (Platform.isAndroid) {
      apiKey = 'goog_jAlsAgpZXlSPVxckpWjzBFPoNRR';
    } else if (Platform.isIOS) {
      apiKey = 'appl_ТВОЙ_IOS_KEY';
    } else {
      throw UnsupportedError('Platform not supported');
    }

    await Purchases.configure(PurchasesConfiguration(apiKey));
  }

  /// Привязывает покупки к Firebase UID, чтобы Premium восстанавливался
  /// после переустановки приложения или входа на другом устройстве.
  static Future<void> syncUserWithRevenueCat() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await Purchases.logIn(user.uid);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RevenueCat login error: $e');
      }
    }
  }

  static bool _hasPremium(CustomerInfo customerInfo) {
    return customerInfo.entitlements.active.containsKey(entitlementId);
  }

  static Future<bool> isPremiumUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      // Локальный debug-доступ владельца. В release-сборке не работает.
      if (kDebugMode && user?.email == 'askatimm@gmail.com') {
        return true;
      }

      final customerInfo = await Purchases.getCustomerInfo();
      return _hasPremium(customerInfo);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Premium check error: $e');
      }
      return false;
    }
  }

  /// Показывает RevenueCat Paywall и возвращает актуальный Premium-статус.
  static Future<bool> showPaywall() async {
    try {
      await RevenueCatUI.presentPaywall();
      final customerInfo = await Purchases.getCustomerInfo();
      return _hasPremium(customerInfo);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Paywall error: $e');
      }
      return false;
    }
  }

  /// Вызывается только по нажатию пользователя «Восстановить покупки».
  static Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      return _hasPremium(customerInfo);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Restore purchases error: $e');
      }
      return false;
    }
  }

  static Future<void> logOut() async {
    try {
      await Purchases.logOut();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RevenueCat logout error: $e');
      }
    }
  }
}
