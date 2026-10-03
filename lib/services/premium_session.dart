/// Serializes billing operations and prevents an account change from publishing
/// another Firebase user's subscription status.
class PremiumSession {
  PremiumSession({
    required this.currentUserId,
    required this.identify,
    required this.logOut,
    String? initialUserId,
  }) : _identifiedUserId = initialUserId;

  final String? Function() currentUserId;
  final Future<void> Function(String uid) identify;
  final Future<void> Function() logOut;
  String? _identifiedUserId;
  Future<void> _tail = Future<void>.value();

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<T> forCurrentUser<T>(Future<T> Function() action) {
    final uid = currentUserId();
    if (uid == null) {
      return Future<T>.error(const PremiumSignInRequiredException());
    }
    return _enqueue(() async {
      _requireSameUser(uid);
      if (_identifiedUserId != uid) {
        await identify(uid);
        _identifiedUserId = uid;
      }
      _requireSameUser(uid);
      final value = await action();
      _requireSameUser(uid);
      return value;
    });
  }

  Future<void> clearIdentity() => _enqueue(() async {
    try {
      await logOut();
    } finally {
      _identifiedUserId = null;
    }
  });

  void _requireSameUser(String uid) {
    if (currentUserId() != uid) throw const PremiumAccountChangedException();
  }
}

class PremiumSignInRequiredException implements Exception {
  const PremiumSignInRequiredException();
}

class PremiumAccountChangedException implements Exception {
  const PremiumAccountChangedException();
}
