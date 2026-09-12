# Build & Release Checklist

## Local
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run

## Android
- Confirm applicationId/namespace.
- Configure signing for release.
- Set launcher icon from assets/logo/logo.png.
- Verify Supabase redirect/deep-link settings.
- Build an AAB for Play Console.

## iOS
- Configure bundle identifier.
- Configure signing/team.
- Configure URL schemes for password reset/deep links.
- Build/archive for App Store Connect.

## Web
- Configure allowed Supabase redirect URLs.
- Review public exposure and RLS.
- Build with `flutter build web`.

## Security
- Never ship a service-role key.
- Keep RLS enabled.
- Test every role against another school's records.
- Audit parent/student linking.
- Verify guest mode cannot call production write repositories.
