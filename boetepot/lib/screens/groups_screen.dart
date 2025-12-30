import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/group_service.dart';
import '../models.dart';

class GroupsScreen extends StatelessWidget {
  final void Function(String id, String name) onSelect;
  const GroupsScreen({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final service = GroupService();

    return StreamBuilder<List<BoetePotGroup>>(
      stream: service.watchGroupsFor(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('No groups yet.'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final g = items[i];
            return ListTile(
              leading: const Icon(Icons.folder),
              title: Text(g.name),
              subtitle: Text('${g.members.length} members'),
              onTap: () => onSelect(g.id, g.name),
            );
          },
        );
      },
    );
  }
}