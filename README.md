# psm
pg.141
Flutter + Firebase starter app.
asd@gmail.com
asd123

admin@psm.com admin123
## What’s included

- A polished Firebase auth screen with sign in, sign up, and password reset.
- Firebase packages for authentication and Firestore.
- A smoke test that verifies the auth screen renders.

## Run it

```bash
flutter pub get
flutter run --dart-define="GEMINI_API_KEY="

```

The student dashboard's **Ask AI** feature uses Gemini. Pass the key at run
time with `--dart-define`; do not commit the key to the repository. For a
production app, proxy Gemini through a trusted backend because mobile app
keys can be extracted.

In VS Code, choose **Run and Debug**, select **psm with Gemini**, press Start,
and enter the key when prompted. Fully stop and restart the app after changing
the key; hot reload cannot change compile-time defines.

## Finish Firebase setup

1. Create a Firebase project in the Firebase console.
2. Install the FlutterFire CLI if you have not already.
3. Run `flutterfire configure` from this folder.
4. Add the generated Firebase config files for Android and iOS.
5. Replace the placeholder buttons and messages with your app flows.

## User database (Firestore)

The app stores each profile at `users/{uid}`, where `uid` is the Firebase
Authentication UID.

It also mirrors each profile into one role collection using the same document
ID: `students/{uid}`, `parents/{uid}`, `teachers/{uid}`, or `admins/{uid}`.
The `users` document remains the canonical profile and role changes keep the
role collection in sync.

```text
uid, email, displayName, role, status, createdAt, updatedAt, lastLoginAt
```

In the Firebase console, create Firestore once at **Build → Firestore Database
→ Create database** (choose the project region and production mode). Also
enable **Email/Password** in **Build → Authentication → Sign-in method**.

Then deploy the included access rules:

```bash
firebase use psm2-8c2fc
firebase deploy --only firestore:rules
```

Signing up in the app will create the Firebase Auth account and its matching
Firestore profile automatically.

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
