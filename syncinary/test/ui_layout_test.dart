@TestOn('vm')
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:syncinary/models/group.dart';
import 'package:syncinary/pages/flight_search.dart';
import 'package:syncinary/pages/groups/group_detail_page.dart';
import 'package:syncinary/pages/groups/join_group_page.dart';
import 'package:syncinary/pages/groups/my_groups_page.dart';
import 'package:syncinary/pages/hotel_search.dart';
import 'package:syncinary/pages/itinerary_builder.dart';
import 'package:syncinary/pages/login_page.dart';
import 'package:syncinary/pages/signup_page.dart';
import 'package:syncinary/pages/verify_email_page.dart';
import 'package:syncinary/pages/user_preferences_page.dart';
import 'package:syncinary/pages/groups/group_preferences_page.dart';
import 'package:syncinary/services/user_preferences_service.dart';
import 'package:syncinary/services/group_preferences_service.dart';
import 'package:syncinary/services/account_service.dart';
import 'package:syncinary/widgets/settings_panel.dart';
import 'package:syncinary/pages/onboarding_page.dart';
import 'package:syncinary/pages/schedule_builder_page.dart';
import 'package:syncinary/pages/trip_expenses_page.dart';
import 'package:syncinary/services/expense_service.dart';
import 'package:syncinary/services/group_service.dart';
import 'package:syncinary/services/recommendation_service.dart';
import 'package:syncinary/services/schedule_service.dart';
import 'package:syncinary/theme/app_theme.dart';
import 'package:syncinary/widgets/page_body.dart';

// Optional local visual QA: set UI_AUDIT_FONT_PATH to a Roboto TTF and run
// this file. Screenshots go to the ignored build/ui-audit directory.
final _fontPath = Platform.environment['UI_AUDIT_FONT_PATH'];
final _boundaryKey = GlobalKey();

