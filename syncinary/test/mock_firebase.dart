import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';

/// Call this at the top of main() in every test file that touches Firebase.
void setupFirebaseAuthMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
}

/// Generate mocks for the Firebase types used across test files.
@GenerateMocks([FirebaseAuth, UserCredential, User])
void main() {}
