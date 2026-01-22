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
  List<BoeteTemplate> _latestTemplates = const [];
  late final Stream<List<BoeteTemplate>> _templatesStream;

  @override
  void initState() {
    super.initState();
    if (widget.members.isNotEmpty) {
      _selectedUid = widget.members.first.id;
    }
    _templatesStream = _service.watchTemplates(widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    final meEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    final meUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Toevoegen uit sjablonen')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text('Toewijzen aan:'),
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
              stream: _templatesStream,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Kon sjablonen niet laden:\n${snap.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final items = snap.data!;
                    _latestTemplates = items;
                    if (items.isEmpty) return const Center(child: Text('Geen sjablonen'));
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
                          if (v == true) {
                            _selectedTemplateIds.add(t.id);
                          } else {
                            _selectedTemplateIds.remove(t.id);
                          }
                        });
                      }),
                      onTap: () {
                        setState(() {
                          if (checked) {
                            _selectedTemplateIds.remove(t.id);
                          } else {
                            _selectedTemplateIds.add(t.id);
                          }
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
              label: const Text('Geselecteerde toevoegen'),
              onPressed: () async {
                final meEmailNow = meEmail;
                if (_selectedUid == null) {
                  setState(() => _error = 'Selecteer een lid');
                  return;
                }
                if (_selectedTemplateIds.isEmpty) {
                  setState(() => _error = 'Selecteer minimaal één sjabloon');
                  return;
                }
                final assignee = widget.members.firstWhere((u) => u.id == _selectedUid, orElse: () => AppUser(id: _selectedUid!, email: _selectedUid!));
                try {
                  final templates = _latestTemplates.isNotEmpty ? _latestTemplates : await _service.fetchTemplatesOnce(widget.groupId);
                  final chosen = templates.where((t) => _selectedTemplateIds.contains(t.id)).toList();
                  if (chosen.isEmpty) {
                    setState(() => _error = 'Geen sjablonen geselecteerd');
                    return;
                  }
                  await _service.addBoetesFromTemplates(
                    templates: chosen,
                    assignedToUid: _selectedUid!,
                    assignedToEmail: assignee.email,
                    groupId: widget.groupId,
                    createdByEmail: meEmailNow,
                    createdByUid: meUid,
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
