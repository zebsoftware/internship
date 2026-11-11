# PharmaCare

Flutter pharmacy management application using Firebase Authentication and Cloud Firestore.

## Current source features
- Account registration and login
- Inventory with medicine quantity, batch, price and expiry fields
- Orders with multiple items and statuses
- Dashboard, analytics, and profile screens

**Status:** Under development. Not verified for real pharmacy operations.

## Run locally

```bash
cd pharmacare
flutter pub get
flutter analyze
flutter test
flutter run
```

Dependency resolution and app tests have not yet been verified. The Dart SDK constraint in `pubspec.yaml` needs review against the Firebase dependency versions.

## Firebase configuration

Create/configure your Firebase project, enable Authentication and Firestore, and supply appropriate platform configuration. Firestore collections include `users`, `medicines`, and `orders`.

**Security:** Review Firestore rules before using real data. The app currently needs an authorization and data-isolation audit. Do not use unrestricted test-mode rules in production.

## Fixes in progress

Order creation now uses a Firestore transaction to check available inventory and write the order and stock updates together. This must be validated with concurrent checkout tests and the Firestore rules. Cancellation/restocking is not yet verified.

## Remaining priorities

1. Resolve Flutter/Dart/Firebase version compatibility.
2. Review account creation, login, ownership and permissions.
3. Test order creation, cancellation, and inventory accounting.
4. Replace the default Flutter counter widget test with real model and UI tests.
5. Validate analytics and error/empty states.
6. Add genuine application screenshots for the Upwork portfolio.

This repository also contains other projects. PharmaCare lives in the `pharmacare/` directory.
