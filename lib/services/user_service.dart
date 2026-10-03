import 'premium_service.dart';

class UserService {
  /// A client-written Firestore flag cannot grant a paid subscription.
  Future<bool> isPremium() => PremiumService.isPremiumUser();
}
