import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models.dart';
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
          final prefs = me?.preferences ?? const UserPreferences();
          final enabled = prefs.notificationsEnabled;
          final paymentRoundsEnabled = prefs.paymentRoundNotificationsEnabled;
          final boetesEnabled = prefs.boeteNotificationsEnabled;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pushmeldingen', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: enabled,
                      onChanged: (v) async {
                        try {
                          await UserService.setNotifications(user.uid, v);
                          final gid = groupId;
                          await NotificationsService.sync(uid: user.uid, groupId: gid);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      },
                      title: const Text('Ingeschakeld'),
                    ),
                    const Divider(height: 1, color: AppTheme.cardStroke),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: paymentRoundsEnabled,
                      onChanged: !enabled
                          ? null
                          : (v) async {
                              try {
                                await UserService.setPaymentRoundNotifications(user.uid, v);
                                final gid = groupId;
                                await NotificationsService.sync(uid: user.uid, groupId: gid);
                                if (!v && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Meldingen voor betaalrondes uitgeschakeld.')),
                                  );
                                }
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            },
                      title: const Text('Betaalronde gestart'),
                      subtitle: Text(
                        groupId == null ? 'Selecteer eerst een BoetePot.' : 'Ontvang een melding als een betaalronde start.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.cardStroke),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: boetesEnabled,
                      onChanged: !enabled
                          ? null
                          : (v) async {
                              try {
                                await UserService.setBoeteNotifications(user.uid, v);
                                final gid = groupId;
                                await NotificationsService.sync(uid: user.uid, groupId: gid);
                                if (!v && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Meldingen voor boetes uitgeschakeld.')),
                                  );
                                }
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            },
                      title: const Text('Boete gekregen'),
                      subtitle: Text(
                        'Ontvang een melding als je een boete krijgt.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                      ),
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
