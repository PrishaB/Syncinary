import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syncinary/models/group.dart';
import 'package:syncinary/models/schedule.dart';
import 'package:syncinary/models/trip_location.dart';
import 'package:syncinary/pages/schedule_builder_page.dart';
import 'package:syncinary/pages/trip_map_page.dart';
import 'package:syncinary/services/place_service.dart';
import 'package:syncinary/services/schedule_service.dart';
import 'package:syncinary/theme/app_theme.dart';
import 'package:syncinary/widgets/trip_location_picker.dart';

class _OfflineTiles extends TileProvider {
  final _image = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _image;
}

class _FailedTile extends Fake implements TileImage {}

class _StreamService extends ScheduleService {
  _StreamService(this.controller)
    : super(firestore: FakeFirebaseFirestore(), auth: MockFirebaseAuth());
  final StreamController<List<ScheduleItem>> controller;
  @override
  Stream<List<ScheduleItem>> itemsStream(String groupId) => controller.stream;
}

void main() {
  late FakeFirebaseFirestore db;
  late ScheduleService service;
  final group = Group(id: 'trip', name: 'New York weekend', members: []);
  const hotel = TripLocation(
    name: 'Hotel',
    address: 'Times Square',
    latitude: 40.758,
    longitude: -73.985,
  );
  const museum = TripLocation(
    name: 'Museum',
    address: 'Fifth Avenue',
    latitude: 40.779,
    longitude: -73.963,
  );

  setUp(() {
    db = FakeFirebaseFirestore();
    service = ScheduleService(
      firestore: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'me')),
    );
  });

  Future<void> add(
    String id,
    String day,
    ScheduleItemType type,
    TripLocation? location,
  ) => db
      .collection('groups')
      .doc('trip')
      .collection('scheduleItems')
      .doc(id)
      .set({
        'title': id,
        'type': type.name,
        'day': day,
        'details': 'Details for $id',
        'createdAt': Timestamp.fromDate(
          DateTime(2026, 10, 25).add(Duration(minutes: id.length)),
        ),
        if (location != null) 'location': location.toMap(),
      });

  Widget app(Widget child) => MaterialApp(theme: buildAppTheme(), home: child);
  Widget map({PlaceService? places}) => app(
    TripMapPage(
      group: group,
      service: service,
      tileProvider: _OfflineTiles(),
      placeService: places,
    ),
  );

  testWidgets(
    '[202-1] planner opens map and returns without losing the schedule',
    (tester) async {
      await tester.pumpWidget(
        app(ScheduleBuilderPage(group: group, service: service)),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Map View'));
      await tester.tap(find.text('Map View'));
      await tester.pumpAndSettle();
      expect(find.text('Trip Map'), findsOneWidget);
      expect(find.text('No locations to show yet'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Schedule Builder'), findsOneWidget);
    },
  );

  testWidgets('[202-1] map pans, zooms and fits all stops', (tester) async {
    await add('Hotel stay', '2026-10-25', ScheduleItemType.hotel, hotel);
    await add('Museum visit', '2026-10-26', ScheduleItemType.activity, museum);
    await tester.pumpWidget(map());
    await tester.pumpAndSettle();
    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    final zoom = controller.camera.zoom;
    final center = controller.camera.center;
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
    expect(controller.camera.zoom, greaterThan(zoom));
    await tester.tap(find.byTooltip('Zoom out'));
    await tester.pumpAndSettle();
    expect(controller.camera.zoom, closeTo(zoom, .001));
    await tester.drag(find.byType(FlutterMap), const Offset(80, 40));
    await tester.pumpAndSettle();
    expect(controller.camera.center, isNot(center));
    await tester.tap(find.byTooltip('Fit all stops'));
    await tester.pumpAndSettle();
    expect(
      controller.camera.visibleBounds.contains(const LatLng(40.758, -73.985)),
      isTrue,
    );
    expect(
      controller.camera.visibleBounds.contains(const LatLng(40.779, -73.963)),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '[202-4] markers and route update after add, move and removal; day filter works',
    (tester) async {
      await add('Hotel stay', '2026-10-26', ScheduleItemType.hotel, hotel);
      await tester.pumpWidget(map());
      await tester.pumpAndSettle();
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
        hasLength(1),
      );
      expect(
        tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines,
        isEmpty,
      );
      await add(
        'Museum visit',
        '2026-10-25',
        ScheduleItemType.activity,
        museum,
      );
      await tester.pumpAndSettle();
      final route = tester
          .widget<PolylineLayer>(find.byType(PolylineLayer))
          .polylines
          .single
          .points;
      expect(route, [
        const LatLng(40.779, -73.963),
        const LatLng(40.758, -73.985),
      ]);
      await service.updateItem(
        'trip',
        'Hotel stay',
        date: DateTime(2026, 10, 24),
        title: 'Hotel stay',
        details: 'Updated',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PolylineLayer>(find.byType(PolylineLayer))
            .polylines
            .single
            .points
            .first,
        const LatLng(40.758, -73.985),
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026-10-25').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
        hasLength(1),
      );
      expect(find.byKey(const ValueKey('marker-Museum visit')), findsOneWidget);
      await service.deleteItem('trip', 'Museum visit');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('marker-Hotel stay')), findsOneWidget);
      await service.deleteItem('trip', 'Hotel stay');
      await tester.pumpAndSettle();
      expect(find.text('No locations to show yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '[202-4] duplicate locations retain every stop and show shared marker details',
    (tester) async {
      await add('Hotel stay', '2026-10-25', ScheduleItemType.hotel, hotel);
      await add('Hotel dinner', '2026-10-25', ScheduleItemType.activity, hotel);
      await tester.pumpWidget(map());
      await tester.pumpAndSettle();
      expect(find.text('2 of 2 stops on map'), findsOneWidget);
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
        hasLength(1),
      );
      await tester.tap(find.byKey(const ValueKey('marker-Hotel stay')));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('Hotel stay')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Hotel dinner')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '[202-3] missing locations can be resolved from the map on a phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await add('Hotel stay', '2026-10-25', ScheduleItemType.hotel, null);
      final places = PlaceService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'places': [hotel.toMap()],
            }),
            200,
          ),
        ),
      );
      addTearDown(places.dispose);
      await tester.pumpWidget(map(places: places));
      await tester.pumpAndSettle();
      expect(find.text('No locations to show yet'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byTooltip('Add location'),
        120,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.byTooltip('Add location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hotel'));
      await tester.pumpAndSettle();
      expect(
        (await service.itemsStream('trip').first).single.location!.address,
        'Times Square',
      );
      expect(find.byKey(const ValueKey('marker-Hotel stay')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '[202-3] schedule loading errors are visible and retry recovers',
    (tester) async {
      final stream = StreamController<List<ScheduleItem>>.broadcast();
      addTearDown(stream.close);
      await tester.pumpWidget(
        app(TripMapPage(group: group, service: _StreamService(stream))),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      stream.addError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Could not load the trip map.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      stream.add([]);
      await tester.pumpAndSettle();
      expect(find.text('No locations to show yet'), findsOneWidget);
    },
  );

  testWidgets(
    '[202-2] planner saves a selected place and allows removing it on edit',
    (tester) async {
      final places = PlaceService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'places': [hotel.toMap()],
            }),
            200,
          ),
        ),
      );
      addTearDown(places.dispose);
      await tester.pumpWidget(
        app(
          ScheduleBuilderPage(
            group: group,
            service: service,
            placeService: places,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Hotel'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Hotel name'),
        'My stay',
      );
      await tester.tap(find.text('Add map location (optional)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hotel'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        (await service.itemsStream('trip').first).single.location!.name,
        'Hotel',
      );
      await tester.ensureVisible(find.byTooltip('Edit'));
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Remove map location'));
      await tester.tap(find.byTooltip('Remove map location'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect((await service.itemsStream('trip').first).single.location, isNull);
    },
  );

  testWidgets('[202-3] stale place results never select a location', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    final places = PlaceService(client: MockClient((_) => pending.future));
    addTearDown(places.dispose);
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => pickTripLocation(context, service: places),
            child: const Text('Choose'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Paris');
    await tester.tap(find.text('Find location'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'London');
    pending.complete(
      http.Response(
        jsonEncode({
          'places': [hotel.toMap()],
        }),
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hotel'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('[202-3] tile failures keep stops visible and offer a retry', (
    tester,
  ) async {
    await add('Hotel stay', '2026-10-25', ScheduleItemType.hotel, hotel);
    await tester.pumpWidget(map());
    await tester.pumpAndSettle();
    final tile = tester.widget<TileLayer>(find.byType(TileLayer));
    // Exercise the provider-error UI without making a network request.
    tile.errorTileCallback!(
      _FailedTile(),
      StateError('offline'),
      StackTrace.current,
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Map tiles could not load. Your trip stops are still available.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('marker-Hotel stay')), findsOneWidget);
    expect(find.text('Hotel stay'), findsOneWidget);
    await tester.tap(find.text('Retry map'));
    await tester.pumpAndSettle();
    expect(find.text('Retry map'), findsNothing);
  });

  testWidgets('[202-3] failed place search can be retried or cancelled', (
    tester,
  ) async {
    var calls = 0;
    final places = PlaceService(
      client: MockClient(
        (_) async => ++calls == 1
            ? http.Response('{}', 502)
            : http.Response(
                jsonEncode({
                  'places': [hotel.toMap()],
                }),
                200,
              ),
      ),
    );
    addTearDown(places.dispose);
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => pickTripLocation(
              context,
              initialQuery: 'Hotel',
              service: places,
            ),
            child: const Text('Choose'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find location'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Place search is unavailable.'), findsOneWidget);
    await tester.tap(find.text('Find location'));
    await tester.pumpAndSettle();
    expect(find.text('Times Square'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Choose'), findsOneWidget);
  });
}