# HADI SMS

HADI SMS is a Flutter + Supabase school management system for school administration, teachers, parents, students, attendance, academics, finance, exams, reports, communication, library and related workflows.

## Tech stack

- Flutter 3.41.9
- Dart 3
- Supabase Auth, PostgreSQL, RLS and Edge Functions
- Riverpod
- GoRouter
- GitHub Actions CI

## Local setup

1. Install Flutter 3.41.9 (stable) or a compatible stable release.
2. Run `flutter pub get`.
3. Verify the Supabase project configuration in `lib/core/network/supabase_client.dart`.
4. Run `flutter run`.

The password-reset mobile deep link is:

`hadi-sms://reset-password`

## Supabase

Database migrations are stored under `supabase/migrations/`.

Edge Function sources are stored under `supabase/functions/`, including:

- `create-staff`
- `create-staff-account`
- `create-role-account`
- `manage-role-account`

Keep the deployed database migrations and Edge Functions synchronized with the repository before releasing.

## Quality checks

Run locally before opening or merging a pull request:

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug
```

The GitHub Actions workflow performs the same checks and uploads a debug APK artifact when successful.

## Android release signing

Production releases must never use Flutter's debug signing key.

1. Create your private upload keystore outside Git.
2. Copy `android/key.properties.example` to `android/key.properties`.
3. Fill in the real keystore path, alias and passwords.
4. Keep both `android/key.properties` and the keystore private; they are ignored by Git.
5. Build the production bundle with `flutter build appbundle --release` only after signing is configured.

### Android application ID

The project currently uses `com.managment.hadi_sms`. Decide whether this is the permanent Play Store application ID **before the first production publication**. Changing the application ID after release creates a different Android app.

## Current backend scope

Core school-management data is Supabase-backed and protected by RLS. Some optional dashboard modules may require dedicated database models before they can become real operational modules; do not replace missing backend data with fabricated production records.

## Security

- Never commit service-role keys, passwords, keystores or `key.properties`.
- Client-side Supabase code must use only a publishable/anonymous client key.
- Privileged user-management operations belong in authenticated Edge Functions.
- Keep RLS enabled and school-scoped for tenant-owned data.
