import 'dart:typed_data';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.user, required this.firebaseReady});

  final User user;
  final bool firebaseReady;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  bool _isSaving = false;
  String? _photoUrl;
  XFile? _pickedImage;
  Uint8List? _pickedBytes;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.user.displayName ?? '');
    _bioController = TextEditingController();
    if (widget.firebaseReady) {
      _loadProfile();
    }
    _photoUrl = widget.user.photoURL;
  }

  Future<void> _loadProfile() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).get();
    final data = doc.data();
    if (data != null) {
      _displayNameController.text = (data['displayName'] as String?) ?? _displayNameController.text;
      _bioController.text = (data['bio'] as String?) ?? '';
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!widget.firebaseReady) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firebase not configured')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final profileRef = FirebaseFirestore.instance.collection('users').doc(widget.user.uid);
      final payload = {
        'displayName': _displayNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      };
      await profileRef.set(payload, SetOptions(merge: true));

      // Update FirebaseAuth displayName as well
      await widget.user.updateDisplayName(_displayNameController.text.trim());
      await widget.user.reload();

      // If a new image was picked, process (center-crop & resize) then upload it and save URL
      if (_pickedBytes != null) {
        final processed = _processImage(_pickedBytes!);
        final ref = FirebaseStorage.instance.ref().child('avatars/${widget.user.uid}.jpg');
        await ref.putData(processed, SettableMetadata(contentType: 'image/jpeg'));
        final url = await ref.getDownloadURL();
        await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).set({
          'photoURL': url,
        }, SetOptions(merge: true));
        await widget.user.updatePhotoURL(url);
        await widget.user.reload();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImage = picked;
        _pickedBytes = bytes;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image pick failed: $e')));
    }
  }

  // Process image bytes: center-crop to square and resize to 512px
  Uint8List _processImage(Uint8List input) {
    try {
      final original = img.decodeImage(input);
      if (original == null) return input;
      final w = original.width;
      final h = original.height;
      final side = min(w, h);
      final x = ((w - side) / 2).round();
      final y = ((h - side) / 2).round();
      final cropped = img.copyCrop(original, x: x, y: y, width: side, height: side);
      final resized = img.copyResize(cropped, width: 512, height: 512, interpolation: img.Interpolation.cubic);
      final jpg = img.encodeJpg(resized, quality: 85);
      return Uint8List.fromList(jpg);
    } catch (_) {
      return input;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile photo
              CircleAvatar(
                radius: 44,
                backgroundImage: _pickedBytes != null
                    ? MemoryImage(_pickedBytes!)
                    : (_photoUrl != null ? NetworkImage(_photoUrl!) as ImageProvider : null),
                child: _pickedBytes == null && _photoUrl == null ? const Icon(Icons.person, size: 44) : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton(
                    onPressed: _pickImage,
                    child: const Text('Change photo'),
                  ),
                  const SizedBox(width: 12),
                  if (_pickedImage != null)
                    Text('Image selected', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(labelText: 'Display name', border: OutlineInputBorder()),
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Enter a display name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Bio (optional)', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: Text(_isSaving ? 'Saving...' : 'Save profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
