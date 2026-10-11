import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/schedule.dart';

/// Firestore-backed data access for a trip's day-by-day schedule.
///
/// Accepts [FirebaseFirestore] / [FirebaseAuth] via constructor (mirroring
/// [ExpenseService]) so tests can pass fakes.
///
/// Schema is documented on [ScheduleDay] and [ScheduleItem] in
/// `models/schedule.dart`.
class ScheduleService {
  ScheduleService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get currentUserId => _auth.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> _group(String groupId) =>
      _firestore.collection('groups').doc(groupId);

  CollectionReference<Map<String, dynamic>> _days(String groupId) =>
      _group(groupId).collection('scheduleDays');

  CollectionReference<Map<String, dynamic>> _items(String groupId) =>
      _group(groupId).collection('scheduleItems');

  Stream<List<ScheduleDay>> daysStream(String groupId) {
    return _days(groupId)
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs.map(ScheduleDay.fromDoc).toList());
  }

  Stream<List<ScheduleItem>> itemsStream(String groupId) {
    return _items(groupId)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(ScheduleItem.fromDoc).toList());
  }

  /// Adding a day that already exists is a no-op (the doc id is the date).
  Future<void> addDay(String groupId, DateTime date) {
    final batch = _firestore.batch();
    _setDay(batch, groupId, date);
    return batch.commit();
  }

  /// Writes the day doc for [date] into [batch] and returns its key.
  String _setDay(WriteBatch batch, String groupId, DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final key = scheduleDayKey(day);
    batch.set(_days(groupId).doc(key), {'date': Timestamp.fromDate(day)});
    return key;
  }

  /// Removes the day and every item scheduled on it.
  Future<void> deleteDay(String groupId, String dayKey) async {
    final items = await _items(groupId).where('day', isEqualTo: dayKey).get();
    final batch = _firestore.batch();
    for (final doc in items.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_days(groupId).doc(dayKey));
    await batch.commit();
  }

  /// Adds an item on [date], creating that day if the trip doesn't have it yet.
  Future<void> addItem(
    String groupId, {
    required DateTime date,
    required ScheduleItemType type,
    required String title,
    String details = '',
  }) {
    final batch = _firestore.batch();
    final dayKey = _setDay(batch, groupId, date);
    batch.set(_items(groupId).doc(), {
      'day': dayKey,
      'type': scheduleItemTypeToString(type),
      'title': title,
      'details': details,
      'addedBy': currentUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return batch.commit();
  }

  /// Saves edits to an item, moving it to [date] (and creating that day) if
  /// the date changed. The day it moved from is kept, even if now empty.
  Future<void> updateItem(
    String groupId,
    String itemId, {
    required DateTime date,
    required String title,
    required String details,
  }) {
    final batch = _firestore.batch();
    final dayKey = _setDay(batch, groupId, date);
    batch.update(_items(groupId).doc(itemId),
        {'day': dayKey, 'title': title, 'details': details});
    return batch.commit();
  }

  Future<void> deleteItem(String groupId, String itemId) =>
      _items(groupId).doc(itemId).delete();
}
