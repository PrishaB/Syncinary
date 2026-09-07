# AGENTS.md — Flutter app

The Syncinary client. Flutter / Dart, Firebase Auth + Cloud Firestore. Run
commands from this directory (`syncinary/`).

## Setup

```bash
flutter pub get
```

`lib/firebase_options.dart` is **gitignored** (it holds Firebase API keys) and
is absent from a fresh clone. Until it exists, `flutter analyze` and
`flutter run` fail with `Target of URI doesn't exist: 'firebase_options.dart'`.
Regenerate it with the FlutterFire CLI against project `syncinary-48881`:

```bash
flutterfire configure --project=syncinary-48881
```

`flutter test` does **not** need this file — the test suite doesn't import
`main.dart`.

## Build / run

- `flutter run` — needs `firebase_options.dart` (see Setup)
- `flutter build <apk|web|windows|…>`

The platform folders (`android/ ios/ web/ windows/ macos/ linux/`) and `build/`
are generated. Don't hand-edit them without a specific reason.

## Test

```bash
flutter test
```

Baseline on `main`: **9 passing, 0 failing.** Tests live in `test/`, one file
per feature (`login_page_test.dart`, `groups_flow_test.dart`). Firestore/Auth
code is tested with `fake_cloud_firestore` + `firebase_auth_mocks` — no
emulator, no network. Add tests next to their peers and keep them offline.

## Analyze / lint

```bash
flutter analyze
```

Config: `analysis_options.yaml` pulls in `package:flutter_lints/flutter.yaml`
with no custom rules; platform dirs and `build/` are excluded. Pre-existing
baseline — do **not** fix these as a drive-by:

- 2 errors from the missing `lib/firebase_options.dart` (see Setup)
- info-level `camel_case_types` on `flight_search`, `itinerary_builder`,
  `_itineraryState`, and one `unnecessary_underscores` in `theme/app_theme.dart`

**New code must not add issues.** CI does not run analyze, so run it yourself
before pushing.

## Layout

```
lib/
  main.dart              # entry; Firebase.initializeApp + AuthGate (routes on auth state)
  models/                # data classes + Firestore (de)serialization  — group.dart
  pages/                 # one screen per file
    groups/              # the Group feature's screens and dialogs
  services/              # Firestore/Auth data access — group_service.dart
  widgets/               # shared widgets (dialogs, app bar, overlays)
  theme/app_theme.dart   # design system: AppColors, AppTextStyles, buildAppTheme()
```

New screens go in `lib/pages/` (feature subfolder if it has several); new data
access goes in `lib/services/`; each source file's test mirrors its path under
`test/`.

## Conventions

- **Style:** follow `flutter_lints` — `UpperCamelCase` types, `const`
  constructors, `super.key`. Some existing widget classes are `snake_case`
  (`itinerary_builder`); that's legacy. Match the lint, not the neighbour.
- **Data access goes through a class, not a widget.** UI does not call
  Firestore or `http` directly — it uses a class in `lib/services/` (Firestore)
  or a service like `AmadeusService` (proxy). See `GroupService`.
- **Constructor-inject `FirebaseFirestore` / `FirebaseAuth`** as nullable
  params that default to `.instance`, so tests can pass fakes. `GroupService`,
  `LoginPage`, and `SignUpPage` all follow this.
- **Firestore collections:** `users/{uid}` (`{ email, username, createdAt }`),
  `groups/{groupId}`, `invites`, `inviteCodes` (maps `inviteCode -> groupId`).
- Flight calls target the proxy at `http://localhost:3000`, hardcoded in
  `AmadeusService`.
