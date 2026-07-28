# psm

Flutter + Firebase starter app.

## What’s included

- A polished Firebase auth screen with sign in, sign up, and password reset.
- Firebase packages for authentication and Firestore.
- A smoke test that verifies the auth screen renders.

## Run it

```bash
flutter pub get
flutter run
```

## Finish Firebase setup

1. Create a Firebase project in the Firebase console.
2. Install the FlutterFire CLI if you have not already.
3. Run `flutterfire configure` from this folder.
4. Add the generated Firebase config files for Android and iOS.
5. Replace the placeholder buttons and messages with your app flows.

## Current app flow

- The app opens on a Firebase auth screen.
- When Firebase is configured, sign in and sign up call `FirebaseAuth` directly.
- When Firebase is not configured yet, the UI still opens in preview mode and shows a setup hint.

## Next features to build

- Sign up and login screens with Firebase Authentication.
- Firestore collections for users, posts, or tasks.
- File uploads with Firebase Storage.
- Push notifications with Firebase Cloud Messaging.

## Requirements and Stories

- Normalized user role requirements and user stories: [docs/user-roles-and-stories.md](docs/user-roles-and-stories.md)
