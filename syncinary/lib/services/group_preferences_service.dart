import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/group_preferences_summary.dart';
import '../models/user_preferences.dart';

class GroupPreferencesAccessException implements Exception {
  const GroupPreferencesAccessException();
}

/// Combines current members' saved preferences for the summary screen.
///
/// Membership/session checks here protect the UI, not Firestore itself. This
/// uses the existing users collection; production access control must be
/// enforced by Firestore rules or moved to a server-side aggregate endpoint.
/// Never broaden users-document read permissions just to enable this screen.
class GroupPreferencesService {
  GroupPreferencesService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Null clears the previous summary while membership/preferences reload.
  /// An error clears the UI rather than displaying an incomplete aggregate.
  Stream<GroupPreferencesSummary?> watchSummary(String groupId) {
    late final StreamController<GroupPreferencesSummary?> controller;
    StreamSubscription<User?>? authSubscription;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
    groupSubscription;
    final memberSubscriptions =
        <StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>[];
    var generation = 0;
    var stopped = false;

    Future<void> cancelMembers() async {
      final previous = memberSubscriptions.toList();
      memberSubscriptions.clear();
      await Future.wait(previous.map((subscription) => subscription.cancel()));
    }

    void denyAccess() {
      if (stopped) return;
      stopped = true;
      generation++;
      controller.addError(const GroupPreferencesAccessException());
      unawaited(cancelMembers());
      unawaited(groupSubscription?.cancel());
    }

    void start() {
      final user = _auth.currentUser;
      if (user == null || !user.emailVerified) {
        denyAccess();
        return;
      }
      final uid = user.uid;
      bool sameUser() =>
          _auth.currentUser?.uid == uid &&
          _auth.currentUser?.emailVerified == true;

      authSubscription = _auth.authStateChanges().listen((current) {
        if (current?.uid != uid || current?.emailVerified != true) denyAccess();
      }, onError: (Object error) => denyAccess());

      groupSubscription = _firestore
          .collection('groups')
          .doc(groupId)
          .snapshots()
          .listen(
            (document) {
              if (stopped) return;
              final data = document.data();
              final members = data?['members'];
              final memberIds = data?['memberIds'];
              if (!sameUser() ||
                  members is! Map ||
                  memberIds is! List ||
                  !members.containsKey(uid) ||
                  !memberIds.contains(uid)) {
                denyAccess();
                return;
              }
              final ids = members.keys
                  .whereType<String>()
                  .where(memberIds.contains)
                  .toSet();
              final version = ++generation;
              controller.add(null);
              // Generation checks invalidate old callbacks immediately; new
              // reads need not wait for the previous listeners to tear down.
              unawaited(cancelMembers());
              final loaded = <String, UserPreferences>{};
              for (final id in ids) {
                memberSubscriptions.add(
                  _firestore
                      .collection('users')
                      .doc(id)
                      .snapshots()
                      .listen(
                        (snapshot) {
                          if (stopped || version != generation) return;
                          if (!sameUser()) {
                            denyAccess();
                            return;
                          }
                          final raw = snapshot.data()?['preferences'];
                          loaded[id] = UserPreferences.fromMap(
                            raw is Map ? Map<String, dynamic>.from(raw) : null,
                          );
                          if (loaded.length == ids.length) {
                            controller.add(
                              GroupPreferencesSummary.fromPreferences(
                                loaded.values,
                              ),
                            );
                          }
                        },
                        onError: (Object error, StackTrace stack) {
                          if (stopped || version != generation) return;
                          // Prevent other member events from restoring stale results.
                          loaded.remove(id);
                          controller.addError(error, stack);
                        },
                      ),
                );
              }
            },
            onError: (Object error, StackTrace stack) {
              if (stopped) return;
              generation++;
              unawaited(cancelMembers());
              controller.addError(error, stack);
            },
          );
    }

    controller = StreamController<GroupPreferencesSummary?>(
      onListen: start,
      onCancel: () async {
        stopped = true;
        generation++;
        await authSubscription?.cancel();
        await groupSubscription?.cancel();
        await cancelMembers();
      },
    );
    return controller.stream;
  }
}
