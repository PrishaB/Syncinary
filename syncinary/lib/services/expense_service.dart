import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/expense.dart';
import '../models/expense_split.dart';

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

  /// [splitWith] shares [amount] equally unless [splitPercentages] is supplied.
  Future<void> addExpense(
    String groupId, {
    required String name,
    required double amount,
    required List<String> splitWith,
    Map<String, double>? splitPercentages,
  }) async {
    final split = ExpenseSplit(
      splitWith: splitWith,
      percentages: splitPercentages,
    );
    final error = split.validationError;
    if (error != null) throw ArgumentError(error);
    if (name.trim().isEmpty ||
        !amount.isFinite ||
        amount <= 0 ||
        !(amount * 100).isFinite ||
        (amount * 100).round() == 0) {
      throw ArgumentError('Enter a name and a valid cost.');
    }
    final username = await _currentUsername();
    await _expenses(groupId).add({
      'name': name.trim(),
      'amount': (amount * 100).round() / 100,
      'addedBy': currentUserId,
      'addedByUsername': username,
      'splitWith': split.splitWith,
      if (split.percentages != null) 'splitPercentages': split.percentages,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteExpense(String groupId, String expenseId) =>
      _expenses(groupId).doc(expenseId).delete();
}
