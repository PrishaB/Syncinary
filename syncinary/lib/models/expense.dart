import 'package:cloud_firestore/cloud_firestore.dart';

/// Backed by a document in the `groups/{groupId}/expenses` subcollection:
/// ```
/// groups/{groupId}/expenses/{expenseId}: {
///   name: string,
///   amount: number,
///   addedBy: uid,
///   addedByUsername: string,
///   splitWith: [uid, ...],   // members who owe an equal share; defaults to [addedBy]
///   createdAt: Timestamp,
/// }
/// ```
class Expense {
  Expense({
    required this.id,
    required this.name,
    required this.amount,
    required this.addedBy,
    required this.addedByUsername,
    required this.splitWith,
  });

  final String id;
  final String name;
  final double amount;
  final String addedBy;
  final String addedByUsername;
  final List<String> splitWith;

  factory Expense.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final addedBy = data['addedBy'] as String? ?? '';
    final rawSplitWith = data['splitWith'] as List?;
    return Expense(
      id: doc.id,
      name: data['name'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      addedBy: addedBy,
      addedByUsername: data['addedByUsername'] as String? ?? 'Someone',
      splitWith: rawSplitWith != null && rawSplitWith.isNotEmpty
          ? rawSplitWith.cast<String>()
          : [addedBy],
    );
  }
}
