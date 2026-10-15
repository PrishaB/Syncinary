import 'package:firebase_auth/firebase_auth.dart';

class AccountService {
  AccountService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<void> sendPasswordResetEmail() async {
    final email = _auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(code: 'missing-email');
    }
    await _auth.sendPasswordResetEmail(email: email);
  }
}