Future<void> _capture(WidgetTester tester, String name) async {
  if (_fontPath == null) return;
  await tester.runAsync(() async {
    final boundary =
        _boundaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/ui-audit')..createSync(recursive: true);
    File(
      '${directory.path}/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    PackageInfo.setMockInitialValues(
      appName: 'Syncinary',
      packageName: 'syncinary',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    if (_fontPath == null) return;
    final loader = FontLoader('Roboto')
      ..addFont(
        Future.value(ByteData.sublistView(File(_fontPath!).readAsBytesSync())),
      );
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '${File(_fontPath!).parent.path}/materialicons-regular.otf',
            ).readAsBytesSync(),
          ),
        ),
      );
    await icons.load();
  });

  test('[N301-4] text and primary actions maintain readable contrast', () {
    double contrast(Color a, Color b) {
      final light = a.computeLuminance();
      final dark = b.computeLuminance();
      return light > dark
          ? (light + .05) / (dark + .05)
          : (dark + .05) / (light + .05);
    }

    for (final surface in [
      AppColors.background,
      AppColors.surface,
      AppColors.surfaceLight,
    ]) {
      for (final text in [
        AppColors.textPrimary,
        AppColors.textSecondary,
        AppColors.textMuted,
        AppColors.accentEnd,
        AppColors.error,
      ]) {
        expect(contrast(text, surface), greaterThanOrEqualTo(4.5));
      }
    }
    for (final color in AppColors.brandGradient.colors) {
      expect(contrast(Colors.white, color), greaterThanOrEqualTo(4.5));
    }
    expect(
      contrast(AppColors.background, AppColors.accentStart),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets(
    '[N301-4] primary actions support keyboard activation and disable while loading',
    (tester) async {
      var activations = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: GradientButton(
                onPressed: () => activations++,
                label: 'Continue',
              ),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(activations, 1);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: GradientButton(
                onPressed: () => activations++,
                label: 'Continue',
                isLoading: true,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(GradientButton));
      expect(activations, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final viewport in [
    (name: 'phone', size: const Size(390, 844), scale: 1.0),
    (name: 'compact', size: const Size(320, 568), scale: 1.0),
    (name: 'tablet', size: const Size(900, 900), scale: 1.0),
    (name: 'desktop', size: const Size(1600, 1000), scale: 1.0),
    (name: 'large-text', size: const Size(390, 844), scale: 2.0),
  ]) {
    testWidgets(
      '[N301-3] main screens fit ${viewport.name} with reachable actions',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = viewport.size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final firestore = FakeFirebaseFirestore();
        final auth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(
            uid: 'me',
            email: 'me@example.com',
            isEmailVerified: true,
          ),
        );
        final groups = GroupService(firestore: firestore, auth: auth);
        final group = Group(
          id: 'trip',
          name: 'A long weekend in the Pacific Northwest',
          inviteCode: 'TRAVEL',
          members: [
            GroupMember(
              id: 'me',
              username: 'Jordan',
              email: 'me@example.com',
              role: GroupRole.admin,
            ),
            GroupMember(
              id: 'friend',
              username: 'Alexandra Chen',
              email: 'friend@example.com',
              role: GroupRole.user,
            ),
          ],
        );
        await firestore.collection('groups').doc(group.id).set({
          'name': group.name,
          'inviteCode': group.inviteCode,
          'memberIds': group.members.map((m) => m.id).toList(),
          'members': {for (final m in group.members) m.id: m.toMap()},
        });
        final advisor = RecommendationService(
          client: MockClient(
            (_) async => http.Response(
              '{"ok":false,"error":"empty_payload","message":"No plans yet"}',
              422,
            ),
          ),
          idTokenProvider: () async => null,
        );

        Future<void> show(Widget page, String name, {String? action}) async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            RepaintBoundary(
              key: _boundaryKey,
              child: MaterialApp(
                theme: buildAppTheme(),
                debugShowCheckedModeBanner: false,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(viewport.scale)),
                  child: child!,
                ),
                home: page,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$name at ${viewport.name}',
          );
          final body = find.byType(PageBody);
          if (body.evaluate().isNotEmpty && viewport.size.width > 1440) {
            final box = find
                .descendant(of: body, matching: find.byType(ConstrainedBox))
                .first;
            expect(tester.getSize(box).width, lessThanOrEqualTo(1440));
          }
          await _capture(tester, '${viewport.name}-$name');
          if (action != null) {
            await tester.ensureVisible(find.text(action));
            await tester.pumpAndSettle();
            expect(find.text(action).hitTestable(), findsOneWidget);
          }
        }

        await show(LoginPage(auth: auth, groupService: groups), 'login');
        await show(SignUpPage(auth: auth, firestore: firestore), 'signup');
        await show(VerifyEmailPage(auth: auth), 'verify');
        await show(const OnboardingPage(), 'onboarding');
        await show(
          MyGroupsPage(service: groups),
          'groups',
          action: 'Add Group',
        );
        await tester.tap(find.text('Add Group'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final dialogWidth = tester
            .getSize(
              find
                  .descendant(
                    of: find.byType(Dialog),
                    matching: find.byType(SingleChildScrollView),
                  )
                  .first,
            )
            .width;
        expect(dialogWidth, lessThanOrEqualTo(480));
        await _capture(tester, '${viewport.name}-new-group');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await show(JoinGroupPage(service: groups), 'join');
        await show(
          UserPreferencesPage(
            service: UserPreferencesService(firestore: firestore, auth: auth),
          ),
          'preferences',
        );
        await show(
          GroupPreferencesPage(
            groupId: group.id,
            groupName: group.name,
            service: GroupPreferencesService(firestore: firestore, auth: auth),
          ),
          'group-preferences',
        );
        await show(
          Scaffold(
            body: Align(
              alignment: Alignment.centerRight,
              child: SettingsPanel(
                service: AccountService(firestore: firestore, auth: auth),
              ),
            ),
          ),
          'settings',
        );
        await show(
          GroupDetailPage(group: group, service: groups),
          'trip',
          action: 'Invite Members',
        );
        await tester.tap(find.text('Invite Members'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _capture(tester, '${viewport.name}-invite');
        await tester.ensureVisible(find.text('Cancel'));
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await show(const itinerary_builder(), 'search', action: 'Continue');
        await tester.ensureVisible(find.text('Travelers'));
        await tester.tap(find.text('Travelers'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _capture(tester, '${viewport.name}-travelers');
        await show(
          HotelSearch(
            initialResults: [
              {
                'name': 'The Waterfront Hotel and Gardens',
                'overall_rating': 4.8,
                'reviews': 1284,
                'hotel_class': 4,
                'rate_per_night': {'lowest': '\$249'},
              },
            ],
          ),
          'hotels',
        );
        await show(
          flight_search(
            title: 'Flight Results',
            origin: 'ORD',
            destination: 'SEA',
            departureDate: '2026-12-01',
            initialResults: [
              {
                'flights': [
                  {
                    'airline': 'Pacific Northwest Airlines',
                    'departure_airport': {
                      'id': 'ORD',
                      'time': '2026-12-01 08:00',
                    },
                    'arrival_airport': {
                      'id': 'SEA',
                      'time': '2026-12-01 10:15',
                    },
                  },
                ],
                'price': 325,
                'total_duration': 255,
              },
            ],
          ),
          'flights',
          action: 'Select Flight',
        );
        await show(
          ScheduleBuilderPage(
            group: group,
            service: ScheduleService(firestore: firestore, auth: auth),
            recommendationService: advisor,
          ),
          'schedule',
        );
        await show(
          TripExpensesPage(
            group: group,
            service: ExpenseService(firestore: firestore, auth: auth),
          ),
          'expenses',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
