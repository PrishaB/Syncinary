import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AccountService {
  AccountService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore? _firestore;

  FirebaseAuth get auth => _auth;

  // Password reset does not need Firestore (including in offline tests).
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Future<void> sendPasswordResetEmail() async {
    final email = _auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(code: 'missing-email');
    }
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Removes the profile, invitations and memberships before deleting Auth.
  /// Shared trip history stays with the group. An account must transfer admin
  /// access or delete a group before leaving it without an admin/member.
  Future<void> deleteAccount({
    required String password,
    required String expectedUserId,
  }) async {
    final user = _requireUser(expectedUserId);
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(code: 'missing-email');
    }
    if (password.isEmpty) {
      throw FirebaseAuthException(code: 'missing-password');
    }

    // Authenticate before touching any data, even with a recent session.
    await _deletionStep(
      'confirming password',
      () => user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      ),
    );
    _requireUser(expectedUserId);

    final groups = await _deletionStep(
      'loading group memberships',
      () => _db
          .collection('groups')
          .where('memberIds', arrayContains: user.uid)
          .get(const GetOptions(source: Source.server)),
    );
    final invites = _db.collection('invites');
    // Invitation rules authorize the sender UID or recipient email. A query
    // by recipientUid alone is denied, even when it would return no documents.
    final invitationQueries = await Future.wait([
      _deletionStep(
        'loading sent invitations',
        () => invites
            .where('senderUid', isEqualTo: user.uid)
            .get(const GetOptions(source: Source.server)),
      ),
      _deletionStep(
        'loading received invitations by email',
        () => invites
            .where('recipientEmail', isEqualTo: email.trim().toLowerCase())
            .get(const GetOptions(source: Source.server)),
      ),
    ]);
    final invitationRefs = {
      for (final query in invitationQueries)
        for (final doc in query.docs) doc.reference.path: doc.reference,
    };
    _requireUser(expectedUserId);

    // One transaction prevents a failed cleanup from deleting only part of
    // the Firestore data. Re-read memberships to handle concurrent role edits.
    await _deletionStep(
      'removing account data',
      () => _runDeletionTransaction((transaction) async {
        final currentGroups = await Future.wait(
          groups.docs.map((doc) => transaction.get(doc.reference)),
        );
        _requireUser(expectedUserId);
        for (final group in currentGroups) {
          if (!group.exists) continue;
          final members = Map<String, dynamic>.from(
            group.data()?['members'] as Map? ?? {},
          );
          final wasMember = members.remove(user.uid) != null;
          if (wasMember &&
              (members.isEmpty ||
                  !members.values.any(
                    (member) => member is Map && member['role'] == 'admin',
                  ))) {
            throw FirebaseAuthException(code: 'group-admin-required');
          }
        }
        for (final group in currentGroups) {
          if (!group.exists) continue;
          transaction.update(group.reference, {
            FieldPath(['members', user.uid]): FieldValue.delete(),
            'memberIds': FieldValue.arrayRemove([user.uid]),
          });
        }
        for (final ref in invitationRefs.values) {
          transaction.delete(ref);
        }
        transaction.delete(_db.collection('users').doc(user.uid));
      }),
    );

    _requireUser(expectedUserId);
    // Auth and Firestore cannot share a transaction. Keep the Auth account
    // usable for retry if this last step fails; cleanup is idempotent.
    try {
      await _deletionStep('deleting authentication account', user.delete);
    } catch (_) {
      throw FirebaseAuthException(code: 'account-delete-incomplete');
    }
  }

  Future<void> _runDeletionTransaction(
    Future<void> Function(Transaction) action,
  ) async {
    Object? callbackError;
    StackTrace? callbackStack;
    try {
      await _db.runTransaction((transaction) async {
        // Firestore may retry the callback. An earlier attempt's exception
        // must not replace a later attempt's result or commit error.
        callbackError = null;
        callbackStack = null;
        try {
          await action(transaction);
        } catch (error, stackTrace) {
          callbackError = error;
          callbackStack = stackTrace;
          rethrow;
        }
      });
    } catch (_) {
      // FlutterFire web boxes Dart callback exceptions in a JavaScript Error
      // (NativeError), hiding codes such as group-admin-required. Restore the
      // original exception without swallowing errors from the commit itself.
      if (callbackError != null) {
        Error.throwWithStackTrace(callbackError!, callbackStack!);
      }
      rethrow;
    }
  }

  // Log only the failing operation and error code, never credentials or user
  // records. Preserve the original exception for the dialog's error handling.
  Future<T> _deletionStep<T>(String step, Future<T> Function() action) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        final reason = error is FirebaseException
            ? '${error.plugin}/${error.code}'
            : error.runtimeType.toString();
        debugPrint('Account deletion failed while $step: $reason');
        if (error is! FirebaseException) {
          debugPrintStack(stackTrace: stackTrace);
        }
      }
      rethrow;
    }
  }

  User _requireUser(String expectedUserId) {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'not-signed-in');
    }
    if (user.uid != expectedUserId) {
      throw FirebaseAuthException(code: 'user-changed');
    }
    return user;
  }
}
