import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/admin_accounts.dart';
import '../profile/profile_screen.dart';
import 'admin_user_management_screen.dart';
import 'schedule_availability_screen.dart';

class RoleHomeScreen extends StatelessWidget {
  const RoleHomeScreen({
    super.key,
    required this.user,
    required this.firebaseReady,
  });

  final User user;
  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final status = (data?['status'] as String?)?.trim().toLowerCase();
        if (status == 'inactive') {
          return _InactiveAccountScreen(user: user);
        }

        final role = _resolveRole(data, user);
        final displayName = (data?['displayName'] as String?)?.trim();

        if (role == null) {
          return _MissingRoleScreen(user: user);
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('${_toTitle(role)} Dashboard'),
            actions: [
              IconButton(
                tooltip: 'Edit profile',
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProfileScreen(user: user, firebaseReady: firebaseReady),
                  ));
                },
                icon: const Icon(Icons.person_outline),
              ),
              if (role == 'admin')
                IconButton(
                  tooltip: 'Manage users',
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AdminUserManagementScreen(),
                    ));
                  },
                  icon: const Icon(Icons.supervisor_account_outlined),
                ),
              IconButton(
                tooltip: 'Sign out',
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _WelcomeCard(
                role: role,
                displayName: displayName,
                email: user.email,
              ),
              const SizedBox(height: 16),
              ScheduleAvailabilitySummary(
                isAdmin: role == 'admin',
                onManagePressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ScheduleAvailabilityScreen(),
                  ));
                },
              ),
              const SizedBox(height: 16),
              ..._roleCards(role),
            ],
          ),
        );
      },
    );
  }

  String? _resolveRole(Map<String, dynamic>? data, User user) {
    final stored = (data?['role'] as String?)?.trim().toLowerCase();
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }

    final email = user.email?.trim().toLowerCase();
    if (email != null && isBuiltInAdminEmail(email)) {
      return 'admin';
    }

    return null;
  }

  List<Widget> _roleCards(String role) {
    switch (role) {
      case 'admin':
        return const [
          _FeatureCard(title: 'Manage Users', subtitle: 'Create, update roles, and deactivate accounts.', icon: Icons.supervisor_account_outlined),
          _FeatureCard(title: 'Schedule Availability', subtitle: 'Organize learning slots and avoid conflicts.', icon: Icons.calendar_month_outlined),
          _FeatureCard(title: 'Learning Materials', subtitle: 'Review and delete outdated modules.', icon: Icons.menu_book_outlined),
          _FeatureCard(title: 'Payment Notifications', subtitle: 'Receive parent payment updates and status alerts.', icon: Icons.notifications_active_outlined),
        ];
      case 'teacher':
        return const [
          _FeatureCard(title: 'Manage Quizzes', subtitle: 'Create and publish quizzes for students.', icon: Icons.quiz_outlined),
          _FeatureCard(title: 'Upload Resources', subtitle: 'Share notes and study materials.', icon: Icons.upload_file_outlined),
          _FeatureCard(title: 'Parent Messaging', subtitle: 'Send updates and discuss student progress.', icon: Icons.forum_outlined),
          _FeatureCard(title: 'Feedback and Analytics', subtitle: 'Review student feedback and class performance.', icon: Icons.insights_outlined),
        ];
      case 'parent':
        return const [
          _FeatureCard(title: 'Teacher Messaging', subtitle: 'Communicate with teachers about progress.', icon: Icons.chat_bubble_outline),
          _FeatureCard(title: 'Progress Tracking', subtitle: 'Monitor child achievements and results.', icon: Icons.trending_up_outlined),
          _FeatureCard(title: 'Payments', subtitle: 'Make payments and view receipt history.', icon: Icons.payments_outlined),
          _FeatureCard(title: 'Notifications', subtitle: 'Receive reminders and important school updates.', icon: Icons.notifications_none_outlined),
        ];
      case 'student':
        return const [
          _FeatureCard(title: 'Play Quiz', subtitle: 'Attempt quizzes to test your understanding.', icon: Icons.sports_esports_outlined),
          _FeatureCard(title: 'Learning Materials', subtitle: 'Open resources for lessons and revision.', icon: Icons.library_books_outlined),
          _FeatureCard(title: 'Achievements', subtitle: 'Track badges, points, and progress.', icon: Icons.emoji_events_outlined),
          _FeatureCard(title: 'Ask AI', subtitle: 'Ask questions when you need help with answers.', icon: Icons.smart_toy_outlined),
        ];
      default:
        return const [
          _FeatureCard(title: 'Access Pending', subtitle: 'Your role is not recognized yet. Contact admin.', icon: Icons.warning_amber_outlined),
        ];
    }
  }

  String _toTitle(String role) {
    if (role.isEmpty) {
      return role;
    }
    return '${role[0].toUpperCase()}${role.substring(1)}';
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.role,
    required this.displayName,
    required this.email,
  });

  final String role;
  final String? displayName;
  final String? email;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome ${displayName?.isNotEmpty == true ? displayName : (email ?? 'User')}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Role: ${role[0].toUpperCase()}${role.substring(1)}',
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.shade50),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE0E7FF),
          child: Icon(icon, color: const Color(0xFF1D4ED8)),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class ScheduleAvailabilitySummary extends StatelessWidget {
  const ScheduleAvailabilitySummary({
    super.key,
    required this.isAdmin,
    required this.onManagePressed,
  });

  final bool isAdmin;
  final VoidCallback onManagePressed;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('schedules').orderBy('sortKey').snapshots(),
      builder: (context, snapshot) {
        final slots = (snapshot.data?.docs ?? const [])
            .where((doc) => doc.data()['active'] != false)
            .toList();

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.blue.shade100),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFE0E7FF),
                      child: const Icon(Icons.calendar_month_outlined, color: Color(0xFF1D4ED8)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Teaching Hours',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          SizedBox(height: 2),
                          Text('Current availability shared with students and staff.'),
                        ],
                      ),
                    ),
                    if (isAdmin)
                      TextButton.icon(
                        onPressed: onManagePressed,
                        icon: const Icon(Icons.edit_calendar_outlined),
                        label: const Text('Manage'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (slots.isEmpty)
                  Text(
                    isAdmin
                        ? 'No availability slots configured yet. Add teaching hours for the week.'
                        : 'No teaching hours have been published yet.',
                    style: TextStyle(color: Colors.grey.shade700),
                  )
                else
                  Column(
                    children: slots.map((doc) => _ScheduleSlotTile(data: doc.data())).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScheduleSlotTile extends StatelessWidget {
  const _ScheduleSlotTile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final day = (data['dayLabel'] as String?)?.trim().isNotEmpty == true
        ? data['dayLabel'] as String
        : _dayLabel(data['dayIndex'] as int?);
    final start = (data['startTimeLabel'] as String?)?.trim() ?? '--:--';
    final end = (data['endTimeLabel'] as String?)?.trim() ?? '--:--';
    final note = (data['notes'] as String?)?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade50),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time_outlined, color: Color(0xFF1D4ED8)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$day · $start - $end',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(note),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dayLabel(int? index) {
    switch (index) {
      case 0:
        return 'Monday';
      case 1:
        return 'Tuesday';
      case 2:
        return 'Wednesday';
      case 3:
        return 'Thursday';
      case 4:
        return 'Friday';
      case 5:
        return 'Saturday';
      case 6:
        return 'Sunday';
      default:
        return 'Day';
    }
  }
}

class _MissingRoleScreen extends StatelessWidget {
  const _MissingRoleScreen({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Required'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 42, color: Color(0xFF334155)),
              const SizedBox(height: 12),
              Text(
                'No role assigned for ${user.email ?? 'this account'}.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Ask an admin to assign a role in the users collection before accessing the dashboard.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InactiveAccountScreen extends StatelessWidget {
  const _InactiveAccountScreen({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Disabled'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block_outlined, size: 42, color: Color(0xFF334155)),
              const SizedBox(height: 12),
              Text(
                'This account has been disabled for ${user.email ?? 'sign-in'}.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Contact an administrator to restore access or update the account status.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
