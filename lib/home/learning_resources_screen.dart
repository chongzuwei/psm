import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LearningResourcesScreen extends StatefulWidget {
  const LearningResourcesScreen({
    super.key,
    required this.user,
    required this.canManage,
    this.canDelete = false,
    this.canUpload = false,
  });

  final User? user;
  final bool canManage;
  final bool canDelete;
  final bool canUpload;

  @override
  State<LearningResourcesScreen> createState() => _LearningResourcesScreenState();
}

class _LearningResourcesScreenState extends State<LearningResourcesScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _resourceUrlController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _resourceUrlController.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    final title = _titleController.text.trim();
    final resourceUrl = _resourceUrlController.text.trim();
    final user = widget.user;
    if (title.isEmpty || resourceUrl.isEmpty || user == null) {
      _showMessage('Enter a title and paste a document link.');
      return;
    }
    final parsedUrl = Uri.tryParse(resourceUrl);
    if (parsedUrl?.hasScheme != true || parsedUrl?.host.isEmpty != false) {
      _showMessage('Enter a complete link starting with https://.');
      return;
    }

    try {
      final resourceId = FirebaseFirestore.instance.collection('learning_resources').doc().id;
      await FirebaseFirestore.instance.collection('learning_resources').doc(resourceId).set({
        'title': title,
        'description': _descriptionController.text.trim(),
        'downloadUrl': resourceUrl,
        'source': 'external_link',
        'ownerId': user.uid,
        'ownerName': user.displayName ?? user.email ?? 'Teacher',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _titleController.clear();
      _descriptionController.clear();
      _resourceUrlController.clear();
      _showMessage('Resource link saved successfully.');
    } on FirebaseException catch (error) {
      if (mounted) _showMessage('Could not save resource (${error.code}).');
    } catch (_) {
      if (mounted) _showMessage('Could not save resource.');
    }
  }

  Future<void> _deleteResource(QueryDocumentSnapshot<Map<String, dynamic>> document) async {
    final data = document.data();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete resource?'),
        content: Text('Remove "${data['title'] ?? data['fileName'] ?? 'this resource'}" from learning materials?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await document.reference.delete();
      if (mounted) _showMessage('Resource deleted.');
    } catch (error) {
      if (mounted) _showMessage('Delete failed: $error');
    }
  }

  Future<void> _openResource(String? url) async {
    if (url == null || !await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      _showMessage('Unable to open this resource.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final resources = FirebaseFirestore.instance
        .collection('learning_resources')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: Text(widget.canUpload ? 'Manage Resources' : 'Learning Materials')),
      floatingActionButton: widget.canUpload
          ? FloatingActionButton.extended(
              onPressed: _showUploadSheet,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload'),
            )
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: resources,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load learning resources.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final documents = snapshot.data?.docs ?? const [];
          if (documents.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No learning resources have been uploaded yet.', textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: documents.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _ResourceTile(
              data: documents[index].data(),
              canEdit: widget.canManage,
              canDelete: widget.canDelete,
              onOpen: () => _openResource(documents[index].data()['downloadUrl'] as String?),
              onEdit: () => _editResource(documents[index]),
              onDelete: () => _deleteResource(documents[index]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _editResource(QueryDocumentSnapshot<Map<String, dynamic>> document) async {
    final data = document.data();
    final titleController = TextEditingController(text: data['title'] as String? ?? '');
    final descriptionController = TextEditingController(text: data['description'] as String? ?? '');
    final urlController = TextEditingController(text: data['downloadUrl'] as String? ?? '');

    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit resource'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Document link', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final url = urlController.text.trim();
              final parsedUrl = Uri.tryParse(url);
              if (title.isEmpty || parsedUrl?.hasScheme != true || parsedUrl?.host.isEmpty != false) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a title and complete https:// document link.')),
                );
                return;
              }
              try {
                await document.reference.update({
                  'title': title,
                  'description': descriptionController.text.trim(),
                  'downloadUrl': url,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                if (mounted) _showMessage('Resource updated successfully.');
              } on FirebaseException catch (error) {
                if (mounted) _showMessage('Could not update resource (${error.code}).');
              }
            },
            child: const Text('Save changes'),
          ),
        ],
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
    urlController.dispose();
    if (updated == true && mounted) setState(() {});
  }

  Future<void> _showUploadSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: StatefulBuilder(
          builder: (context, setSheetState) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Upload learning resource', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: _descriptionController, maxLines: 2, decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                  controller: _resourceUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Google Drive / OneDrive document link *',
                    hintText: 'https://...',
                    prefixIcon: Icon(Icons.link),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    await _upload();
                    if (!context.mounted) return;
                    if (_resourceUrlController.text.isEmpty) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Save resource link'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.data,
    required this.canEdit,
    required this.canDelete,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> data;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final extension = (data['fileExtension'] as String?)?.toUpperCase();
    return Card(
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE0E7FF),
          child: Text(extension?.isNotEmpty == true ? extension! : 'FILE', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
        ),
        title: Text(data['title'] as String? ?? data['fileName'] as String? ?? 'Untitled resource'),
        subtitle: Text(data['description'] as String? ?? data['fileName'] as String? ?? 'Learning material'),
        onTap: onOpen,
        trailing: (canEdit || canDelete)
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canEdit)
                    IconButton(tooltip: 'Edit resource', onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
                  if (canDelete)
                    IconButton(tooltip: 'Delete resource', onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
                ],
              )
            : const Icon(Icons.open_in_new),
      ),
    );
  }
}
