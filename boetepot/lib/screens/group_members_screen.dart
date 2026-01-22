import 'package:flutter/material.dart';
import '../services/group_service.dart';
import '../models.dart';

class GroupMembersScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final VoidCallback? onDeleted;
  const GroupMembersScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.onDeleted,
  });

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  final _svc = GroupService();
  List<AppUser> _members = [];
  Map<String, String> _roles = {};
  final _newMembersText = TextEditingController();
  String? _error;
  bool _busy = false;
  String? _notice;

  Future<void> _confirmDeleteGroup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('BoetePot verwijderen'),
        content: Text(
          'Weet je zeker dat je "${widget.groupName}" wilt verwijderen?\n\n'
          'Dit verwijdert ook boetes, sjablonen en betaalrondes van deze BoetePot.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuleren')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      setState(() {
        _busy = true;
        _error = null;
        _notice = null;
      });
      await _svc.deleteGroup(widget.groupId);
      if (!mounted) return;
      widget.onDeleted?.call();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('BoetePot verwijderd.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

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
        title: Text('Leden – ${widget.groupName}'),
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
                    labelText: 'E-mails (komma-gescheiden)',
                    helperText: 'Alleen bestaande accounts kunnen toegevoegd worden.',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Spacer(),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () async {
                        final emails = _newMembersText.text
                            .split(',')
                            .map((e) => e.trim().toLowerCase())
                            .where((e) => e.isNotEmpty)
                            .toList();
                        if (emails.isEmpty) return;
                        try {
                          setState(() {
                            _busy = true;
                            _error = null;
                            _notice = null;
                          });
                          final requested = emails.toSet().toList();
                          final blocked = await _svc.addMembers(widget.groupId, requested);
                          final addedCount = (requested.length - blocked.length).clamp(0, 9999);
                          setState(() {
                            if (blocked.isEmpty) {
                              _newMembersText.clear();
                              _notice = 'Toegevoegd: $addedCount';
                            } else {
                              _newMembersText.text = blocked.join(', ');
                              _notice = 'Toegevoegd: $addedCount • Niet gevonden: ${blocked.join(', ')}';
                            }
                            _error = null;
                            _busy = false;
                          });
                        } catch (e) {
                          setState(() {
                            _busy = false;
                            _error = e.toString();
                          });
                        }
                      },
                      child: Text(_busy ? 'Toevoegen…' : 'Toevoegen'),
                    )
                  ],
                ),
                if (_notice != null) Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_notice!, style: const TextStyle(color: Colors.orange)),
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
            final roleLabel = role == 'admin'
                ? 'admin'
                : role == 'boeteAssigner'
                    ? 'boete-uitdeler'
                    : 'lid';
            return ListTile(
              title: Text(u.displayName?.isNotEmpty == true ? u.displayName! : u.email),
              subtitle: Text('${u.email} • $roleLabel'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  try {
                    setState(() => _error = null);
                    if (v == 'admin' || v == 'boeteAssigner' || v == 'member') {
                      await _svc.setRole(widget.groupId, u.id, v);
                    } else if (v == 'remove') {
                      await _svc.removeMember(widget.groupId, u.id);
                    }
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _error = e.toString());
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'admin', child: Text('Maak admin')),
                  PopupMenuItem(value: 'boeteAssigner', child: Text('Maak boete-uitdeler')),
                  PopupMenuItem(value: 'member', child: Text('Maak lid')),
                  PopupMenuItem(value: 'remove', child: Text('Verwijderen')),
                ],
              ),
            );
          }),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            child: FilledButton.icon(
              onPressed: _busy ? null : _confirmDeleteGroup,
              icon: const Icon(Icons.delete_forever),
              label: const Text('BoetePot verwijderen'),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
