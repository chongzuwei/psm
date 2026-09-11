import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({
    super.key,
    required this.studentId,
    required this.firebaseReady,
  });

  final String studentId;
  final bool firebaseReady;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _model = 'gemini-3.6-flash';

  final _questionController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text: 'Hi! Ask me about a quiz topic and I will explain it step by step.',
      isUser: false,
    ),
  ];
  bool _isLoading = false;

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _askQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();
    _questionController.clear();
    setState(() {
      _messages.add(_ChatMessage(text: question, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      if (_apiKey.isEmpty) {
        throw Exception('Gemini API key is missing.');
      }

      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'system_instruction': {
            'parts': [
              {
                'text': 'You are a friendly study tutor for students. Explain quiz topics clearly and briefly, guide the student to understand the answer, and do not help with unsafe or unrelated requests.',
              },
            ],
          },
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': question},
              ],
            },
          ],
          'generationConfig': {'temperature': 0.4},
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Gemini request failed (${response.statusCode}): ${_errorDetail(response.body)}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>? ?? const [];
      final answer = candidates.isEmpty
          ? ''
          : (((candidates.first as Map<String, dynamic>)['content'] as Map<String, dynamic>?)?['parts'] as List<dynamic>?)
                  ?.map((part) => (part as Map<String, dynamic>)['text'])
                  .whereType<String>()
                  .join('\n') ??
              '';
      if (answer.trim().isEmpty) {
        throw Exception('Gemini returned an empty answer.');
      }

      if (widget.firebaseReady) {
        try {
          await FirebaseFirestore.instance.collection('ai_questions').add({
            'studentId': widget.studentId,
            'question': question,
            'answer': answer,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {
          // Showing the AI answer should not depend on Firestore rules being deployed.
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(_ChatMessage(text: answer.trim(), isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(_ChatMessage(
          text: error.toString().contains('API key')
              ? 'The AI tutor is not configured yet. Run the app with GEMINI_API_KEY.'
              : 'I could not answer right now. ${error.toString().replaceFirst('Exception: ', '')}',
          isUser: false,
          isError: true,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  String _errorDetail(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>?;
      return (error?['message'] as String?) ?? 'Unknown API error';
    } catch (_) {
      return 'Unknown API error';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask AI'),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            onPressed: _isLoading
                ? null
                : () => setState(() {
                      _messages
                        ..clear()
                        ..add(const _ChatMessage(
                          text: 'Hi! Ask me about a quiz topic and I will explain it step by step.',
                          isUser: false,
                        ));
                    }),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const _TypingIndicator();
                }
                return _MessageBubble(message: _messages[index]);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      onSubmitted: (_) => _askQuestion(),
                      decoration: const InputDecoration(
                        hintText: 'Ask about your quiz...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send question',
                    onPressed: _isLoading ? null : _askQuestion,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.isUser, this.isError = false});

  final String text;
  final bool isUser;
  final bool isError;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: message.isError
              ? colorScheme.errorContainer
              : message.isUser
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isError
                ? colorScheme.onErrorContainer
                : message.isUser
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 12, left: 4),
        child: Row(
          children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text('AI is thinking...'),
          ],
        ),
      ),
    );
  }
}
