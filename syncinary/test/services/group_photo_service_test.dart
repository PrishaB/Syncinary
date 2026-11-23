import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syncinary/models/group.dart';
import 'package:syncinary/services/group_photo_service.dart';
import 'package:syncinary/widgets/group_avatar.dart';

/// Smallest byte strings that pass each format's signature check.
final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
final pngBytes =
    Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2]);
final gifBytes = Uint8List.fromList([...'GIF89a'.codeUnits, 1, 2]);
final webpBytes =
    Uint8List.fromList([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits, 1]);

Future<Group> seedGroup(FakeFirebaseFirestore firestore,
    [Map<String, dynamic> extra = const {}]) async {
  final ref = firestore.collection('groups').doc('trip');
  await ref.set({
    'name': 'Trip',
    'memberIds': ['admin-uid'],
    'members': {
      'admin-uid': {'username': 'Admin', 'email': 'a@syncinary.app', 'role': 'admin'},
    },
    ...extra,
  });
  return Group.fromDoc(await ref.get());
}

Future<Group> reload(FakeFirebaseFirestore firestore) async =>
    Group.fromDoc(await firestore.collection('groups').doc('trip').get());

Future<bool> objectExists(FirebaseStorage storage, String path) async {
  try {
    await storage.ref(path).getDownloadURL();
    return true;
  } on FirebaseException {
    return false;
  }
}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseStorage storage;
  late int tick;
  late GroupPhotoService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    storage = MockFirebaseStorage();
    tick = 1000;
    service = GroupPhotoService(
      firestore: firestore,
      storage: storage,
      clock: () => DateTime.fromMicrosecondsSinceEpoch(tick++),
    );
  });

  group('[401-1] upload valid file to storage', () {
    test('[401-1] stores the image with its content type and saves the URL on the group',
        () async {
      final group = await seedGroup(firestore);

      final url = await service.uploadGroupPhoto(group, pngBytes);

      final saved = await reload(firestore);
      expect(saved.photoUrl, url);
      expect(saved.photoPath, 'groups/trip/photo_1000');
      expect(await objectExists(storage, saved.photoPath!), isTrue);
      final metadata = await storage.ref(saved.photoPath!).getMetadata();
      expect(metadata.contentType, 'image/png');
    });

    test('[401-1] accepts JPEG, PNG, GIF and WebP', () {
      expect(validateGroupPhoto(jpegBytes), 'image/jpeg');
      expect(validateGroupPhoto(pngBytes), 'image/png');
      expect(validateGroupPhoto(gifBytes), 'image/gif');
      expect(validateGroupPhoto(webpBytes), 'image/webp');
    });

    test('[401-1] accepts an image of exactly 5 MB', () {
      final bytes = Uint8List(maxGroupPhotoBytes)..setAll(0, jpegBytes);
      expect(validateGroupPhoto(bytes), 'image/jpeg');
    });

    test('[401-1] replacing a photo gives a new URL and deletes the old object',
        () async {
      final group = await seedGroup(firestore);
      final firstUrl = await service.uploadGroupPhoto(group, pngBytes);
      final first = await reload(firestore);

      final secondUrl = await service.uploadGroupPhoto(first, jpegBytes);

      final second = await reload(firestore);
      expect(secondUrl, isNot(firstUrl));
      expect(second.photoUrl, secondUrl);
      expect(await objectExists(storage, second.photoPath!), isTrue);
      expect(await objectExists(storage, first.photoPath!), isFalse);
    });

    test('[401-1] a failed group update removes the new object and keeps the old photo',
        () async {
      // The group doc doesn't exist, so update() fails.
      final group = Group(id: 'gone', name: 'Gone', members: []);

      await expectLater(service.uploadGroupPhoto(group, pngBytes), throwsA(anything));

      expect(await objectExists(storage, 'groups/gone/photo_1000'), isFalse);
    });
  });

  group('[401-2] retrieve and display uploaded file', () {
    test('[401-2] Group.fromDoc reads photoUrl and photoPath, and ignores bad types',
        () async {
      final withPhoto = await seedGroup(
          firestore, {'photoUrl': 'https://example.com/p.png', 'photoPath': 'groups/trip/p'});
      expect(withPhoto.photoUrl, 'https://example.com/p.png');
      expect(withPhoto.photoPath, 'groups/trip/p');

      final badTypes = await seedGroup(firestore, {'photoUrl': 42, 'photoPath': true});
      expect(badTypes.photoUrl, isNull);
      expect(badTypes.photoPath, isNull);
    });

    testWidgets('[401-2] GroupAvatar shows the uploaded photo from its download URL',
        (tester) async {
      final group = await seedGroup(firestore);
      final url = await tester.runAsync(() => service.uploadGroupPhoto(group, pngBytes));
      final saved = (await tester.runAsync(() => reload(firestore)))!;

      await tester.pumpWidget(MaterialApp(
        home: GroupAvatar(photoUrl: saved.photoUrl, size: 84),
      ));

      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as NetworkImage).url, url);
    });

    testWidgets('[401-2] GroupAvatar falls back to the group icon without a photo',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: GroupAvatar(photoUrl: null, size: 44)));
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.group_rounded), findsOneWidget);
    });
  });

  group('[401-3] reject invalid file upload', () {
    Future<void> expectRejected(Uint8List bytes, String messagePart) async {
      final group = await seedGroup(firestore);
      await expectLater(
        service.uploadGroupPhoto(group, bytes),
        throwsA(isA<InvalidImageException>()
            .having((e) => e.message, 'message', contains(messagePart))),
      );
      // Nothing was uploaded and the group is unchanged.
      expect(await objectExists(storage, 'groups/trip/photo_1000'), isFalse);
      expect((await reload(firestore)).photoUrl, isNull);
    }

    test('[401-3] rejects a text file', () =>
        expectRejected(Uint8List.fromList('hello, not an image'.codeUnits), 'supported image'));

    test('[401-3] rejects a PDF even if named like an image', () =>
        expectRejected(Uint8List.fromList('%PDF-1.7 ...'.codeUnits), 'supported image'));

    test('[401-3] rejects an empty file', () => expectRejected(Uint8List(0), 'empty'));

    test('[401-3] rejects an image over 5 MB', () {
      final bytes = Uint8List(maxGroupPhotoBytes + 1)..setAll(0, jpegBytes);
      return expectRejected(bytes, '5 MB');
    });

    test('[401-3] rejects a truncated signature', () =>
        expectRejected(Uint8List.fromList([0x89, 0x50, 0x4E]), 'supported image'));
  });
}
