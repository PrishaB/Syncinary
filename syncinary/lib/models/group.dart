import 'package:cloud_firestore/cloud_firestore.dart';

enum GroupRole { admin, user }

GroupRole groupRoleFromString(String? value) =>
    value == 'admin' ? GroupRole.admin : GroupRole.user;

String groupRoleToString(GroupRole role) =>
    role == GroupRole.admin ? 'admin' : 'user';

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
        username: map['username'] as String? ?? 'Unknown',
        email: map['email'] as String? ?? '',
        role: groupRoleFromString(map['role'] as String?),
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
    final rawMembers = data['members'] as Map<String, dynamic>? ?? const {};
    return Group(
      id: doc.id,
      name: data['name'] as String? ?? '',
      inviteCode: data['inviteCode'] as String?,
      members: rawMembers.entries
          .map((e) => GroupMember.fromMap(e.key, Map<String, dynamic>.from(e.value as Map)))
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
      senderUsername: data['senderUsername'] as String? ?? 'Someone',
      groupId: data['groupId'] as String? ?? '',
      groupName: data['groupName'] as String? ?? '',
      role: groupRoleFromString(data['role'] as String?),
    );
  }
}
