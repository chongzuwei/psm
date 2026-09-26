import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, required this.user, required this.role});

  final User user;
  final String role;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _recipientController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _attachmentController = TextEditingController();
  bool _sending = false;
  String? _selectedRecipient;
  String? _selectedSubject;

  @override
  void dispose() {
    _recipientController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    _attachmentController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final recipient = (_selectedRecipient ?? _recipientController.text)
        .trim()
        .toLowerCase();
    final message = _messageController.text.trim();
    final attachmentUrl = _attachmentController.text.trim();
    if (!recipient.contains('@') || message.isEmpty) {
      _showMessage('Select a contact and enter a message.');
      return;
    }
    if (attachmentUrl.isNotEmpty) {
      final parsedAttachment = Uri.tryParse(attachmentUrl);
      if (parsedAttachment?.hasScheme != true ||
          parsedAttachment?.host.isEmpty != false) {
        _showMessage('Attachment link must start with https://.');
        return;
      }
    }
    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': widget.user.uid,
        'senderEmail': widget.user.email?.trim().toLowerCase(),
        'recipientEmail': recipient,
        'conversationId': _conversationId(widget.user.email, recipient),
        'subject': 'Academic message',
        'message': message,
        if (attachmentUrl.isNotEmpty) 'attachmentUrl': attachmentUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _recipientController.clear();
      _messageController.clear();
      _attachmentController.clear();
      setState(() {
        _selectedRecipient = recipient;
        _selectedSubject = 'Academic message';
      });
    } on FirebaseException catch (error) {
      if (mounted) _showMessage('Could not send message (${error.code}).');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editMessage(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final controller = TextEditingController(
      text: document.data()['message'] as String? ?? '',
    );
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              await document.reference.update({
                'message': controller.text.trim(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _deleteMessage(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text(
          'This message will be removed from the conversation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await document.reference.delete();
    if (mounted) _showMessage('Message deleted.');
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.user.email?.trim().toLowerCase() ?? '';
    final inbox = FirebaseFirestore.instance
        .collection('messages')
        .where('recipientEmail', isEqualTo: email)
        .snapshots();
    final sent = FirebaseFirestore.instance
        .collection('messages')
        .where('senderEmail', isEqualTo: email)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Messages')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: inbox,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load messages.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: sent,
            builder: (context, usersSnapshot) {
              if (usersSnapshot.hasError) {
                return const Center(
                  child: Text('Unable to load sent messages.'),
                );
              }
              if (usersSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = [
                ...?snapshot.data?.docs,
                ...?usersSnapshot.data?.docs,
              ]..sort((a, b) => _timestamp(b).compareTo(_timestamp(a)));
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where(
                      'role',
                      isEqualTo: widget.role == 'teacher'
                          ? 'parent'
                          : 'teacher',
                    )
                    .snapshots(),
                builder: (context, contactsSnapshot) {
                  if (contactsSnapshot.hasError) {
                    return const Center(
                      child: Text('Unable to load contacts.'),
                    );
                  }
                  if (contactsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final users = contactsSnapshot.data?.docs ?? const [];
                  if (_selectedRecipient == null && users.isNotEmpty) {
                    final firstAvailableUser = users
                        .cast<QueryDocumentSnapshot<Map<String, dynamic>>>()
                        .first;
                    final firstData = firstAvailableUser.data();
                    final firstEmail = (firstData['email'] as String?)
                        ?.toLowerCase();
                    if (firstEmail != null && firstEmail.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted || _selectedRecipient != null) return;
                        setState(() {
                          _selectedRecipient = firstEmail;
                          _selectedSubject = 'Academic message';
                          _recipientController.text = firstEmail;
                        });
                      });
                    }
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final rail = _ConversationRail(
                        messages: docs,
                        users: users,
                        currentUserEmail: email,
                        selectedRecipient: _selectedRecipient,
                        onSelected: (recipient, subject) => setState(() {
                          _selectedRecipient = recipient;
                          _selectedSubject = subject;
                          _recipientController.text = recipient;
                          _subjectController.text = subject;
                        }),
                      );
                      final chat = _ChatPanel(
                        messages: docs
                            .where((doc) => _conversationMatches(doc))
                            .toList(),
                        recipient: _selectedRecipient,
                        subject: _selectedSubject,
                        messageController: _messageController,
                        attachmentController: _attachmentController,
                        sending: _sending,
                        onSend: _sendMessage,
                        onAttach: _chooseAttachment,
                        onOpenAttachment: _openAttachment,
                        currentUserId: widget.user.uid,
                        currentUserEmail:
                            widget.user.email?.trim().toLowerCase() ?? '',
                        onEditMessage: _editMessage,
                        onDeleteMessage: _deleteMessage,
                      );
                      if (constraints.maxWidth < 700) {
                        return Column(children: [Expanded(child: chat)]);
                      }
                      return Row(
                        children: [
                          SizedBox(width: 300, child: rail),
                          Expanded(child: chat),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  bool _conversationMatches(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    if (_selectedRecipient == null) return false;
    final data = document.data();
    return (data['senderEmail'] as String?)?.toLowerCase() ==
            _selectedRecipient ||
        (data['recipientEmail'] as String?)?.toLowerCase() ==
            _selectedRecipient;
  }

  String _conversationId(String? senderEmail, String recipientEmail) {
    final participants = [
      senderEmail?.trim().toLowerCase() ?? '',
      recipientEmail.trim().toLowerCase(),
    ]..sort();
    return participants.join('_');
  }

  Future<void> _chooseAttachment() async {
    final controller = TextEditingController(text: _attachmentController.text);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attach document'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Google Drive / OneDrive link',
            hintText: 'https://...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Attach'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      setState(() => _attachmentController.text = controller.text.trim());
      _showMessage('Document attached.');
    }
    controller.dispose();
  }

  Future<void> _openAttachment(String url) async {
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      if (mounted) _showMessage('Unable to open attachment.');
    }
  }

  DateTime _timestamp(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final timestamp = document.data()['createdAt'];
    return timestamp is Timestamp
        ? timestamp.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _ConversationRail extends StatefulWidget {
  const _ConversationRail({
    required this.messages,
    required this.users,
    required this.currentUserEmail,
    required this.selectedRecipient,
    required this.onSelected,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> messages;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> users;
  final String currentUserEmail;
  final String? selectedRecipient;
  final void Function(String recipient, String subject) onSelected;

  @override
  State<_ConversationRail> createState() => _ConversationRailState();
}

class _ConversationRailState extends State<_ConversationRail> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final contacts = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    final allowedEmails = widget.users
        .map((user) => (user.data()['email'] as String?)?.toLowerCase())
        .whereType<String>()
        .toSet();
    for (final message in widget.messages) {
      final data = message.data();
      final sender = (data['senderEmail'] as String?)?.toLowerCase();
      final recipient = (data['recipientEmail'] as String?)?.toLowerCase();
      final participant = sender == widget.currentUserEmail
          ? recipient
          : sender;
      if (participant != null &&
          participant.isNotEmpty &&
          allowedEmails.contains(participant)) {
        contacts.putIfAbsent(participant, () => message);
      }
    }
    for (final user in widget.users) {
      final data = user.data();
      final email = (data['email'] as String?)?.toLowerCase();
      if (email != null && email.isNotEmpty) {
        contacts.putIfAbsent(email, () => user);
      }
    }
    final visibleContacts = contacts.entries.where((entry) {
      final data = entry.value.data();
      final displayName = (data['displayName'] as String?)?.toLowerCase() ?? '';
      return _search.isEmpty ||
          entry.key.contains(_search) ||
          displayName.contains(_search);
    }).toList();

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
            child: Row(
              children: [
                Text(
                  'Chats',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search messages',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF1F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: visibleContacts.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No users available.'),
                    ),
                  )
                : ListView(
                    children: visibleContacts.map((entry) {
                      final data = entry.value.data();
                      final isUser = data['email'] != null;
                      final displayName = data['displayName'] as String?;
                      final title = isUser && displayName?.isNotEmpty == true
                          ? displayName!
                          : entry.key;
                      final subject = isUser
                          ? entry.key
                          : data['subject'] as String? ?? 'No subject';
                      final selected = entry.key == widget.selectedRecipient;
                      return ListTile(
                        selected: selected,
                        selectedTileColor: const Color(0xFFE8F1FF),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF60A5FA),
                          foregroundColor: Colors.white,
                          child: Text(entry.key.substring(0, 1).toUpperCase()),
                        ),
                        title: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => widget.onSelected(entry.key, subject),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.messages,
    required this.recipient,
    required this.subject,
    required this.messageController,
    required this.attachmentController,
    required this.sending,
    required this.onSend,
    required this.onAttach,
    required this.onOpenAttachment,
    required this.currentUserId,
    required this.currentUserEmail,
    required this.onEditMessage,
    required this.onDeleteMessage,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> messages;
  final String? recipient;
  final String? subject;
  final TextEditingController messageController;
  final TextEditingController attachmentController;
  final bool sending;
  final Future<void> Function() onSend;
  final Future<void> Function() onAttach;
  final Future<void> Function(String) onOpenAttachment;
  final String currentUserId;
  final String currentUserEmail;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>>)
  onEditMessage;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>>)
  onDeleteMessage;

  @override
  Widget build(BuildContext context) {
    final hasConversation = recipient != null;
    return Container(
      color: const Color(0xFFE9F1F6),
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF2563EB),
                  child: Text(
                    hasConversation ? recipient![0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasConversation ? recipient! : 'New conversation',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        hasConversation
                            ? (subject ?? 'Academic conversation')
                            : 'Send a message about coursework',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: hasConversation && messages.isNotEmpty
                ? ListView.builder(
                    padding: const EdgeInsets.all(20),
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final data = messages[index].data();
                      final attachment = data['attachmentUrl'] as String?;
                      final isSentByCurrentUser =
                          data['senderId'] == currentUserId ||
                          (data['senderId'] == null &&
                              (data['senderEmail'] as String?)?.toLowerCase() ==
                                  currentUserEmail);
                      return TweenAnimationBuilder<double>(
                        key: ValueKey(messages[index].id),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        builder: (context, value, child) => Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 8 * (1 - value)),
                            child: child,
                          ),
                        ),
                        child: Align(
                          alignment: isSentByCurrentUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 520),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSentByCurrentUser
                                  ? const Color(0xFFD9FDD3)
                                  : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(
                                  isSentByCurrentUser ? 16 : 4,
                                ),
                                bottomRight: Radius.circular(
                                  isSentByCurrentUser ? 4 : 16,
                                ),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0D000000),
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['subject'] as String? ??
                                            'No subject',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(data['message'] as String? ?? ''),
                                      if (attachment?.isNotEmpty == true)
                                        TextButton.icon(
                                          onPressed: () =>
                                              onOpenAttachment(attachment!),
                                          icon: const Icon(
                                            Icons.attach_file,
                                            size: 18,
                                          ),
                                          label: const Text('Open document'),
                                        ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _formatMessageTime(
                                              data['createdAt'],
                                            ),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          if (isSentByCurrentUser) ...[
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.done_all,
                                              size: 15,
                                              color: Colors.blue.shade600,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSentByCurrentUser)
                                  PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    onSelected: (action) {
                                      if (action == 'edit') {
                                        onEditMessage(messages[index]);
                                      }
                                      if (action == 'delete') {
                                        onDeleteMessage(messages[index]);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : Center(
                    child: Text(
                      hasConversation
                          ? 'No messages in this conversation.'
                          : 'Choose a conversation or start a new message.',
                    ),
                  ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: messageController,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) {
                          if (!sending) onSend();
                        },
                        decoration: InputDecoration(
                          hintText: 'Write a message',
                          filled: true,
                          fillColor: const Color(0xFFF5F7FA),
                          prefixIcon: const Icon(Icons.message_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Attach document',
                      onPressed: sending ? null : onAttach,
                      icon: const Icon(Icons.attach_file),
                    ),
                    IconButton.filled(
                      tooltip: 'Send',
                      onPressed: sending ? null : onSend,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
                if (attachmentController.text.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Document attached',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatMessageTime(Object? value) {
  if (value is! Timestamp) return 'Sending...';
  final time = value.toDate().toLocal();
  final hour = time.hour == 0
      ? 12
      : (time.hour > 12 ? time.hour - 12 : time.hour);
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.hour >= 12 ? 'PM' : 'AM'}';
}
