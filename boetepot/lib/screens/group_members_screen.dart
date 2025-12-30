import 'package:flutter/material.dart';
import '../services/group_service.dart';
import '../models.dart';

class GroupMembersScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  const GroupMembersScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  final _svc = GroupService();
  List<AppUser> _members = [];
  Map<String, String> _roles = {};
  final _newMembersText = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _svc.watchGroupMembers(widget.groupId).listen((data) {
      setState(() {
        _members = data.members;
        _roles = data.roles;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Members – ${widget.groupName}'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _newMembersText,
                  decoration: const InputDecoration(
                    labelText: 'Emails (comma-separated)',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        final emails = _newMembersText.text
                            .split(',')
                            .map((e) => e.trim().toLowerCase())
                            .where((e) => e.isNotEmpty)
                            .toList();
                        try {
                          await _svc.addMembers(widget.groupId, emails);
                          setState(() {
                            _newMembersText.clear();
                            _error = null;
                          });
                        } catch (e) {
                          setState(() => _error = e.toString());
                        }
                      },
                      child: const Text('Add'),
                    )
                  ],
                ),
                if (_error != null) Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
          const Divider(),
          ..._members.map((u) {
            final role = _roles[u.id] ?? 'member';
            return ListTile(
              title: Text(u.displayName?.isNotEmpty == true ? u.displayName! : u.email),
              subtitle: Text('${u.email} • $role'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'admin' || v == 'boeteAssigner' || v == 'member') {
                    await _svc.setRole(widget.groupId, u.id, v);
                  } else if (v == 'remove') {
                    await _svc.removeMember(widget.groupId, u.id);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'admin', child: Text('Make Admin')),
                  PopupMenuItem(value: 'boeteAssigner', child: Text('Make BoeteAssigner')),
                  PopupMenuItem(value: 'member', child: Text('Make Member')),
                  PopupMenuItem(value: 'remove', child: Text('Remove')),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}