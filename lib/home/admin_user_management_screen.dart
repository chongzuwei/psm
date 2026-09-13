import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/admin_accounts.dart';
import '../firebase_options.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() => _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? const [];
          final users = _filteredAndSortedUsers(docs);
          final activeCount = docs.where((doc) => _userStatus(doc.data()) != 'inactive').length;
          final adminCount = docs.where((doc) => _userRole(doc.data()) == 'admin').length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryHeader(
                totalUsers: docs.length,
                activeUsers: activeCount,
                adminUsers: adminCount,
                onCreatePressed: () async {
                  await _openCreator(context);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search users',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (users.isEmpty)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.blue.shade100),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No users match the current search.'),
                  ),
                )
              else
                ...users.map((doc) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _UserCard(
                        data: doc.data(),
                        onEdit: () async {
                          await _openEditor(context, doc);
                        },
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredAndSortedUsers(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final filtered = docs.where((doc) {
      if (_searchText.isEmpty) {
        return true;
      }

      final data = doc.data();
      final haystack = [
        data['displayName'],
        data['email'],
        data['role'],
        data['status'],
        data['uid'],
      ].whereType<String>().join(' ').toLowerCase();

      return haystack.contains(_searchText);
    }).toList();

    filtered.sort((left, right) {
      final leftStatus = _userStatus(left.data());
      final rightStatus = _userStatus(right.data());
      if (leftStatus != rightStatus) {
        if (leftStatus == 'active') {
          return -1;
        }
        if (rightStatus == 'active') {
          return 1;
        }
      }

      final leftRole = _userRole(left.data());
      final rightRole = _userRole(right.data());
      if (leftRole != rightRole) {
        if (leftRole == 'admin') {
          return -1;
        }
        if (rightRole == 'admin') {
          return 1;
        }
      }

      final leftName = _userLabel(left.data()).toLowerCase();
      final rightName = _userLabel(right.data()).toLowerCase();
      return leftName.compareTo(rightName);
    });

    return filtered;
  }

  Future<void> _openEditor(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _EditUserSheet(
          doc: doc,
          currentUserId: FirebaseAuth.instance.currentUser?.uid,
        );
      },
    );
  }

  Future<void> _openCreator(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return const _CreateUserSheet();
      },
    );
  }

  String _userLabel(Map<String, dynamic> data) {
    final displayName = (data['displayName'] as String?)?.trim();
    final email = (data['email'] as String?)?.trim();
    return displayName != null && displayName.isNotEmpty ? displayName : (email ?? 'Unnamed user');
  }

  String _userRole(Map<String, dynamic> data) {
    final email = (data['email'] as String?)?.trim().toLowerCase();
    final stored = (data['role'] as String?)?.trim().toLowerCase();
    if (email != null && isBuiltInAdminEmail(email)) {
      return 'admin';
    }
    if (stored == null || stored.isEmpty) {
      return 'student';
    }
    return stored;
  }

  String _userStatus(Map<String, dynamic> data) {
    final stored = (data['status'] as String?)?.trim().toLowerCase();
    if (stored == null || stored.isEmpty) {
      return 'active';
    }
    return stored;
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.totalUsers,
    required this.activeUsers,
    required this.adminUsers,
    required this.onCreatePressed,
  });

  final int totalUsers;
  final int activeUsers;
  final int adminUsers;
  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System user profiles',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Review accounts, update roles, and disable access when needed.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCreatePressed,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Create user profile'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _StatTile(label: 'Total', value: totalUsers.toString(), icon: Icons.groups_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _StatTile(label: 'Active', value: activeUsers.toString(), icon: Icons.verified_user_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _StatTile(label: 'Admins', value: adminUsers.toString(), icon: Icons.admin_panel_settings_outlined)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade50),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1D4ED8)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.data, required this.onEdit});

  final Map<String, dynamic> data;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final label = _displayLabel(data);
    final email = (data['email'] as String?)?.trim() ?? 'No email';
    final role = _roleLabel(data);
    final status = _statusLabel(data);
    final isProtectedAdmin = email.toLowerCase() == 'admin@psm.com';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: const Color(0xFFE0E7FF),
                    child: Text(
                      _initials(label),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edit user',
                              onPressed: onEdit,
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ],
                        ),
                        Text(email),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ChipLabel(label: role, icon: Icons.badge_outlined),
                  _ChipLabel(label: status, icon: status == 'active' ? Icons.verified_user_outlined : Icons.pause_circle_outline),
                  if (isProtectedAdmin) const _ChipLabel(label: 'Protected admin', icon: Icons.lock_outline),
                  if (_hasTeacherDocument(data))
                    const _ChipLabel(label: 'Document pending review', icon: Icons.description_outlined),
                ],
              ),
              if (_hasTeacherDocument(data)) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _openTeacherDocument(context, data),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(data['teacherDocumentName'] as String? ?? 'Open supporting document'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _displayLabel(Map<String, dynamic> data) {
    final displayName = (data['displayName'] as String?)?.trim();
    final email = (data['email'] as String?)?.trim();
    return displayName != null && displayName.isNotEmpty ? displayName : (email ?? 'Unnamed user');
  }

  String _roleLabel(Map<String, dynamic> data) {
    final role = (data['role'] as String?)?.trim();
    if (role == null || role.isEmpty) {
      return 'student';
    }
    return role;
  }

  String _statusLabel(Map<String, dynamic> data) {
    final status = (data['status'] as String?)?.trim();
    if (status == null || status.isEmpty) {
      return 'active';
    }
    return status;
  }

  String _initials(String label) {
    final words = label
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return '?';
    }
    if (words.length == 1) {
      return words.first.characters.first.toUpperCase();
    }
    return '${words.first.characters.first}${words.last.characters.first}'.toUpperCase();
  }

  bool _hasTeacherDocument(Map<String, dynamic> data) {
    return _roleLabel(data) == 'teacher' &&
        (data['teacherDocumentUrl'] as String?)?.isNotEmpty == true &&
        data['teacherDocumentStatus'] != 'approved';
  }

  Future<void> _openTeacherDocument(BuildContext context, Map<String, dynamic> data) async {
    final url = data['teacherDocumentUrl'] as String?;
    if (url == null || !await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open supporting document.')),
        );
      }
    }
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      side: BorderSide.none,
      backgroundColor: const Color(0xFFF1F5F9),
    );
  }
}

