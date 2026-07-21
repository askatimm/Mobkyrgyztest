import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';

class PremiumService {
  /// 🔥 Инициализация RevenueCat (только configure!)
  static Future<void> init() async {
    debugPrint("=== PREMIUM INIT START ===");

    String apiKey;

    if (Platform.isAndroid) {
      apiKey = 'goog_jAlsAgpZXlSPVxckpWjzBFPoNRR'; // вставь полный ключ
    } else if (Platform.isIOS) {
      apiKey = 'appl_ТВОЙ_IOS_KEY';
    } else {
      throw UnsupportedError('Platform not supported');
    }

    await Purchases.configure(PurchasesConfiguration(apiKey));

    debugPrint("RC CONFIGURED");
    debugPrint("=== PREMIUM INIT END ===");
  }

  /// 🔗 Синхронизация Firebase пользователя с RevenueCat
  static Future<void> syncUserWithRevenueCat() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint("RC LOGIN SKIPPED: no user");
        return;
      }

      final result = await Purchases.logIn(user.uid);

      debugPrint(
        "RC USER: ${result.customerInfo.originalAppUserId}",
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint("RC LOGIN ERROR: $e");
      }
    }
  }

  /// ✅ Проверка премиума
  static Future<bool> isPremiumUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      // 🔥 временно для тебя (dev режим)
      if (kDebugMode && user?.email == "askatimm@gmail.com") {
        return true;
      }

      final customerInfo = await Purchases.getCustomerInfo();

      return customerInfo.entitlements.active.containsKey('KyrgyzTest Pro');
    } catch (e) {
      if (kDebugMode) {
        debugPrint("CHECK PREMIUM ERROR: $e");
      }
      return false;
    }
  }

  /// 💳 Покупка (пока можно не использовать)
  static Future<void> showPaywall() async {
    try {
      await RevenueCatUI.presentPaywall();

      final customerInfo = await Purchases.getCustomerInfo();

      final isPremium = customerInfo.entitlements.active.containsKey(
        'KyrgyzTest Pro',
      );

      await UserService().setPremium(isPremium);

      debugPrint("PAYWALL RESULT: $isPremium");
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Paywall error: $e');
      }
    }
  }
}