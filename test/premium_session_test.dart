import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyrgyztestapp/services/premium_session.dart';

void main() {
  test('a guest cannot start a purchase or restore', () async {
    var calls = 0;
    final session = PremiumSession(
      currentUserId: () => null,
      identify: (_) async { calls++; }, logOut: () async {},
    );
    await expectLater(session.forCurrentUser(() async { calls++; }),
      throwsA(isA<PremiumSignInRequiredException>()));
    expect(calls, 0);
  });

  test('a returning Firebase account is kept at startup', () async {
    final identified = <String>[];
    final session = PremiumSession(
      currentUserId: () => 'returning-user', initialUserId: 'returning-user',
      identify: (uid) async { identified.add(uid); }, logOut: () async {},
    );
    expect(await session.forCurrentUser(() async => true), isTrue);
    expect(identified, isEmpty);
  });

  test('failed login never falls back to the previous billing identity', () async {
    var attempts = 0;
    var purchases = 0;
    final session = PremiumSession(
      currentUserId: () => 'new-user', initialUserId: 'old-user',
      identify: (_) async {
        attempts++;
        if (attempts == 1) throw StateError('offline');
      },
      logOut: () async {},
    );
    Future<bool> purchase() async { purchases++; return true; }
    await expectLater(session.forCurrentUser(purchase), throwsStateError);
    expect(purchases, 0);
    expect(await session.forCurrentUser(purchase), isTrue);
    expect(attempts, 2);
    expect(purchases, 1);
  });

  test('an account switch during login prevents the purchase', () async {
    String? uid = 'first';
    var purchased = false;
    final session = PremiumSession(
      currentUserId: () => uid,
      identify: (_) async { uid = 'second'; }, logOut: () async {},
    );
    await expectLater(session.forCurrentUser(() async { purchased = true; }),
      throwsA(isA<PremiumAccountChangedException>()));
    expect(purchased, isFalse);
  });

  test('a delayed purchase cannot publish Premium for the next account', () async {
    String? uid = 'first';
    var sdkUid = 'first';
    final started = Completer<void>();
    final complete = Completer<void>();
    final session = PremiumSession(
      currentUserId: () => uid, initialUserId: uid,
      identify: (value) async { sdkUid = value; }, logOut: () async {},
    );
    final pending = session.forCurrentUser(() async {
      started.complete(); await complete.future;
      return true;
    });
    final assertion = expectLater(pending, throwsA(isA<PremiumAccountChangedException>()));
    await started.future;
    uid = 'second';
    final nextStatus = session.forCurrentUser(() async => sdkUid);
    complete.complete();
    await assertion;
    expect(await nextStatus, 'second');
  });

  test('a queued operation for an account that signed out is discarded', () async {
    String? uid = 'first';
    final started = Completer<void>();
    final complete = Completer<void>();
    var queuedRan = false;
    final session = PremiumSession(
      currentUserId: () => uid, initialUserId: uid,
      identify: (_) async {}, logOut: () async {},
    );
    final first = session.forCurrentUser(() async {
      started.complete(); await complete.future;
    });
    final firstAssertion = expectLater(first, throwsA(isA<PremiumAccountChangedException>()));
    await started.future;
    final queued = session.forCurrentUser(() async { queuedRan = true; });
    final queuedAssertion = expectLater(queued, throwsA(isA<PremiumAccountChangedException>()));
    uid = null;
    complete.complete();
    await firstAssertion;
    await queuedAssertion;
    expect(queuedRan, isFalse);
  });

  test('logout clears the cached identity even when the SDK is offline', () async {
    final logins = <String>[];
    final session = PremiumSession(
      currentUserId: () => 'first', initialUserId: 'first',
      identify: (uid) async { logins.add(uid); },
      logOut: () async { throw StateError('offline'); },
    );
    await expectLater(session.clearIdentity(), throwsStateError);
    await session.forCurrentUser(() async => true);
    expect(logins, ['first']);
  });
}
