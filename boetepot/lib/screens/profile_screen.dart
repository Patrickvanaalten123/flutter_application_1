import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:boetepot/services/storage_service.dart';
import 'package:boetepot/services/user_service.dart';
import '../ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _pickAndUpload() async {
    setState(() {
      _busy = true;
      _error = null;
    });
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
        final displayName = me?.displayName ?? user.displayName ?? (user.email ?? '');
        final email = user.email ?? '';
        final photoUrl = me?.photoURL;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            AppCard(
              child: Row(
                children: [
                  if (photoUrl != null && photoUrl.isNotEmpty)
                    CircleAvatar(
                      radius: 32,
                      backgroundImage: CachedNetworkImageProvider(photoUrl),
                    )
                  else
                    AvatarCircle(title: displayName.isNotEmpty ? displayName : email, size: 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(email, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profiel', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : _pickAndUpload,
                    icon: const Icon(Icons.photo),
                    label: Text(_busy ? 'Uploading…' : 'Kies foto'),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('App info', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Image.asset('boetepot/assets/images/RKHVV.png', width: 44, height: 44, fit: BoxFit.cover),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'BoetePot app\nRKHVV',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
