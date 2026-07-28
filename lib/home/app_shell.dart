import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/auth_screen.dart';
import 'role_home_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    if (!firebaseReady) {
      return const AuthScreen(firebaseReady: false);
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const AuthScreen(firebaseReady: true);
        }

        return RoleHomeScreen(user: user, firebaseReady: true);
      },
    );
  }
}
