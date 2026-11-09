import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// Models FlutterFire web replacing a Dart callback exception with a JS error.
/// This keeps the regression test offline while exercising the service boundary.
class WrappingTransactionFirestore extends FakeFirebaseFirestore {
  WrappingTransactionFirestore({this.onRetry, this.commitError});

  final Future<void> Function()? onRetry;
  final Object? commitError;

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    T result;
    try {
      result = await super.runTransaction(transactionHandler);
    } catch (_) {
      if (onRetry == null) throw StateError('JavaScript callback wrapper');
      await onRetry!();
      try {
        result = await super.runTransaction(transactionHandler);
      } catch (_) {
        throw StateError('JavaScript callback wrapper');
      }
    }
    if (commitError != null) throw commitError!;
    return result;
  }
}
