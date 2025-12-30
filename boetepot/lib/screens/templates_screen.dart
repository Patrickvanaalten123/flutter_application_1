import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/templates_service.dart';
import '../models.dart';
import 'add_from_templates_screen.dart';

class TemplatesScreen extends StatefulWidget {
  final String groupId;
  final bool isAdmin;
  final List<AppUser> currentMembers; // optional for "Add from templates" member picker

  const TemplatesScreen({
    super.key,
    required this.groupId,
    required this.isAdmin,
    required this.currentMembers,
  });

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final _service = TemplatesService();

  @override
  Widget build(BuildContext context) {
    final meEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Templates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Add from templates',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AddFromTemplatesScreen(groupId: widget.groupId, members: widget.currentMembers),
              ));
            },
          ),
        ],
      ),
      body: StreamBuilder<List<BoeteTemplate>>(
        stream: _service.watchTemplates(widget.groupId),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) return const Center(child: Text('No templates yet.'));
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final t = items[i];
              return ListTile(
                title: Text(t.title),
                subtitle: Text('${t.description}\n€${t.amount.toStringAsFixed(2)}'),
                isThreeLine: true,
                trailing: widget.isAdmin
                    ? PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'deactivate') await _service.deactivateTemplate(t);
                          if (v == 'delete') await _service.deleteTemplate(t);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      )
                    : null,
              );
            },
          );
        },
      ),
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context, meEmail),
              label: const Text('New Template'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _showCreateDialog(BuildContext context, String meEmail) async {
    final title = TextEditingController();
    final desc = TextEditingController();
    final amount = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create template'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')),
              TextField(
                controller: amount,
                decoration: const InputDecoration(labelText: 'Amount (€)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              if (error != null) Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final t = title.text.trim();
                final d = desc.text.trim();
                final a = double.tryParse(amount.text.replaceAll(',', '.'));
                if (t.isEmpty || d.isEmpty || a == null) {
                  setState(() => error = 'Please fill all fields with a valid amount.');
                  return;
                }
                await _service.createTemplate(
                  groupId: widget.groupId,
                  title: t,
                  description: d,
                  amount: a,
                  createdBy: meEmail,
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}