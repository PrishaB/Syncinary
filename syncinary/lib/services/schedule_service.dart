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

  /// Per-user marker that the current user has run the trip-setup search
  /// (origin → destination → dates) for this group, after which "Plan
  /// Itinerary" goes straight to the Schedule Builder:
  /// `groups/{groupId}/itineraryStarted/{uid}: { startedAt: Timestamp }`.
  DocumentReference<Map<String, dynamic>> _startedMarker(String groupId) =>
      _group(groupId).collection('itineraryStarted').doc(currentUserId);

  Future<bool> hasStartedItinerary(String groupId) async =>
      (await _startedMarker(groupId).get()).exists;

  Future<void> markItineraryStarted(String groupId) =>
      _startedMarker(groupId).set({'startedAt': FieldValue.serverTimestamp()});

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
    final day = DateTime(date.year, date.month, date.day);
    return _days(groupId).doc(scheduleDayKey(day)).set({'date': Timestamp.fromDate(day)});
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

  Future<void> addItem(
    String groupId, {
    required String dayKey,
    required ScheduleItemType type,
    required String title,
    String details = '',
  }) {
    return _items(groupId).add({
      'day': dayKey,
      'type': scheduleItemTypeToString(type),
      'title': title,
      'details': details,
      'addedBy': currentUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateItem(
    String groupId,
    String itemId, {
    required String title,
    required String details,
  }) {
    return _items(groupId).doc(itemId).update({'title': title, 'details': details});
  }

  Future<void> deleteItem(String groupId, String itemId) =>
      _items(groupId).doc(itemId).delete();
}
