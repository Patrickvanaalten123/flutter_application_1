import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/templates_service.dart';
import '../models.dart';

class AddFromTemplatesScreen extends StatefulWidget {
  final String groupId;
  final List<AppUser> members;

  const AddFromTemplatesScreen({
    super.key,
    required this.groupId,
    required this.members,
  });

  @override
  State<AddFromTemplatesScreen> createState() => _AddFromTemplatesScreenState();
}

class _AddFromTemplatesScreenState extends State<AddFromTemplatesScreen> {
  final _service = TemplatesService();
  String? _selectedUid;
  final Set<String> _selectedTemplateIds = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.members.isNotEmpty) {
      _selectedUid = widget.members.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final meEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Add from templates')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text('Assign to:'),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedUid,
                    items: widget.members.map((u) {
                      final label = (u.displayName?.isNotEmpty == true) ? u.displayName! : u.email;
                      return DropdownMenuItem(value: u.id, child: Text(label));
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedUid = v),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<BoeteTemplate>>(
              stream: _service.watchTemplates(widget.groupId),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final items = snap.data!;
                if (items.isEmpty) return const Center(child: Text('No templates'));
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = items[i];
                    final checked = _selectedTemplateIds.contains(t.id);
                    return ListTile(
                      title: Text(t.title),
                      subtitle: Text('${t.description}\n€${t.amount.toStringAsFixed(2)}'),
                      isThreeLine: true,
                      trailing: Checkbox(value: checked, onChanged: (v) {
                        setState(() {
                          if (v == true) _selectedTemplateIds.add(t.id);
                          else _selectedTemplateIds.remove(t.id);
                        });
                      }),
                      onTap: () {
                        setState(() {
                          if (checked) _selectedTemplateIds.remove(t.id);
                          else _selectedTemplateIds.add(t.id);
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          if (_error != null) Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add selected'),
              onPressed: () async {
                final meEmailNow = meEmail;
                if (_selectedUid == null) {
                  setState(() => _error = 'Select a member');
                  return;
                }
                final templates = await _service.watchTemplates(widget.groupId).first;
                final chosen = templates.where((t) => _selectedTemplateIds.contains(t.id)).toList();
                final assignee = widget.members.firstWhere((u) => u.id == _selectedUid, orElse: () => AppUser(id: _selectedUid!, email: _selectedUid!));
                try {
                  await _service.addBoetesFromTemplates(
                    templates: chosen,
                    assignedToUid: _selectedUid!,
                    assignedToEmail: assignee.email,
                    groupId: widget.groupId,
                    createdByEmail: meEmailNow,
                  );
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  setState(() => _error = e.toString());
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}