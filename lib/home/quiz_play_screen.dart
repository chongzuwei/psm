import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class QuizPlayScreen extends StatelessWidget {
  const QuizPlayScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final quizzes = FirebaseFirestore.instance
        .collection('quizzes')
        .where('published', isEqualTo: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Play Quiz')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: quizzes,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load quizzes.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('No published quizzes are available yet.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final questions =
                  (data['questions'] as List<dynamic>?) ?? const [];
              return Card(
                elevation: 0,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: const CircleAvatar(child: Icon(Icons.quiz_outlined)),
                  title: Text(data['title'] as String? ?? 'Untitled quiz'),
                  subtitle: Text(
                    '${data['topic'] as String? ?? 'General'} · ${questions.length} question${questions.length == 1 ? '' : 's'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          _QuizAttemptScreen(user: user, quiz: docs[index]),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _QuizAttemptScreen extends StatefulWidget {
  const _QuizAttemptScreen({required this.user, required this.quiz});

  final User user;
  final QueryDocumentSnapshot<Map<String, dynamic>> quiz;

  @override
  State<_QuizAttemptScreen> createState() => _QuizAttemptScreenState();
}

class _QuizAttemptScreenState extends State<_QuizAttemptScreen> {
  late final List<Map<String, dynamic>> _questions;
  late final List<int?> _answers;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final stored =
        (widget.quiz.data()['questions'] as List<dynamic>?) ?? const [];
    _questions = stored
        .map((question) => Map<String, dynamic>.from(question as Map))
        .toList();
    _answers = List<int?>.filled(_questions.length, null);
  }

  Future<void> _submit() async {
    if (_answers.any((answer) => answer == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Answer every question before submitting.'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    final correct = List.generate(_questions.length, (index) {
      final expected =
          (_questions[index]['correctAnswer'] as num?)?.toInt() ?? 0;
      return _answers[index] == expected;
    }).where((value) => value).length;
    final score = _questions.isEmpty
        ? 0
        : ((correct / _questions.length) * 100).round();
    try {
      await FirebaseFirestore.instance.collection('attempts').add({
        'quizId': widget.quiz.id,
        'quizTitle': widget.quiz.data()['title'] as String? ?? 'Quiz',
        'teacherId': widget.quiz.data()['ownerId'],
        'studentId': widget.user.uid,
        'score': score,
        'correctAnswers': correct,
        'totalQuestions': _questions.length,
        'submittedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Quiz complete'),
          content: Text(
            'You scored $score% ($correct/${_questions.length} correct).',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save attempt (${error.code}).')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.quiz.data();
    return Scaffold(
      appBar: AppBar(title: Text(data['title'] as String? ?? 'Quiz')),
      body: _questions.isEmpty
          ? const Center(child: Text('This quiz has no questions.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if ((data['description'] as String?)?.trim().isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(data['description'] as String),
                  ),
                ..._questions.asMap().entries.map(
                  (entry) => _QuestionCard(
                    number: entry.key + 1,
                    question: entry.value,
                    selected: _answers[entry.key],
                    onSelected: (value) =>
                        setState(() => _answers[entry.key] = value),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(_submitting ? 'Submitting...' : 'Submit quiz'),
                ),
              ],
            ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.number,
    required this.question,
    required this.selected,
    required this.onSelected,
  });

  final int number;
  final Map<String, dynamic> question;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final options =
        (question['options'] as List<dynamic>?)?.cast<String>() ??
        const <String>[];
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$number. ${question['prompt'] as String? ?? 'Question'}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...options.asMap().entries.map((entry) {
              final isSelected = entry.key == selected;
              return InkWell(
                onTap: () => onSelected(entry.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(entry.value)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
