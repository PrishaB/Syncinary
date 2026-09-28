import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/expense.dart';

/// Firestore-backed data access for per-trip expenses.
///
/// Stateless wrapper around [FirebaseFirestore] / [FirebaseAuth] — accepts
/// both via constructor (mirroring the DI pattern used by [GroupService])
/// so tests can pass `FakeFirebaseFirestore` / `MockFirebaseAuth` instead of
/// the real singletons.
///
/// Schema is documented on [Expense] in `models/expense.dart`.
class ExpenseService {
  ExpenseService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get currentUserId => _auth.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> _expenses(String groupId) =>
      _firestore.collection('groups').doc(groupId).collection('expenses');

  Future<String> _currentUsername() async {
    final doc = await _firestore.collection('users').doc(currentUserId).get();
    return doc.data()?['username'] as String? ??
        (_auth.currentUser?.displayName ?? 'Someone');
  }

  Stream<List<Expense>> expensesStream(String groupId) {
    return _expenses(groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Expense.fromDoc).toList());
  }

  /// [splitWith] is who owes an equal share of [amount] — just the adder for
  /// a personal expense, or a chosen subset of the group to split it evenly.
  Future<void> addExpense(
    String groupId, {
    required String name,
    required double amount,
    required List<String> splitWith,
  }) async {
    final username = await _currentUsername();
    await _expenses(groupId).add({
      'name': name,
      'amount': amount,
      'addedBy': currentUserId,
      'addedByUsername': username,
      'splitWith': splitWith,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteExpense(String groupId, String expenseId) =>
      _expenses(groupId).doc(expenseId).delete();
}
