import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

class PopupAuth extends MockFirebaseAuth {
  PopupAuth({super.mockUser});

  final providers = <AuthProvider>[];
  Future<void> Function()? beforePopup;
  Object? popupError;

  @override
  Future<UserCredential> signInWithPopup(AuthProvider provider) async {
    providers.add(provider);
    await beforePopup?.call();
    if (popupError != null) throw popupError!;
    return super.signInWithPopup(provider);
  }
}
