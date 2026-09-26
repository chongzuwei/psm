import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FeedbackAnalyticsScreen extends StatelessWidget {
  const FeedbackAnalyticsScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final feedbackStream = FirebaseFirestore.instance
        .collection('feedback')
        .where('teacherId', isEqualTo: user.uid)
        .snapshots();
    final attemptsStream = FirebaseFirestore.instance
        .collection('attempts')
        .where('teacherId', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Feedback and Analytics')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: feedbackStream,
        builder: (context, feedbackSnapshot) {
          if (feedbackSnapshot.hasError) {
            return const Center(
              child: Text('Unable to load feedback metrics.'),
            );
          }
          if (feedbackSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: attemptsStream,
            builder: (context, attemptsSnapshot) {
              if (attemptsSnapshot.hasError) {
                return const Center(
                  child: Text('Unable to load assessment metrics.'),
                );
              }
              if (attemptsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final feedback = feedbackSnapshot.data?.docs ?? const [];
              final attempts = attemptsSnapshot.data?.docs ?? const [];
              final ratings = feedback
                  .map((document) => _number(document.data()['rating']))
                  .whereType<double>()
                  .toList();
              final scores = attempts
                  .map((document) => _number(document.data()['score']))
                  .whereType<double>()
                  .toList();
              final averageRating = _average(ratings);
              final averageScore = _average(scores);
              final difficulty = averageScore == null
                  ? null
                  : 100 - averageScore;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Lesson engagement and assessment difficulty',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Use student feedback and quiz results to improve lesson delivery.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 620 ? 2 : 1;
                      return GridView.count(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: columns == 2 ? 2.2 : 3.1,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _MetricCard(
                            label: 'Feedback received',
                            value: '${feedback.length}',
                            detail: 'Responses',
                            icon: Icons.forum_outlined,
                            color: const Color(0xFF2563EB),
                          ),
                          _MetricCard(
                            label: 'Average rating',
                            value: averageRating == null
                                ? '--'
                                : '${averageRating.toStringAsFixed(1)} / 5',
                            detail: 'Lesson sentiment',
                            icon: Icons.star_outline,
                            color: const Color(0xFFD97706),
                          ),
                          _MetricCard(
                            label: 'Quiz attempts',
                            value: '${attempts.length}',
                            detail: 'Learner engagement',
                            icon: Icons.groups_outlined,
                            color: const Color(0xFF059669),
                          ),
                          _MetricCard(
                            label: 'Assessment difficulty',
                            value: difficulty == null
                                ? '--'
                                : '${difficulty.toStringAsFixed(0)}%',
                            detail: difficulty == null
                                ? 'Awaiting quiz results'
                                : 'Higher means harder',
                            icon: Icons.speed_outlined,
                            color: const Color(0xFF7C3AED),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _InsightSection(
                    title: 'Recent feedback',
                    icon: Icons.chat_bubble_outline,
                    child: feedback.isEmpty
                        ? const Text(
                            'No student feedback has been submitted yet.',
                          )
                        : Column(
                            children: feedback.take(5).map((document) {
                              final data = document.data();
                              final text =
                                  data['text'] as String? ??
                                  data['comment'] as String? ??
                                  'No written comment';
                              final rating = _number(data['rating']);
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(text),
                                subtitle: rating == null
                                    ? null
                                    : Text(
                                        'Rating: ${rating.toStringAsFixed(1)} / 5',
                                      ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static double? _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static double? _average(List<double> values) {
    if (values.isEmpty) return null;
    return values.reduce((left, right) => left + right) / values.length;
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(detail, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightSection extends StatelessWidget {
  const _InsightSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
