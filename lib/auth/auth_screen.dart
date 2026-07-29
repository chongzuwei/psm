import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin_accounts.dart';
import '../profile/profile_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSignIn = true;
  bool _isLoading = false;
  String _selectedRole = 'student';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!widget.firebaseReady) {
      _showMessage(
        'Firebase is not connected yet. Run flutterfire configure and add the platform config files.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isSignIn) {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        await _upsertUserProfile(credential.user, isNewUser: false);
        _showMessage('Signed in successfully.');
      } else {
        final normalizedEmail = _emailController.text.trim().toLowerCase();
        final isBuiltInAdmin = isBuiltInAdminEmail(normalizedEmail);
        if (isBuiltInAdmin) {
          _showMessage('Admin accounts are built-in. Please sign in with the admin account.');
          return;
        }

        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final inputName = _nameController.text.trim();
        final displayName = inputName.isNotEmpty
            ? inputName
          : (isBuiltInAdmin ? builtInAdminName(normalizedEmail) : null);

        if (displayName != null && displayName.isNotEmpty) {
          await credential.user?.updateDisplayName(displayName);
        }

        await _upsertUserProfile(credential.user, isNewUser: true);

        _showMessage('Account created successfully.');
        if (mounted) {
          setState(() {
            _isSignIn = true;
            _selectedRole = 'student';
          });
        }
      }
    } on FirebaseAuthException catch (error) {
      _showMessage(error.message ?? 'Authentication failed.');
    } catch (_) {
      _showMessage('Something went wrong while using Firebase Auth.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showMessage('Enter your email address first.');
      return;
    }

    if (!widget.firebaseReady) {
      _showMessage('Firebase is not connected yet.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      _showMessage('Password reset email sent.');
    } on FirebaseAuthException catch (error) {
      _showMessage(error.message ?? 'Could not send reset email.');
    } catch (_) {
      _showMessage('Could not send reset email.');
    }
  }

  Future<void> _upsertUserProfile(User? user, {required bool isNewUser}) async {
    if (user == null || !widget.firebaseReady) {
      return;
    }

    final profileRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final profileSnapshot = await profileRef.get();
    final shouldInitializeProfile = isNewUser || !profileSnapshot.exists;
    final normalizedEmail = user.email?.trim().toLowerCase();
    final isBuiltInAdmin = normalizedEmail != null && isBuiltInAdminEmail(normalizedEmail);
    final resolvedRole = isBuiltInAdmin ? 'admin' : _selectedRole;
    final resolvedName = isBuiltInAdmin
      ? builtInAdminName(normalizedEmail)
        : (_nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : user.displayName);

    final payload = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'displayName': resolvedName,
      if (shouldInitializeProfile || isBuiltInAdmin) 'role': resolvedRole,
      if (shouldInitializeProfile || isBuiltInAdmin) 'status': 'active',
      'lastLoginAt': FieldValue.serverTimestamp(),
      if (shouldInitializeProfile) 'createdAt': FieldValue.serverTimestamp(),
    };

    await profileRef.set(payload, SetOptions(merge: true));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: widget.firebaseReady ? FirebaseAuth.instance.authStateChanges() : null,
      builder: (context, snapshot) {
        final currentUser = snapshot.data;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF8FBFF), Color(0xFFEAF4FF), Color(0xFFFFFFFF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _Header(firebaseReady: widget.firebaseReady),
                  const SizedBox(height: 20),
                  if (currentUser != null) ...[
                    _SignedInCard(
                      user: currentUser,
                      onSignOut: () async {
                        await FirebaseAuth.instance.signOut();
                      },
                    ),
                  ] else ...[
                    _AuthCard(
                      isSignIn: _isSignIn,
                      isLoading: _isLoading,
                      formKey: _formKey,
                      emailController: _emailController,
                      passwordController: _passwordController,
                      nameController: _nameController,
                      onSubmit: _submit,
                      onResetPassword: _resetPassword,
                      onToggleMode: () {
                        setState(() {
                          _isSignIn = !_isSignIn;
                          if (_isSignIn) {
                            _selectedRole = 'student';
                          }
                        });
                      },
                      selectedRole: _selectedRole,
                      onRoleChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedRole = value;
                        });
                      },
                      firebaseReady: widget.firebaseReady,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.firebaseReady});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF2563EB), Color(0xFF38BDF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F172A),
            blurRadius: 32,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Kindergarten Teaching System',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInCard extends StatelessWidget {
  const _SignedInCard({required this.user, required this.onSignOut});

  final User user;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final displayName = (data?['displayName'] as String?)?.trim();
        final email = (data?['email'] as String?)?.trim();
        final role = (data?['role'] as String?)?.trim();
        final lastLoginAt = data?['lastLoginAt'];

        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.blue.shade50),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are signed in',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  email?.isNotEmpty == true ? email! : (user.email ?? 'No email on file'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF475569),
                      ),
                ),
                if ((displayName ?? user.displayName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Display name: ${displayName ?? user.displayName}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF475569),
                        ),
                  ),
                ],
                if (lastLoginAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Profile saved in Firestore',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF0F766E),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
                if (role != null && role.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Role: ${role[0].toUpperCase()}${role.substring(1)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF475569),
                        ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: onSignOut,
                        child: const Text('Sign out'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () async {
                        // Navigate to the profile edit screen
                        await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ProfileScreen(user: user, firebaseReady: true),
                        ));
                      },
                      child: const Text('Edit profile'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.isSignIn,
    required this.isLoading,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.nameController,
    required this.onSubmit,
    required this.onResetPassword,
    required this.onToggleMode,
    required this.selectedRole,
    required this.onRoleChanged,
    required this.firebaseReady,
  });

  final bool isSignIn;
  final bool isLoading;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController nameController;
  final VoidCallback onSubmit;
  final VoidCallback onResetPassword;
  final VoidCallback onToggleMode;
  final String selectedRole;
  final ValueChanged<String?> onRoleChanged;
  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.blue.shade50),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ToggleButtons(
                isSelected: [isSignIn, !isSignIn],
                onPressed: (_) => onToggleMode(),
                borderRadius: BorderRadius.circular(14),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: Text('Sign in'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: Text('Sign up'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (!isSignIn) ...[
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text('Student')),
                    DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                    DropdownMenuItem(value: 'parent', child: Text('Parent')),
                  ],
                  onChanged: onRoleChanged,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Enter an email address';
                  }
                  if (!text.contains('@')) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value ?? '';
                  if (text.length < 6) {
                    return 'Use at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLoading ? null : onSubmit,
                  child: Text(isLoading ? 'Please wait...' : (isSignIn ? 'Sign in' : 'Create account')),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: onToggleMode,
                    child: Text(isSignIn ? 'Need an account?' : 'Already have an account?'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: firebaseReady ? onResetPassword : null,
                    child: const Text('Reset password'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
