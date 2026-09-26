import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProgressTrackingScreen extends StatefulWidget {
  const ProgressTrackingScreen({
    super.key,
    required this.user,
    required this.role,
  });

  final User user;
  final String role;

  @override
  State<ProgressTrackingScreen> createState() => _ProgressTrackingScreenState();
}

class _ProgressTrackingScreenState extends State<ProgressTrackingScreen> {
  String? _studentId;

  @override
  Widget build(BuildContext context) {
    final students = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Progress Tracking')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: students,
        builder: (context, studentsSnapshot) {
          if (studentsSnapshot.hasError) {
            return const Center(
              child: Text('Unable to load student profiles.'),
            );
          }
          if (studentsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final studentDocs = studentsSnapshot.data?.docs ?? const [];
          if (studentDocs.isEmpty) {
            return const Center(
              child: Text('No student records are available yet.'),
            );
          }
          final selectedId =
              studentDocs.any((student) => student.id == _studentId)
              ? _studentId
              : studentDocs.first.id;
          if (_studentId != selectedId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _studentId == null) {
                setState(() => _studentId = selectedId);
              }
            });
          }
          final selectedStudent = studentDocs.firstWhere(
            (student) => student.id == selectedId,
          );
          final studentData = selectedStudent.data();
          final attempts = widget.role == 'teacher'
              ? FirebaseFirestore.instance
                    .collection('attempts')
                    .where('teacherId', isEqualTo: widget.user.uid)
                    .snapshots()
              : FirebaseFirestore.instance
                    .collection('attempts')
                    .where('studentId', isEqualTo: selectedId)
                    .snapshots();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedId,
                decoration: InputDecoration(
                  labelText: widget.role == 'teacher' ? 'Student' : 'Child',
                  border: OutlineInputBorder(),
                ),
                items: studentDocs.map((student) {
                  final data = student.data();
                  final name = (data['displayName'] as String?)?.trim();
                  final email = data['email'] as String? ?? 'Student';
                  return DropdownMenuItem(
                    value: student.id,
                    child: Text(name?.isNotEmpty == true ? name! : email),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _studentId = value),
              ),
              const SizedBox(height: 16),
              Text(
                '${studentData['displayName'] as String? ?? studentData['email'] as String? ?? 'Child'} performance',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: attempts,
                builder: (context, attemptsSnapshot) {
                  if (attemptsSnapshot.hasError) {
                    return const Text('Unable to load performance records.');
                  }
                  if (attemptsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final records =
                      ([...?attemptsSnapshot.data?.docs]
                            .where(
                              (record) =>
                                  widget.role != 'teacher' ||
                                  record.data()['studentId'] == selectedId,
                            )
                            .toList())
                        ..sort((a, b) => _date(b).compareTo(_date(a)));
                  final scores = records
                      .map((record) => _number(record.data()['score']))
                      .whereType<double>()
                      .toList();
                  final average = scores.isEmpty
                      ? null
                      : scores.reduce((a, b) => a + b) / scores.length;
                  final latest = scores.isEmpty ? null : scores.first;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ProgressMetric(
                              label: 'Quizzes completed',
                              value: '${records.length}',
                              icon: Icons.assignment_turned_in_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ProgressMetric(
                              label: 'Average score',
                              value: average == null
                                  ? '--'
                                  : '${average.toStringAsFixed(0)}%',
                              icon: Icons.insights_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ProgressMetric(
                        label: 'Latest result',
                        value: latest == null
                            ? '--'
                            : '${latest.toStringAsFixed(0)}%',
                        icon: Icons.trending_up_outlined,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Performance history',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (records.isEmpty)
                        const Text('No completed quizzes for this child yet.')
                      else
                        ...records.map((record) {
                          final data = record.data();
                          final score = _number(data['score']);
                          return Card(
                            elevation: 0,
                            child: ListTile(
                              leading: const Icon(Icons.quiz_outlined),
                              title: Text(
                                data['quizTitle'] as String? ?? 'Quiz',
                              ),
                              subtitle: Text(_dateLabel(_date(record))),
                              trailing: Text(
                                score == null
                                    ? '--'
                                    : '${score.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  static double? _number(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  static DateTime _date(QueryDocumentSnapshot<Map<String, dynamic>> record) =>
      record.data()['submittedAt'] is Timestamp
      ? (record.data()['submittedAt'] as Timestamp).toDate()
      : DateTime.fromMillisecondsSinceEpoch(0);
  static String _dateLabel(DateTime date) => date.millisecondsSinceEpoch == 0
      ? 'Date unavailable'
      : '${date.day}/${date.month}/${date.year}';
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
