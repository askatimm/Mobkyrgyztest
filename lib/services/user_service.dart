import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🔍 Проверка: является ли пользователь Premium
  Future<bool> isPremium() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return false;

    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return false;

    return doc.data()?['isPremium'] == true;
  }

  /// 💾 Сохранение статуса Premium
  Future<void> setPremium(bool value) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).set(
      {
        'isPremium': value,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}