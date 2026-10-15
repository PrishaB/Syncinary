import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_preferences.dart';

/// Preferences belong to the signed-in account and apply across its groups.
class UserPreferencesService {
  UserPreferencesService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get currentUserId {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'not-signed-in');
    }
    return user.uid;
  }

  Future<UserPreferences> load() async {
    final document = await _firestore
        .collection('users')
        .doc(currentUserId)
        .get();
    final data = document.data()?['preferences'];
    return UserPreferences.fromMap(
      data is Map ? Map<String, dynamic>.from(data) : null,
    );
  }

  Future<void> save(
    UserPreferences preferences, {
    required String expectedUserId,
  }) async {
    final uid = currentUserId;
    // A form opened by one account must never write its draft to another.
    if (uid != expectedUserId) {
      throw FirebaseAuthException(code: 'user-changed');
    }
    await _firestore.collection('users').doc(uid).set({
      'preferences': preferences.toMap(),
    }, SetOptions(merge: true));
  }
}
