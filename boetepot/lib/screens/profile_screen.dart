import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:boetepot/services/storage_service.dart';
import 'package:boetepot/services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _pickAndUpload() async {
    setState(() { _busy = true; _error = null; });
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final url = await StorageService.uploadProfileJpeg(uid, bytes);
      await UserService.setPhotoURL(uid, url);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return StreamBuilder(
      stream: UserService.watchMe(user.uid),
      builder: (context, snap) {
        final me = snap.data;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (me?.photoURL != null && me!.photoURL!.isNotEmpty)
                CircleAvatar(
                  radius: 40,
                  backgroundImage: CachedNetworkImageProvider(me.photoURL!),
                )
              else
                CircleAvatar(
                  radius: 40,
                  child: Text((user.email ?? 'U').substring(0, 1).toUpperCase()),
                ),
              const SizedBox(height: 12),
              Text(me?.displayName ?? user.displayName ?? (user.email ?? '')),
              Text(user.email ?? '', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _pickAndUpload,
                icon: const Icon(Icons.photo),
                label: Text(_busy ? 'Uploading…' : 'Choose Photo'),
              ),
            ],
          ),
        );
      },
    );
  }
}