class _EditUserSheet extends StatefulWidget {
  const _EditUserSheet({required this.doc, required this.currentUserId});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String? currentUserId;

  @override
  State<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends State<_EditUserSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late String _role;
  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.doc.data();
    _displayNameController = TextEditingController(text: _displayLabel(data));
    _role = _initialRole(data);
    _status = _initialStatus(data);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data();
    final email = (data['email'] as String?)?.trim() ?? 'No email';
    final isProtectedAdmin = isBuiltInAdminEmail(email);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _displayLabel(data),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(email),
                const SizedBox(height: 12),
                if (isProtectedAdmin)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'This is the built-in system admin account. Role and status are protected.',
                    ),
                  ),
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value?.trim().isEmpty ?? true) ? 'Enter a display name' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text('Student')),
                    DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                    DropdownMenuItem(value: 'parent', child: Text('Parent')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: isProtectedAdmin
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _role = value;
                          });
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Account status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'pending_review', child: Text('Pending review')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  ],
                  onChanged: isProtectedAdmin
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _status = value;
                          });
                        },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save changes'),
                  ),
                ),
                if (_role == 'teacher' && _status == 'pending_review') ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _approveTeacher,
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Approve teacher'),
                    ),
                  ),
                ],
                if (!isProtectedAdmin && widget.doc.id != widget.currentUserId) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _deleteProfile,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete user profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_status == 'inactive' && widget.doc.id == widget.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot deactivate your own account.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final data = widget.doc.data();
      final email = (data['email'] as String?)?.trim();
      final isProtectedAdmin = email != null && isBuiltInAdminEmail(email);
      final previousRole = (data['role'] as String?)?.trim().toLowerCase();
      final nextRole = isProtectedAdmin ? 'admin' : _role;
      final payload = <String, dynamic>{
        'displayName': _displayNameController.text.trim(),
        'role': nextRole,
        'status': isProtectedAdmin ? 'active' : _status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final batch = FirebaseFirestore.instance.batch();
      batch.set(widget.doc.reference, payload, SetOptions(merge: true));
      batch.set(
        FirebaseFirestore.instance.collection('${nextRole}s').doc(widget.doc.id),
        {...data, ...payload, 'uid': widget.doc.id},
        SetOptions(merge: true),
      );
      if (previousRole != null && previousRole != nextRole) {
        batch.delete(
          FirebaseFirestore.instance.collection('${previousRole}s').doc(widget.doc.id),
        );
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User profile updated.')),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _approveTeacher() async {
    setState(() => _saving = true);
    try {
      final data = widget.doc.data();
      final payload = <String, dynamic>{
        'status': 'active',
        'teacherDocumentStatus': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final batch = FirebaseFirestore.instance.batch();
      batch.set(widget.doc.reference, payload, SetOptions(merge: true));
      batch.set(
        FirebaseFirestore.instance.collection('teachers').doc(widget.doc.id),
        {...data, ...payload, 'uid': widget.doc.id},
        SetOptions(merge: true),
      );
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teacher approved successfully.')),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approval failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteProfile() async {
    final data = widget.doc.data();
    final name = _displayLabel(data);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete user profile?'),
        content: Text(
          'This permanently removes $name from the Firestore users database. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.doc.reference.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User profile deleted.')),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _displayLabel(Map<String, dynamic> data) {
    final displayName = (data['displayName'] as String?)?.trim();
    final email = (data['email'] as String?)?.trim();
    return displayName != null && displayName.isNotEmpty ? displayName : (email ?? 'Unnamed user');
  }

  String _initialRole(Map<String, dynamic> data) {
    final email = (data['email'] as String?)?.trim().toLowerCase();
    final stored = (data['role'] as String?)?.trim().toLowerCase();
    if (email != null && isBuiltInAdminEmail(email)) {
      return 'admin';
    }
    if (stored == null || stored.isEmpty) {
      return 'student';
    }
    return stored;
  }

  String _initialStatus(Map<String, dynamic> data) {
    final stored = (data['status'] as String?)?.trim().toLowerCase();
    if (stored == null || stored.isEmpty) {
      return 'active';
    }
    return stored;
  }
}

class _CreateUserSheet extends StatefulWidget {
  const _CreateUserSheet();

  @override
  State<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends State<_CreateUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  String _role = 'student';
  String _status = 'active';
  bool _saving = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Create user profile',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Create an account and categorize it with a role and account status.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
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
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Temporary password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if ((value?.trim().length ?? 0) < 6) {
                      return 'Use at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value?.trim().isEmpty ?? true) ? 'Enter a display name' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text('Student')),
                    DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                    DropdownMenuItem(value: 'parent', child: Text('Parent')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _role = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Account status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _status = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Creating...' : 'Create profile'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final displayName = _displayNameController.text.trim();
      if (isBuiltInAdminEmail(email)) {
        throw StateError('The built-in admin account already exists.');
      }

      final secondaryApp = await Firebase.initializeApp(
        name: 'admin-user-${DateTime.now().microsecondsSinceEpoch}',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      try {
        final credential = await FirebaseAuth.instanceFor(app: secondaryApp)
            .createUserWithEmailAndPassword(
              email: email,
              password: _passwordController.text.trim(),
            );
        final user = credential.user;
        if (user == null) {
          throw StateError('Firebase Auth did not return the new user.');
        }

        await user.updateDisplayName(displayName);
        final payload = <String, dynamic>{
          'uid': user.uid,
          'email': email,
          'displayName': displayName,
          'role': _role,
          'status': _status,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        final batch = FirebaseFirestore.instance.batch();
        batch.set(
          FirebaseFirestore.instance.collection('users').doc(user.uid),
          payload,
        );
        batch.set(
          FirebaseFirestore.instance.collection('${_role}s').doc(user.uid),
          payload,
        );
        await batch.commit();
      } finally {
        await secondaryApp.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User account and profile created.')),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Create failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }
}
