import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/notifications_service.dart';
import '../services/user_service.dart';
import '../ui.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.groupId});

  final String? groupId;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      appBar: AppBar(title: const Text('Meldingen')),
      body: StreamBuilder(
        stream: UserService.watchMe(user.uid),
        builder: (context, snap) {
          final me = snap.data;
          final enabled = me?.preferences.notificationsEnabled ?? true;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pushmeldingen', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      'Ontvang een melding als een betaalronde start.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: enabled,
                      onChanged: (v) async {
                        await UserService.setNotifications(user.uid, v);
                        if (!v) {
                          await NotificationsService.unsubscribeCurrentTopic();
                          return;
                        }
                        final gid = groupId;
                        if (gid == null) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Selecteer eerst een BoetePot om meldingen te activeren.')),
                          );
                          return;
                        }
                        await NotificationsService.syncForGroup(uid: user.uid, groupId: gid);
                      },
                      title: const Text('Ingeschakeld'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

