import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class QuizManagementScreen extends StatefulWidget {
  const QuizManagementScreen({super.key, required this.user});

  final User user;

  @override
  State<QuizManagementScreen> createState() => _QuizManagementScreenState();
}

class _QuizManagementScreenState extends State<QuizManagementScreen> {
  final _quizzes = FirebaseFirestore.instance.collection('quizzes');

  Future<void> _openEditor({QueryDocumentSnapshot<Map<String, dynamic>>? document}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _QuizEditorSheet(user: widget.user, document: document),
    );
  }

  Future<void> _deleteQuiz(QueryDocumentSnapshot<Map<String, dynamic>> document) async {
    final title = document.data()['title'] as String? ?? 'this quiz';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete quiz?'),
        content: Text('Remove "$title" and its questions?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await document.reference.delete();
      if (mounted) _message('Quiz deleted.');
    } on FirebaseException catch (error) {
      if (mounted) _message('Delete failed (${error.code}).');
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Quizzes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Create quiz'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _quizzes.where('ownerId', isEqualTo: widget.user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Unable to load quizzes.'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('No quizzes created yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final questions = (data['questions'] as List<dynamic>?) ?? const [];
              final published = data['published'] == true;
              return Card(
                elevation: 0,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE0E7FF),
                    child: Icon(published ? Icons.visibility_outlined : Icons.edit_note_outlined, color: const Color(0xFF1D4ED8)),
                  ),
                  title: Text(data['title'] as String? ?? 'Untitled quiz'),
                  subtitle: Text('${data['topic'] ?? 'General'} · ${questions.length} question${questions.length == 1 ? '' : 's'} · ${published ? 'Published' : 'Draft'}'),
                  onTap: () => _openEditor(document: doc),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit quiz',
                        onPressed: () => _openEditor(document: doc),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete quiz',
                        onPressed: () => _deleteQuiz(doc),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
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

class _QuizEditorSheet extends StatefulWidget {
  const _QuizEditorSheet({required this.user, this.document});

  final User user;
  final QueryDocumentSnapshot<Map<String, dynamic>>? document;

  @override
  State<_QuizEditorSheet> createState() => _QuizEditorSheetState();
}

class _QuizEditorSheetState extends State<_QuizEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _topic;
  late final TextEditingController _description;
  late bool _published;
  late List<_QuestionDraft> _questions;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.document?.data() ?? const <String, dynamic>{};
    _title = TextEditingController(text: data['title'] as String? ?? '');
    _topic = TextEditingController(text: data['topic'] as String? ?? '');
    _description = TextEditingController(text: data['description'] as String? ?? '');
    _published = data['published'] == true;
    final stored = (data['questions'] as List<dynamic>?) ?? const [];
    _questions = stored.map((item) => _QuestionDraft.fromMap(Map<String, dynamic>.from(item as Map))).toList();
    if (_questions.isEmpty) _questions.add(_QuestionDraft());
  }

  @override
  void dispose() {
    _title.dispose();
    _topic.dispose();
    _description.dispose();
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payload = {
        'title': _title.text.trim(),
        'topic': _topic.text.trim(),
        'description': _description.text.trim(),
        'questions': _questions.map((question) => question.toMap()).toList(),
        'published': _published,
        'ownerId': widget.user.uid,
        'ownerName': widget.user.displayName ?? widget.user.email ?? 'Teacher',
        'updatedAt': FieldValue.serverTimestamp(),
        if (widget.document == null) 'createdAt': FieldValue.serverTimestamp(),
      };
      final reference = widget.document?.reference ?? FirebaseFirestore.instance.collection('quizzes').doc();
      await reference.set(payload, SetOptions(merge: true));
      if (mounted) Navigator.pop(context);
    } on FirebaseException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save quiz (${error.code}).')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.document == null ? 'Create quiz' : 'Edit quiz', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Quiz title', border: OutlineInputBorder()), validator: (value) => value?.trim().isEmpty == true ? 'Enter a title' : null),
                const SizedBox(height: 12),
                TextFormField(controller: _topic, decoration: const InputDecoration(labelText: 'Topic', border: OutlineInputBorder()), validator: (value) => value?.trim().isEmpty == true ? 'Enter a topic' : null),
                const SizedBox(height: 12),
                TextFormField(controller: _description, maxLines: 2, decoration: const InputDecoration(labelText: 'Instructions (optional)', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                ..._questions.asMap().entries.map((entry) => _QuestionEditor(
                      key: ObjectKey(entry.value),
                      index: entry.key,
                      draft: entry.value,
                      onRemove: _questions.length == 1 ? null : () => setState(() => _questions.remove(entry.value)),
                    )),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _questions.add(_QuestionDraft())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add question'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _published,
                  onChanged: (value) => setState(() => _published = value),
                  title: const Text('Publish quiz'),
                  subtitle: const Text('Published quizzes are available to students.'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving...' : 'Save quiz')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionEditor extends StatelessWidget {
  const _QuestionEditor({super.key, required this.index, required this.draft, required this.onRemove});

  final int index;
  final _QuestionDraft draft;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [Expanded(child: Text('Question ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700))), if (onRemove != null) IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline))]),
            TextFormField(controller: draft.prompt, decoration: const InputDecoration(labelText: 'Question', border: OutlineInputBorder()), validator: (value) => value?.trim().isEmpty == true ? 'Enter a question' : null),
            const SizedBox(height: 10),
            for (var index = 0; index < 4; index++) ...[
              TextFormField(controller: draft.options[index], decoration: InputDecoration(labelText: 'Option ${String.fromCharCode(65 + index)}', border: const OutlineInputBorder()), validator: (value) => value?.trim().isEmpty == true ? 'Enter all options' : null),
              const SizedBox(height: 8),
            ],
            DropdownButtonFormField<int>(
              initialValue: draft.correctAnswer,
              decoration: const InputDecoration(labelText: 'Correct answer', border: OutlineInputBorder()),
              items: const [DropdownMenuItem(value: 0, child: Text('Option A')), DropdownMenuItem(value: 1, child: Text('Option B')), DropdownMenuItem(value: 2, child: Text('Option C')), DropdownMenuItem(value: 3, child: Text('Option D'))],
              onChanged: (value) => draft.correctAnswer = value ?? 0,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionDraft {
  _QuestionDraft()
      : prompt = TextEditingController(),
        options = List.generate(4, (_) => TextEditingController()),
        correctAnswer = 0;

  _QuestionDraft.fromMap(Map<String, dynamic> data)
      : prompt = TextEditingController(text: data['prompt'] as String? ?? ''),
        options = (data['options'] as List<dynamic>? ?? const ['', '', '', '']).map((value) => TextEditingController(text: value as String? ?? '')).toList(),
        correctAnswer = data['correctAnswer'] as int? ?? 0 {
    while (options.length < 4) {
      options.add(TextEditingController());
    }
  }

  final TextEditingController prompt;
  final List<TextEditingController> options;
  int correctAnswer;

  Map<String, dynamic> toMap() => {
        'prompt': prompt.text.trim(),
        'options': options.map((controller) => controller.text.trim()).toList(),
        'correctAnswer': correctAnswer,
      };

  void dispose() {
    prompt.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}
