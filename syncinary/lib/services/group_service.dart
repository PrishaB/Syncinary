import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group.dart';

/// Thrown by [GroupService.inviteMemberByEmail] when nobody has a `users`
/// profile document for the given email — i.e. they haven't signed up yet.
class UserNotFoundException implements Exception {
  UserNotFoundException(this.email);
  final String email;
}

/// Firestore-backed data access for the Group feature.
///
/// Stateless wrapper around [FirebaseFirestore] / [FirebaseAuth] — accepts
/// both via constructor (mirroring the DI pattern already used by
/// `LoginPage`/`SignUpPage`) so tests can pass `FakeFirebaseFirestore` /
/// `MockFirebaseAuth` instead of the real singletons.
///
/// Schema is documented on [Group] and [GroupInvite] in `models/group.dart`.
/// The `users` collection (written by `signup_page.dart`) is:
/// `users/{uid}: { email, username, createdAt }`.
class GroupService {
  GroupService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get currentUserId => _auth.currentUser!.uid;
  String get currentUserEmail => (_auth.currentUser?.email ?? '').trim().toLowerCase();

  CollectionReference<Map<String, dynamic>> get _groups => _firestore.collection('groups');
  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _invites => _firestore.collection('invites');

  /// Maps `inviteCode -> groupId`. Exists so joining-by-code can look up a
  /// group without querying the `groups` collection directly — a query
  /// filtered on `inviteCode` isn't provably safe under the `groups` read
  /// rule (which only lets existing members read), so Firestore would deny
  /// it outright for a non-member. Doc IDs here are the invite codes
  /// themselves, so this is always a direct by-ID lookup, not a query.
  CollectionReference<Map<String, dynamic>> get _inviteCodes =>
      _firestore.collection('inviteCodes');

  Future<String> _currentUsername() async {
    final doc = await _users.doc(currentUserId).get();
    return doc.data()?['username'] as String? ??
        (_auth.currentUser?.displayName ?? currentUserEmail.split('@').first);
  }

  // ── Reads ──────────────────────────────────────────────

  Stream<List<Group>> myGroupsStream() {
    return _groups
        .where('memberIds', arrayContains: currentUserId)
        .snapshots()
        .map((snap) => snap.docs.map(Group.fromDoc).toList());
  }

  Stream<Group?> groupStream(String groupId) {
    return _groups.doc(groupId).snapshots().map((doc) => doc.exists ? Group.fromDoc(doc) : null);
  }

  Stream<List<GroupInvite>> pendingInvitesStream() {
    return _invites
        .where('recipientEmail', isEqualTo: currentUserEmail)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map(GroupInvite.fromDoc).toList());
  }

  GroupRole roleOf(Group group) => group.memberById(currentUserId)?.role ?? GroupRole.user;

  bool isAdmin(Group group) => roleOf(group) == GroupRole.admin;

  // ── Writes ─────────────────────────────────────────────

  /// Reads the group's current `members` map, lets [mutate] modify it, then
  /// writes `members` + a `memberIds` array kept in sync with its keys.
  /// Deletes the group doc entirely if [mutate] empties the member list.
  ///
  /// This is a read-then-write rather than a transaction: two admins editing
  /// membership at the exact same instant could race. Acceptable for a
  /// small-group travel app; revisit with `runTransaction` (or a Cloud
  /// Function) if that ever becomes a real concern.
  Future<void> _updateMembers(
    String groupId,
    void Function(Map<String, Map<String, dynamic>> members) mutate,
  ) async {
    final ref = _groups.doc(groupId);
    final snap = await ref.get();
    final data = Map<String, dynamic>.from(snap.data() ?? const {});
    final raw = data['members'] as Map<String, dynamic>? ?? const {};
    final members = raw.map(
      (key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)),
    );
    mutate(members);
    if (members.isEmpty) {
      await ref.delete();
    } else {
      // set() rather than update(): passing a nested map to update() gets
      // deep-merged by some Firestore client/test implementations instead of
      // replacing the field outright, which would silently resurrect a
      // removed member. set() with the full document data avoids that.
      data['members'] = members;
      data['memberIds'] = members.keys.toList();
      await ref.set(data);
    }
  }

  Future<Group> createGroup(String name) async {
    final username = await _currentUsername();
    final ref = _groups.doc();
    final inviteCode = ref.id.substring(0, 6).toUpperCase();
    await ref.set({
      'name': name,
      'inviteCode': inviteCode,
      'createdAt': FieldValue.serverTimestamp(),
      'memberIds': [currentUserId],
      'members': {
        currentUserId: {'username': username, 'email': currentUserEmail, 'role': 'admin'},
      },
    });
    await _inviteCodes.doc(inviteCode).set({'groupId': ref.id});
    final snap = await ref.get();
    return Group.fromDoc(snap);
  }

  Future<void> renameGroup(Group group, String newName) =>
      _groups.doc(group.id).update({'name': newName});

  Future<void> leaveGroup(Group group) =>
      _updateMembers(group.id, (members) => members.remove(currentUserId));

  Future<void> deleteGroup(Group group) => _groups.doc(group.id).delete();

  Future<void> removeMember(Group group, GroupMember member) =>
      _updateMembers(group.id, (members) => members.remove(member.id));

  Future<void> transferAdmin(Group group, GroupMember newAdmin) =>
      _updateMembers(group.id, (members) {
        members[currentUserId]?['role'] = 'user';
        members[newAdmin.id]?['role'] = 'admin';
      });

  /// Looks the invitee up in `users` by email and creates a pending invite
  /// for them — they must accept it from the Join Group screen. Throws
  /// [UserNotFoundException] if nobody has signed up with that email yet.
  Future<void> inviteMemberByEmail(Group group, String email, GroupRole role) async {
    final trimmed = email.trim().toLowerCase();
    final matches = await _users.where('email', isEqualTo: trimmed).limit(1).get();
    if (matches.docs.isEmpty) {
      throw UserNotFoundException(trimmed);
    }
    final recipient = matches.docs.first;
    final senderUsername = await _currentUsername();

    await _invites.add({
      'groupId': group.id,
      'groupName': group.name,
      'senderUid': currentUserId,
      'senderUsername': senderUsername,
      'recipientUid': recipient.id,
      'recipientEmail': trimmed,
      'role': groupRoleToString(role),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Adds the current user to a group they're not a member of yet, without
  /// reading the group doc first — the `groups` read rule only allows
  /// existing members, so a prior `.get()` would be denied for a joiner.
  /// `arrayUnion` + a dotted-path field update let Firestore apply this
  /// server-side against the doc it already has, so only "write" permission
  /// is needed, not "read".
  Future<void> _joinAsMember(String groupId, {required GroupRole role}) async {
    final username = await _currentUsername();
    await _groups.doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([currentUserId]),
      'members.$currentUserId': {
        'username': username,
        'email': currentUserEmail,
        'role': groupRoleToString(role),
      },
    });
  }

  Future<bool> joinByCode(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) return false;
    final mapping = await _inviteCodes.doc(trimmed).get();
    final groupId = mapping.data()?['groupId'] as String?;
    if (groupId == null) return false;

    await _joinAsMember(groupId, role: GroupRole.user);
    return true;
  }

  Future<void> acceptInvite(GroupInvite invite) async {
    await _joinAsMember(invite.groupId, role: invite.role);
    await _invites.doc(invite.id).delete();
  }

  Future<void> declineInvite(GroupInvite invite) => _invites.doc(invite.id).delete();
}
