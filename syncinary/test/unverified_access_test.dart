import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncinary/models/group.dart';
import 'package:syncinary/models/schedule.dart';
import 'package:syncinary/pages/groups/group_detail_page.dart';
import 'package:syncinary/pages/groups/join_group_page.dart';
import 'package:syncinary/pages/groups/my_groups_page.dart';
import 'package:syncinary/pages/itinerary_builder.dart';
import 'package:syncinary/pages/login_page.dart';
import 'package:syncinary/pages/schedule_builder_page.dart';
import 'package:syncinary/pages/verify_email_page.dart';
import 'package:syncinary/services/group_service.dart';
import 'package:syncinary/widgets/auth_gate.dart';

// This test double models server state changing when the user reloads.
// ignore: must_be_immutable
class _VerificationUser extends MockUser {
  _VerificationUser() : super(uid: 'traveler', email: 'traveler@example.com');

  bool verifiedOnServer = false;
  bool _verified = false;
  int reloads = 0;
  int sentEmails = 0;

  @override
  bool get emailVerified => _verified;

  @override
  Future<void> reload() async {
    reloads++;
    _verified = verifiedOnServer;
  }

  @override
  Future<void> sendEmailVerification([
    ActionCodeSettings? actionCodeSettings,
  ]) async {
    sentEmails++;
  }
}

class _TrackedGroups extends GroupService {
  _TrackedGroups({required super.auth, required super.firestore});

  int groupReads = 0;
  int inviteReads = 0;

  @override
  Stream<List<Group>> myGroupsStream() {
    groupReads++;
    return super.myGroupsStream();
  }

  @override
  Stream<Group?> groupStream(String groupId) {
    groupReads++;
    return super.groupStream(groupId);
  }

  @override
  Stream<List<GroupInvite>> pendingInvitesStream() {
    inviteReads++;
    return super.pendingInvitesStream();
  }
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _login(WidgetTester tester) async {
  expect(find.byType(LoginPage), findsOneWidget);
  await tester.enterText(
    find.byType(TextFormField).at(0),
    'traveler@example.com',
  );
  await tester.enterText(find.byType(TextFormField).at(1), 'password123');
  await _tap(tester, 'Sign In');
}

void _expectBlocked(_TrackedGroups service) {
  expect(find.byType(VerifyEmailPage), findsOneWidget);
  expect(find.text('Verify your email'), findsOneWidget);
  for (final page in [
    MyGroupsPage,
    JoinGroupPage,
    GroupDetailPage,
    PlanItineraryPage,
    ScheduleBuilderPage,
    itinerary_builder,
  ]) {
    expect(find.byType(page, skipOffstage: false), findsNothing);
  }
  for (final label in [
    'My Groups',
    'Join Group',
    'Plan Itinerary',
    'Private trip',
    'Private hotel',
  ]) {
    expect(find.text(label, skipOffstage: false), findsNothing);
  }
  expect(service.groupReads, 0);
  expect(service.inviteReads, 0);
}

void main() {
  for (final restoredSession in [true, false]) {
    testWidgets(
      '${restoredSession ? 'restored session' : 'fresh login'} cannot reach groups or itinerary until verified',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1100, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final user = _VerificationUser();
        final auth = MockFirebaseAuth(
          mockUser: user,
          signedIn: restoredSession,
        );
        final database = FakeFirebaseFirestore();
        final service = _TrackedGroups(auth: auth, firestore: database);
        // Membership and an existing itinerary must not bypass verification.
        await database.collection('groups').doc('private-trip').set({
          'name': 'Private trip',
          'memberIds': ['traveler'],
          'members': {
            'traveler': {
              'username': 'Traveler',
              'email': 'traveler@example.com',
              'role': 'admin',
            },
          },
        });
        // Seed the per-user marker directly since a fresh session is signed out.
        await database
            .collection('groups')
            .doc('private-trip')
            .collection('itineraryStarted')
            .doc('traveler')
            .set({});
        await service.scheduleService.addDay(
          'private-trip',
          DateTime(2026, 5, 3),
        );
        await database
            .collection('groups')
            .doc('private-trip')
            .collection('scheduleItems')
            .doc('hotel')
            .set({
              'day': '2026-05-03',
              'type': scheduleItemTypeToString(ScheduleItemType.hotel),
              'title': 'Private hotel',
              'details': 'Private booking',
              'addedBy': 'traveler',
              'createdAt': DateTime(2026, 5, 3),
            });

        await tester.pumpWidget(
          MaterialApp(
            home: AuthGate(auth: auth, groupService: service),
          ),
        );
        await tester.pumpAndSettle();
        if (!restoredSession) await _login(tester);
        _expectBlocked(service);
        expect(auth.currentUser!.emailVerified, isFalse);

        await _tap(tester, 'Check verification');
        expect(user.reloads, 1);
        expect(
          find.text(
            'Your email is not verified yet. Open the link in your email and try again.',
          ),
          findsOneWidget,
        );
        _expectBlocked(service);

        await _tap(tester, 'Resend verification email');
        expect(user.sentEmails, 1);
        expect(
          find.text(
            'Verification email sent. Check your inbox and spam folder.',
          ),
          findsOneWidget,
        );
        _expectBlocked(service);
        // Exercise the platform Back action, rather than force-popping a route.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        _expectBlocked(service);

        await _tap(tester, 'Back to sign in');
        expect(auth.currentUser, isNull);
        expect(find.byType(LoginPage), findsOneWidget);
        await _login(tester);
        _expectBlocked(service);
        await _tap(tester, 'Check verification');
        expect(user.reloads, 2);
        _expectBlocked(service);

        // Positive control: only a successful reload of verified status unlocks
        // the real group and itinerary routes using the same account and data.
        user.verifiedOnServer = true;
        _expectBlocked(service);
        await _tap(tester, 'Check verification');
        expect(user.reloads, 3);
        expect(auth.currentUser!.emailVerified, isTrue);
        expect(find.byType(VerifyEmailPage, skipOffstage: false), findsNothing);
        expect(find.byType(MyGroupsPage), findsOneWidget);
        expect(service.groupReads, greaterThan(0));
        await _tap(tester, 'Private trip');
        await _tap(tester, 'Plan Itinerary');
        expect(find.byType(ScheduleBuilderPage), findsOneWidget);
        expect(find.text('Private hotel'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
