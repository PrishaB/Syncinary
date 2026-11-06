import 'package:cloud_firestore/cloud_firestore.dart';

enum GroupRole { admin, user }

GroupRole groupRoleFromString(String? value) =>
    value == 'admin' ? GroupRole.admin : GroupRole.user;

String groupRoleToString(GroupRole role) =>
    role == GroupRole.admin ? 'admin' : 'user';

/// Firestore data isn't type-checked, so a field can hold anything. These
/// treat a wrongly typed value the same as a missing one.
String? _stringOrNull(Object? value) => value is String ? value : null;

Map<String, dynamic> _mapOrEmpty(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

class GroupMember {
  GroupMember({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
  });

  final String id;
  final String username;
  final String email;
  GroupRole role;

  factory GroupMember.fromMap(String id, Map<String, dynamic> map) => GroupMember(
        id: id,
        username: _stringOrNull(map['username']) ?? 'Unknown',
        email: _stringOrNull(map['email']) ?? '',
        role: groupRoleFromString(_stringOrNull(map['role'])),
      );

  Map<String, dynamic> toMap() => {
        'username': username,
        'email': email,
        'role': groupRoleToString(role),
      };
}

/// Backed by a document in the top-level `groups` collection:
/// ```
/// groups/{groupId}: {
///   name: string,
///   inviteCode: string,
///   createdAt: Timestamp,
///   memberIds: [uid, ...],           // kept in sync with members.keys for array-contains queries
///   members: { uid: {username, email, role}, ... },
/// }
/// ```
class Group {
  Group({
    required this.id,
    required this.name,
    required this.members,
    this.inviteCode,
  });

  final String id;
  String name;
  String? inviteCode;
  final List<GroupMember> members;

  GroupMember? memberById(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  factory Group.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final rawMembers = _mapOrEmpty(data['members']);
    return Group(
      id: doc.id,
      name: _stringOrNull(data['name']) ?? '',
      inviteCode: _stringOrNull(data['inviteCode']),
      members: rawMembers.entries
          .map((e) => GroupMember.fromMap(e.key, _mapOrEmpty(e.value)))
          .toList(),
    );
  }
}

/// Backed by a document in the top-level `invites` collection:
/// ```
/// invites/{inviteId}: {
///   groupId, groupName, senderUid, senderUsername,
///   recipientUid, recipientEmail, role, status: 'pending', createdAt
/// }
/// ```
class GroupInvite {
  GroupInvite({
    required this.id,
    required this.senderUsername,
    required this.groupId,
    required this.groupName,
    required this.role,
  });

  final String id;
  final String senderUsername;
  final String groupId;
  final String groupName;
  final GroupRole role;

  factory GroupInvite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return GroupInvite(
      id: doc.id,
      senderUsername: _stringOrNull(data['senderUsername']) ?? 'Someone',
      groupId: _stringOrNull(data['groupId']) ?? '',
      groupName: _stringOrNull(data['groupName']) ?? '',
      role: groupRoleFromString(_stringOrNull(data['role'])),
    );
  }
}
