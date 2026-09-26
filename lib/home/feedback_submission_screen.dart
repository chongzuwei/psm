import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FeedbackSubmissionScreen extends StatefulWidget {
  const FeedbackSubmissionScreen({
    super.key,
    required this.user,
    required this.role,
  });

  final User user;
  final String role;

  @override
  State<FeedbackSubmissionScreen> createState() =>
      _FeedbackSubmissionScreenState();
}

class _FeedbackSubmissionScreenState extends State<FeedbackSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  String? _teacherId;
  int _rating = 0;
  bool _saving = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_teacherId == null || _rating == 0) {
      _showMessage('Choose a teacher and rating first.');
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'teacherId': _teacherId,
        'authorId': widget.user.uid,
        'authorEmail': widget.user.email,
        'authorRole': widget.role.trim().toLowerCase(),
        'rating': _rating,
        'text': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _commentController.clear();
      setState(() => _rating = 0);
      _showMessage('Feedback submitted to the teacher.');
    } on FirebaseException catch (error) {
      if (mounted) _showMessage('Could not submit feedback (${error.code}).');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final teachers = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'teacher')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Write Feedback')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: teachers,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load teachers.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final teacherDocs = snapshot.data?.docs ?? const [];
          if (teacherDocs.isEmpty) {
            return const Center(child: Text('No teachers are available yet.'));
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Help your teacher improve lessons',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your feedback will be visible to the selected teacher.',
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _teacherId,
                  decoration: const InputDecoration(
                    labelText: 'Teacher',
                    border: OutlineInputBorder(),
                  ),
                  items: teacherDocs.map((document) {
                    final data = document.data();
                    final name = (data['displayName'] as String?)?.trim();
                    final email = data['email'] as String? ?? 'Teacher';
                    return DropdownMenuItem(
                      value: document.id,
                      child: Text(name?.isNotEmpty == true ? name! : email),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _teacherId = value),
                  validator: (value) =>
                      value == null ? 'Select a teacher' : null,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Lesson rating',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (index) {
                    final value = index + 1;
                    return IconButton(
                      tooltip: '$value star${value == 1 ? '' : 's'}',
                      onPressed: () => setState(() => _rating = value),
                      icon: Icon(
                        value <= _rating ? Icons.star : Icons.star_border,
                        color: const Color(0xFFD97706),
                        size: 34,
                      ),
                    );
                  }),
                ),
                if (_rating == 0)
                  const Text(
                    'Select a rating from 1 to 5.',
                    style: TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _commentController,
                  minLines: 5,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Your feedback',
                    hintText: 'What helped you learn? What could improve?',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => value?.trim().isEmpty == true
                      ? 'Write some feedback'
                      : null,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: const Icon(Icons.send_outlined),
                  label: Text(_saving ? 'Submitting...' : 'Submit feedback'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
