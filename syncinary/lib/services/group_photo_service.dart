import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/group.dart';

/// Thrown by [GroupPhotoService.uploadGroupPhoto] when the chosen file is
/// not an image it accepts. [message] is written for the user.
class InvalidImageException implements Exception {
  const InvalidImageException(this.message);
  final String message;

  @override
  String toString() => 'InvalidImageException: $message';
}

/// Largest group photo accepted, in bytes. `storage.rules` enforces the same
/// limit server-side.
const int maxGroupPhotoBytes = 5 * 1024 * 1024;

/// Returns the MIME type of [bytes] if they start with the signature of a
/// supported image format (JPEG, PNG, GIF, WebP), otherwise null.
///
/// Checks the file's content rather than its name or reported type, so a
/// renamed text file or PDF is still rejected.
String? detectImageContentType(Uint8List bytes) {
  bool startsWith(List<int> sig, [int offset = 0]) {
    if (bytes.length < offset + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (bytes[offset + i] != sig[i]) return false;
    }
    return true;
  }

  if (startsWith(const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'image/png';
  }
  if (startsWith('GIF87a'.codeUnits) || startsWith('GIF89a'.codeUnits)) {
    return 'image/gif';
  }
  if (startsWith('RIFF'.codeUnits) && startsWith('WEBP'.codeUnits, 8)) {
    return 'image/webp';
  }
  return null;
}

/// Checks [bytes] against the group photo rules and returns its MIME type.
/// Throws [InvalidImageException] if the file is empty, too large, or not a
/// supported image format.
String validateGroupPhoto(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw const InvalidImageException('That file is empty. Choose an image.');
  }
  if (bytes.length > maxGroupPhotoBytes) {
    throw const InvalidImageException(
        'That image is larger than 5 MB. Choose a smaller one.');
  }
  final contentType = detectImageContentType(bytes);
  if (contentType == null) {
    throw const InvalidImageException(
        "That file isn't a supported image. Choose a JPEG, PNG, GIF or WebP.");
  }
  return contentType;
}

/// Uploads and replaces a group's photo.
///
/// The image goes to Firebase Storage at `groups/{groupId}/photo_<timestamp>`,
/// and its download URL and storage path are saved on the group document as
/// `photoUrl` and `photoPath`. Each upload gets a new object name so its URL
/// changes too, otherwise clients would keep showing the old photo from their
/// image cache. The previous object is deleted after the switch.
///
/// Accepts [FirebaseFirestore] / [FirebaseStorage] via the constructor so
/// tests can pass `FakeFirebaseFirestore` / `MockFirebaseStorage`.
class GroupPhotoService {
  GroupPhotoService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    DateTime Function()? clock,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _clock = clock ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final DateTime Function() _clock;

  /// Validates [bytes], uploads them as [group]'s photo and returns the new
  /// download URL. Throws [InvalidImageException] without uploading anything
  /// if the file is rejected.
  Future<String> uploadGroupPhoto(Group group, Uint8List bytes) async {
    final contentType = validateGroupPhoto(bytes);
    final path = 'groups/${group.id}/photo_${_clock().microsecondsSinceEpoch}';
    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();
    try {
      await _firestore
          .collection('groups')
          .doc(group.id)
          .update({'photoUrl': url, 'photoPath': path});
    } catch (_) {
      // The group doc still points at the old photo, so drop the new one.
      await _deleteQuietly(path);
      rethrow;
    }
    final previous = group.photoPath;
    if (previous != null && previous != path) await _deleteQuietly(previous);
    return url;
  }

  /// Best effort: a leftover object costs a little storage but must not fail
  /// an upload that otherwise succeeded.
  Future<void> _deleteQuietly(String path) async {
    try {
      await _storage.ref(path).delete();
    } catch (_) {}
  }
}
