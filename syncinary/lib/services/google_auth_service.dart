import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firebase's web popup handles both new and returning Google accounts.
class GoogleAuthService {
  GoogleAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore? _firestore;

  /// Call from a web button's click handler so browsers allow the popup.
  /// A dismissed popup returns null without creating a profile.
  Future<User?> signIn() async {
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    final UserCredential credential;
    try {
      credential = await _auth.signInWithPopup(provider);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request') {
        return null;
      }
      rethrow;
    }

    final user = credential.user;
    if (user == null) throw FirebaseAuthException(code: 'missing-user');

    try {
      final db = _firestore ?? FirebaseFirestore.instance;
      final ref = db.collection('users').doc(user.uid);
      // Preserve the existing username, preferences and creation time, including
      // when Firebase links Google to an existing email/password account.
      await db.runTransaction((transaction) async {
        if ((await transaction.get(ref)).exists) return;
        final email = (user.email ?? '').trim().toLowerCase();
        final name = user.displayName?.trim();
        transaction.set(ref, {
          'username': name != null && name.isNotEmpty
              ? name
              : email.split('@').first,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {
      // Leave the Auth account available for retry, but end this session if
      // profile setup failed. Never sign out a replacement session.
      if (_auth.currentUser?.uid == user.uid) await _auth.signOut();
      throw FirebaseAuthException(code: 'profile-unavailable');
    }
    return _auth.currentUser?.uid == user.uid ? user : null;
  }
}
