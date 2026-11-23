import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:syncinary/models/group.dart';
import 'package:syncinary/pages/groups/group_detail_page.dart';
import 'package:syncinary/services/group_photo_service.dart';
import 'package:syncinary/services/group_service.dart';
import 'package:syncinary/theme/app_theme.dart';

/// Returns [next] from the gallery picker and counts how often it was opened.
class FakeImagePicker extends ImagePicker {
  FakeImagePicker(this.next);
  final XFile? next;
  int calls = 0;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    calls++;
    return next;
  }
}

final pngBytes =
    Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2]);

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseStorage storage;
  late Group group;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    storage = MockFirebaseStorage();
    final ref = firestore.collection('groups').doc('bali');
    await ref.set({
      'name': 'Bali Trip',
      'inviteCode': 'BALI01',
      'memberIds': ['me-uid', 'alex-uid'],
      'members': {
        'me-uid': {'username': 'You', 'email': 'me@syncinary.app', 'role': 'admin'},
        'alex-uid': {'username': 'Alex', 'email': 'alex@syncinary.app', 'role': 'user'},
      },
    });
    group = Group.fromDoc(await ref.get());
  });

  Future<void> pumpAs(WidgetTester tester, String uid, FakeImagePicker picker) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = MockFirebaseAuth(
      mockUser: MockUser(uid: uid, email: '$uid@syncinary.app'),
      signedIn: true,
    );
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: GroupDetailPage(
        group: group,
        service: GroupService(firestore: firestore, auth: auth),
        photoService: GroupPhotoService(firestore: firestore, storage: storage),
        imagePicker: picker,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('[401-1] [401-2] admin picks a photo; it is uploaded and shown',
      (tester) async {
    final picker = FakeImagePicker(XFile.fromData(pngBytes, name: 'beach.png'));
    await pumpAs(tester, 'me-uid', picker);
    expect(find.text('Add photo'), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    await tester.tap(find.byIcon(Icons.group_rounded));
    // Not pumpAndSettle: it would run past the overlay's 1.3 s auto-dismiss.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Group photo updated'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    final saved = (await firestore.collection('groups').doc('bali').get()).data()!;
    final url = saved['photoUrl'] as String;
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, url);
    expect(find.text('Change photo'), findsOneWidget);
  });

  testWidgets('[401-3] picking a non-image shows an error and uploads nothing',
      (tester) async {
    final notAnImage = XFile.fromData(
        Uint8List.fromList('just some text'.codeUnits), name: 'notes.png');
    await pumpAs(tester, 'me-uid', FakeImagePicker(notAnImage));

    await tester.tap(find.byIcon(Icons.group_rounded));
    await tester.pumpAndSettle();

    expect(
      find.text("That file isn't a supported image. Choose a JPEG, PNG, GIF or WebP."),
      findsOneWidget,
    );
    final saved = (await firestore.collection('groups').doc('bali').get()).data()!;
    expect(saved.containsKey('photoUrl'), isFalse);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('[401-3] a regular member cannot change the photo', (tester) async {
    final picker = FakeImagePicker(XFile.fromData(pngBytes, name: 'beach.png'));
    await pumpAs(tester, 'alex-uid', picker);
    expect(find.text('Add photo'), findsNothing);

    await tester.tap(find.byIcon(Icons.group_rounded));
    await tester.pumpAndSettle();
    expect(picker.calls, 0);
  });
}
