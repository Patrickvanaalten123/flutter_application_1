import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:boetepot/services/storage_service.dart';
import 'package:boetepot/services/auth_service.dart';
import 'package:boetepot/services/user_service.dart';
import 'package:boetepot/screens/group_members_screen.dart';
import 'notifications_screen.dart';
import '../ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.roleLabel,
    required this.isAdminHere,
    required this.onPickGroup,
  });

  final String? groupId;
  final String? groupName;
  final String? roleLabel;
  final bool isAdminHere;
  final VoidCallback onPickGroup;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _openAccountSettingsSheet({
    required String initialDisplayName,
    required String initialEmail,
  }) async {
    final displayName = TextEditingController(text: initialDisplayName);
    final email = TextEditingController(text: initialEmail);
    final currentPasswordForEmail = TextEditingController();

    final currentPassword = TextEditingController();
    final newPassword = TextEditingController();
    final confirmNewPassword = TextEditingController();

    String? error;
    String? success;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppBottomSheet(
        childBuilder: (sheetContext, scrollController) {
          return StatefulBuilder(
            builder: (context, setState) {
              Future<void> run(Future<void> Function() fn) async {
                setState(() {
                  saving = true;
                  error = null;
                  success = null;
                });
                try {
                  await fn();
                  setState(() => success = 'Opgeslagen.');
                } catch (e) {
                  setState(() => error = e.toString());
                } finally {
                  setState(() => saving = false);
                }
              }

              final canChangePassword = currentPassword.text.isNotEmpty &&
                  newPassword.text.isNotEmpty &&
                  newPassword.text == confirmNewPassword.text &&
                  newPassword.text.length >= 6;

              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Profiel & Instellingen',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Profiel', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            setState(() {
                              saving = true;
                              error = null;
                              success = null;
                            });
                            try {
                              final didUpload = await _pickAndUpload();
                              if (didUpload) {
                                setState(() => success = 'Foto opgeslagen.');
                              }
                            } catch (e) {
                              setState(() => error = e.toString());
                            } finally {
                              setState(() => saving = false);
                            }
                          },
                    icon: const Icon(Icons.photo),
                    label: Text(saving ? 'Bezig…' : 'Wijzig foto'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: displayName,
                    decoration: const InputDecoration(labelText: 'Weergavenaam'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Spacer(),
                      FilledButton(
                        onPressed: saving
                            ? null
                            : () => run(() async {
                                  final name = displayName.text.trim();
                                  if (name.isEmpty) throw Exception('Naam is verplicht');
                                  await AuthService.updateDisplayName(name);
                                }),
                        child: const Text('Sla naam op'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('E-mail wijzigen', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: email,
                    decoration: const InputDecoration(labelText: 'E-mailadres'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: currentPasswordForEmail,
                    decoration: const InputDecoration(labelText: 'Huidig wachtwoord (verificatie)'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Spacer(),
                      FilledButton(
                        onPressed: saving
                            ? null
                            : () => run(() async {
                                  final newEmail = email.text.trim().toLowerCase();
                                  if (newEmail.isEmpty) throw Exception('E-mail is verplicht');
                                  if (currentPasswordForEmail.text.isEmpty) throw Exception('Wachtwoord is verplicht');
                                  await AuthService.updateEmail(
                                    newEmail: newEmail,
                                    currentPassword: currentPasswordForEmail.text,
                                  );
                                }),
                        child: const Text('E-mail bijwerken'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Wachtwoord wijzigen', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: currentPassword,
                    decoration: const InputDecoration(labelText: 'Huidig wachtwoord'),
                    obscureText: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newPassword,
                    decoration: const InputDecoration(labelText: 'Nieuw wachtwoord (min. 6 tekens)'),
                    obscureText: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmNewPassword,
                    decoration: const InputDecoration(labelText: 'Herhaal nieuw wachtwoord'),
                    obscureText: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Spacer(),
                      FilledButton(
                        onPressed: saving || !canChangePassword
                            ? null
                            : () => run(() async {
                                  await AuthService.updatePassword(
                                    currentPassword: currentPassword.text,
                                    newPassword: newPassword.text,
                                  );
                                  currentPassword.clear();
                                  newPassword.clear();
                                  confirmNewPassword.clear();
                                }),
                        child: const Text('Wachtwoord bijwerken'),
                      ),
                    ],
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                  if (success != null) ...[
                    const SizedBox(height: 12),
                    Text(success!, style: const TextStyle(color: Colors.greenAccent)),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<bool> _pickAndUpload() async {
    final picker = ImagePicker();
    // Keep the upload small enough for Storage rules and to avoid slow uploads.
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return false;
    final bytes = await file.readAsBytes();
    const maxBytes = 5 * 1024 * 1024; // keep in sync with Storage rules
    if (bytes.lengthInBytes >= maxBytes) {
      throw Exception('Foto is te groot (max 5MB). Kies een kleinere foto.');
    }
    final uid = FirebaseAuth.instance.currentUser!.uid;
    String url;
    try {
      url = await StorageService.uploadProfileJpeg(uid, bytes);
    } catch (e) {
      throw Exception('Uploaden naar Storage mislukt: $e');
    }
    try {
      await UserService.setPhotoURL(uid, url);
    } catch (e) {
      throw Exception('Opslaan van foto-URL in Firestore mislukt: $e');
    }
    return true;
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: [
            _profileCard(context, displayName: displayName, email: email, photoUrl: photoUrl),
            const SizedBox(height: 12),
            _groupCard(context),
            const SizedBox(height: 12),
            _menuCard(context),
            const SizedBox(height: 12),
            _logoutButton(context),
            const SizedBox(height: 12),
            _appInfoCard(context),
          ],
        );
      },
    );
  }

  Widget _profileCard(
    BuildContext context, {
    required String displayName,
    required String email,
    required String? photoUrl,
  }) {
    return GestureDetector(
      onTap: () => _openAccountSettingsSheet(
        initialDisplayName: displayName,
        initialEmail: email,
      ),
      child: AppCard(
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
                  Text(
                    displayName.isNotEmpty ? displayName : 'Profiel',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _groupCard(BuildContext context) {
    final hasGroup = widget.groupId != null && (widget.groupName?.isNotEmpty == true);
    final role = widget.roleLabel;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Jouw groep', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (!hasGroup)
            Row(
              children: [
                const Icon(Icons.folder, color: AppTheme.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Geen BoetePot geselecteerd',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                FilledButton(
                  onPressed: widget.onPickGroup,
                  child: const Text('Selecteer'),
                ),
              ],
            )
          else
            Row(
              children: [
                const Icon(Icons.folder, color: AppTheme.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.groupName ?? '—',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        role ?? '—',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (role != null) AppPill(text: role.toUpperCase(), color: role == 'admin' ? AppTheme.gold : null),
              ],
            ),
          if (hasGroup && widget.isAdminHere) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.cardStroke),
            const SizedBox(height: 6),
            _menuRow(
              context,
              icon: Icons.group,
              title: 'Groep beheren',
              onTap: () {
                final gid = widget.groupId!;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GroupMembersScreen(
                      groupId: gid,
                      groupName: widget.groupName ?? '',
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _menuCard(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          _menuRow(
            context,
            icon: Icons.settings,
            title: 'Instellingen',
            onTap: () {
              final user = FirebaseAuth.instance.currentUser!;
              _openAccountSettingsSheet(
                initialDisplayName: user.displayName ?? '',
                initialEmail: user.email ?? '',
              );
            },
          ),
          const Divider(height: 1, color: AppTheme.cardStroke),
          _menuRow(
            context,
            icon: Icons.notifications,
            title: 'Meldingen',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NotificationsScreen(groupId: widget.groupId),
                ),
              );
            },
          ),
          const Divider(height: 1, color: AppTheme.cardStroke),
          _menuRow(
            context,
            icon: Icons.privacy_tip,
            title: 'Privacybeleid',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Privacybeleid: nog te implementeren.')));
            },
          ),
        ],
      ),
    );
  }

  Widget _logoutButton(BuildContext context) {
    return FilledButton(
      onPressed: () async {
        await AuthService.signOut();
      },
      child: const Text('UITLOGGEN'),
    );
  }

  Widget _appInfoCard(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset('assets/images/RKHVV.png', width: 44, height: 44, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'BoetePot\nRKHVV',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const SizedBox(width: 2),
            Icon(icon, color: AppTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
