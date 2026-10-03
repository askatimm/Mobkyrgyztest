import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../config/premium_config.dart';
import 'premium_session.dart';

class PremiumService {
  /// UI status only. Firebase Functions independently authorize every video URL.
  static final ValueNotifier<bool> premiumStatus = ValueNotifier(false);
  static bool _configured = false;
  static bool _billingBusy = false;
  static PremiumSession? _session;
  static StreamSubscription<User?>? _authSubscription;

  static String? get _currentUid {
    final user = FirebaseAuth.instance.currentUser;
    return user == null || user.isAnonymous ? null : user.uid;
  }

  /// Call once, after Firebase initialization. Missing iOS configuration does
  /// not prevent users from opening the rest of the app.
  static Future<void> init() async {
    if (_configured || kIsWeb) return;
    final android = defaultTargetPlatform == TargetPlatform.android;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (!android && !ios) return;
    final key = android ? PremiumConfig.androidApiKey : PremiumConfig.iosApiKey;
    if (!PremiumConfig.isValidSdkKey(key, android ? 'goog_' : 'appl_',
        release: kReleaseMode)) {
      if (kDebugMode) debugPrint('RevenueCat SDK key is not configured.');
      return;
    }

    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);
      final uid = _currentUid;
      await Purchases.configure(PurchasesConfiguration(key)..appUserID = uid);
      _session = PremiumSession(
        initialUserId: uid,
        currentUserId: () => _currentUid,
        identify: (uid) async { await Purchases.logIn(uid); },
        logOut: () async {
          if (!await Purchases.isAnonymous) await Purchases.logOut();
        },
      );
      _configured = true;
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
        premiumStatus.value = false;
        unawaited(syncUserWithRevenueCat());
      });
      await syncUserWithRevenueCat();
    } catch (error) {
      if (kDebugMode) debugPrint('RevenueCat initialization failed: $error');
    }
  }

  /// Authentication succeeds even if billing is temporarily offline. Purchase
  /// and restore operations always require successful identity synchronization.
  static Future<void> syncUserWithRevenueCat({bool forceRefresh = false}) async {
    if (!_configured) return;
    try {
      if (_currentUid == null) {
        premiumStatus.value = false;
        await _session!.clearIdentity();
      } else {
        await refreshStatus(forceRefresh: forceRefresh);
      }
    } catch (error) {
      premiumStatus.value = false;
      if (kDebugMode) debugPrint('RevenueCat synchronization failed: $error');
    }
  }

  static void _requireConfigured() {
    if (!_configured || _session == null) {
      throw const PremiumUnavailableException();
    }
  }

  static Future<bool> refreshStatus({bool forceRefresh = false}) async {
    _requireConfigured();
    final uid = _currentUid;
    if (uid == null) {
      premiumStatus.value = false;
      return false;
    }
    final info = await _session!.forCurrentUser(() async {
      if (forceRefresh) await Purchases.invalidateCustomerInfoCache();
      return Purchases.getCustomerInfo();
    });
    return _updateStatus(info, uid);
  }

  static bool _updateStatus(CustomerInfo info, String uid) {
    if (_currentUid != uid) throw const PremiumAccountChangedException();
    final active = info.entitlements.active.containsKey(PremiumConfig.entitlementId);
    premiumStatus.value = active;
    return active;
  }

  static Future<bool> isPremiumUser() async {
    try {
      return await refreshStatus();
    } catch (_) {
      premiumStatus.value = false;
      return false;
    }
  }

  static Future<bool> _runBilling(Future<CustomerInfo> Function(String uid) action) async {
    final uid = _currentUid;
    if (uid == null) throw const PremiumSignInRequiredException();
    _requireConfigured();
    if (_billingBusy) throw const PremiumBusyException();
    _billingBusy = true;
    try {
      final info = await _session!.forCurrentUser(() => action(uid));
      return _updateStatus(info, uid);
    } finally {
      _billingBusy = false;
    }
  }

  static Future<bool> showPaywall() => _runBilling((uid) async {
    final existing = await Purchases.getCustomerInfo();
    if (existing.entitlements.active.containsKey(PremiumConfig.entitlementId)) {
      return existing;
    }
    final offerings = await Purchases.getOfferings();
    final offering = PremiumConfig.offeringId.isEmpty
        ? offerings.current : offerings.all[PremiumConfig.offeringId];
    if (_currentUid != uid) throw const PremiumAccountChangedException();
    if (offering == null || offering.availablePackages.isEmpty) {
      throw const PremiumProductsUnavailableException();
    }
    final result = await RevenueCatUI.presentPaywall(
      offering: offering, displayCloseButton: true,
    );
    if (result == PaywallResult.error) throw const PremiumUnavailableException();
    await Purchases.invalidateCustomerInfoCache();
    return Purchases.getCustomerInfo();
  });

  /// Restore can display an OS prompt; call only after a user's explicit tap.
  static Future<bool> restorePurchases() => _runBilling((_) => Purchases.restorePurchases());

  static Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
  }
}

class PremiumUnavailableException implements Exception {
  const PremiumUnavailableException();
}

class PremiumProductsUnavailableException implements Exception {
  const PremiumProductsUnavailableException();
}

class PremiumBusyException implements Exception {
  const PremiumBusyException();
}
