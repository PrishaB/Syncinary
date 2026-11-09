import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group.dart';
import '../models/schedule.dart';
import 'group_preferences_service.dart';
import '../models/trip_location.dart';
import 'recommendation_to_schedule.dart';

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

  GroupPreferencesService get groupPreferencesService =>
      GroupPreferencesService(firestore: _firestore, auth: _auth);

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

  /// Admin only: removes the day and every item scheduled on it.
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
  ///
  /// Members add with [ScheduleItemStatus.suggested]; only the admin may add
  /// [ScheduleItemStatus.approved] items (the Firestore rules enforce this).
  Future<void> addItem(
    String groupId, {
    required DateTime date,
    required ScheduleItemType type,
    required String title,
    String details = '',
    ScheduleItemStatus status = ScheduleItemStatus.approved,
    TripLocation? location,
  }) {
    if (location != null && !location.isValid) {
      throw ArgumentError('Invalid trip location');
    }
    final batch = _firestore.batch();
    final dayKey = _setDay(batch, groupId, date);
    batch.set(_items(groupId).doc(), {
      ..._itemData(dayKey, type, title, details, status),
      if (location != null) 'location': location.toMap(),
    });
    return batch.commit();
  }

  /// Most writes Firestore allows in one batch.
  static const maxBatchWrites = 500;

  /// Adds every item, and the days they need, in one atomic batch, tagged as
  /// AI-sourced from [sourceDestination]. Throws [ArgumentError], writing
  /// nothing, if that would exceed [maxBatchWrites].
  Future<void> addItems(
    String groupId,
    List<PendingScheduleItem> items, {
    required ScheduleItemStatus status,
    required String sourceDestination,
  }) {
    if (items.isEmpty) return Future.value();
    final dayKeys = {for (final item in items) scheduleDayKey(item.date)};
    if (items.length + dayKeys.length > maxBatchWrites) {
      throw ArgumentError('Too many schedule items for one batch');
    }
    final batch = _firestore.batch();
    final seen = <String>{};
    for (final item in items) {
      final dayKey = scheduleDayKey(item.date);
      if (seen.add(dayKey)) _setDay(batch, groupId, item.date);
      batch.set(_items(groupId).doc(), {
        ..._itemData(dayKey, item.type, item.title, item.details, status),
        'source': 'ai',
        'sourceDestination': sourceDestination,
      });
    }
    return batch.commit();
  }

  Map<String, dynamic> _itemData(
    String dayKey,
    ScheduleItemType type,
    String title,
    String details,
    ScheduleItemStatus status,
  ) =>
      {
        'day': dayKey,
        'type': scheduleItemTypeToString(type),
        'title': title,
        'details': details,
        'addedBy': currentUserId,
        'status': scheduleItemStatusToString(status),
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// Admin only: moves a suggestion onto the itinerary. Rejecting one is
  /// [deleteItem].
  Future<void> approveItem(String groupId, String itemId) => _items(groupId)
      .doc(itemId)
      .update({'status': scheduleItemStatusToString(ScheduleItemStatus.approved)});

  /// Saves edits to an item, moving it to [date] (and creating that day) if
  /// the date changed. The day it moved from is kept, even if now empty.
  Future<void> updateItem(
    String groupId,
    String itemId, {
    required DateTime date,
    required String title,
    required String details,
    TripLocation? location,
    bool clearLocation = false,
  }) {
    if (location != null && !location.isValid) {
      throw ArgumentError('Invalid trip location');
    }
    final batch = _firestore.batch();
    final dayKey = _setDay(batch, groupId, date);
    batch.update(_items(groupId).doc(itemId), {
      'day': dayKey,
      'title': title,
      'details': details,
      if (location != null) 'location': location.toMap(),
      if (clearLocation) 'location': FieldValue.delete(),
    });
    return batch.commit();
  }

  /// Removes an item; also how a suggestion is rejected or withdrawn.
  Future<void> deleteItem(String groupId, String itemId) =>
      _items(groupId).doc(itemId).delete();

  /// Admin only: updates the location, preserving concurrent title/date edits.
  Future<void> setItemLocation(
      String groupId, String itemId, TripLocation location) async {
    if (!location.isValid) throw ArgumentError('Invalid trip location');
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Only trip admins can change locations.');
    await _firestore.runTransaction((transaction) async {
      final group = Group.fromDoc(await transaction.get(_group(groupId)));
      if (group.memberById(uid)?.role != GroupRole.admin) {
        throw StateError('Only trip admins can change locations.');
      }
      transaction.update(_items(groupId).doc(itemId), {
        'location': location.toMap(),
      });
    });
  }
}
