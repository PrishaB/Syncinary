import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

/// Records destructive Auth calls and lets tests delay/fail either boundary.
// MockUser inherits Equatable's annotation but models mutable Auth state.
// ignore: must_be_immutable
class DeletableUser extends MockUser {
  DeletableUser() : super(uid: 'traveler', email: 'traveler@example.com');

  final credentials = <EmailAuthCredential>[];
  int deleteCalls = 0;
  FirebaseAuthException? reauthenticationError;
  Future<void> Function()? onReauthenticate;
  Future<void> Function()? onDelete;

  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential? credential,
  ) async {
    credentials.add(credential as EmailAuthCredential);
    if (reauthenticationError != null) throw reauthenticationError!;
    await onReauthenticate?.call();
    return super.reauthenticateWithCredential(credential);
  }

  @override
  Future<void> delete() async {
    deleteCalls++;
    await onDelete?.call();
  }
}
