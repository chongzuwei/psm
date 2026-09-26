import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final attempts = FirebaseFirestore.instance
        .collection('attempts')
        .where('studentId', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: attempts,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load achievements.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = [...?snapshot.data?.docs]
            ..sort((a, b) => _date(b).compareTo(_date(a)));
          final scores = records
              .map((record) => _score(record))
              .whereType<double>()
              .toList();
          final average = scores.isEmpty
              ? 0
              : scores.reduce((a, b) => a + b) / scores.length;
          final perfect = scores.any((score) => score >= 100);
          final milestones = [
            _Milestone(
              'First steps',
              'Complete your first quiz',
              records.isNotEmpty,
              Icons.flag_outlined,
              records.length,
              1,
            ),
            _Milestone(
              'Quiz explorer',
              'Complete 3 quizzes',
              records.length >= 3,
              Icons.explore_outlined,
              records.length,
              3,
            ),
            _Milestone(
              'High achiever',
              'Reach an average score of 80%',
              average >= 80,
              Icons.school_outlined,
              average.round(),
              80,
            ),
            _Milestone(
              'Perfect score',
              'Get 100% on a quiz',
              perfect,
              Icons.workspace_premium_outlined,
              perfect ? 1 : 0,
              1,
            ),
          ];
          final earned = milestones
              .where((milestone) => milestone.earned)
              .length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Your academic rewards',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text('$earned of ${milestones.length} milestones earned'),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Color(0xFFFFF3CD),
                        foregroundColor: Color(0xFFD97706),
                        child: Icon(Icons.emoji_events_outlined, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$earned milestones earned',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${records.length} quizzes completed · ${average == 0 ? '--' : '${average.toStringAsFixed(0)}%'} average score',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Milestones',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...milestones.map(
                (milestone) => _MilestoneTile(milestone: milestone),
              ),
              if (records.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Recent quiz results',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...records.take(5).map((record) {
                  final data = record.data();
                  final score = _score(record);
                  return ListTile(
                    leading: const Icon(Icons.quiz_outlined),
                    title: Text(data['quizTitle'] as String? ?? 'Quiz'),
                    subtitle: Text(_dateLabel(_date(record))),
                    trailing: Text(
                      '${score?.toStringAsFixed(0) ?? '--'}%',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }

  static double? _score(QueryDocumentSnapshot<Map<String, dynamic>> record) =>
      record.data()['score'] is num
      ? (record.data()['score'] as num).toDouble()
      : null;
  static DateTime _date(QueryDocumentSnapshot<Map<String, dynamic>> record) =>
      record.data()['submittedAt'] is Timestamp
      ? (record.data()['submittedAt'] as Timestamp).toDate()
      : DateTime.fromMillisecondsSinceEpoch(0);
  static String _dateLabel(DateTime date) => date.millisecondsSinceEpoch == 0
      ? 'Date unavailable'
      : '${date.day}/${date.month}/${date.year}';
}

class _Milestone {
  const _Milestone(
    this.title,
    this.description,
    this.earned,
    this.icon,
    this.current,
    this.target,
  );
  final String title;
  final String description;
  final bool earned;
  final IconData icon;
  final int current;
  final int target;
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({required this.milestone});
  final _Milestone milestone;

  @override
  Widget build(BuildContext context) {
    final progress = (milestone.current / milestone.target).clamp(0.0, 1.0);
    return Card(
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: milestone.earned
              ? const Color(0xFFFFF3CD)
              : const Color(0xFFE5E7EB),
          foregroundColor: milestone.earned
              ? const Color(0xFFD97706)
              : Colors.grey.shade600,
          child: Icon(milestone.earned ? milestone.icon : Icons.lock_outline),
        ),
        title: Text(
          milestone.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(milestone.description),
            if (!milestone.earned) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 2),
              Text('${milestone.current}/${milestone.target}'),
            ],
          ],
        ),
        trailing: milestone.earned
            ? const Icon(Icons.check_circle, color: Color(0xFF059669))
            : null,
      ),
    );
  }
}
