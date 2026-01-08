import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/templates_service.dart';
import '../models.dart';
import 'add_from_templates_screen.dart';
import '../ui.dart';

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
  late final Stream<List<BoeteTemplate>> _templatesStream;

  @override
  void initState() {
    super.initState();
    _templatesStream = widget.isAdmin ? _service.watchAllTemplates(widget.groupId) : _service.watchTemplates(widget.groupId);
  }

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
        stream: _templatesStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AppCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kon templates niet laden',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snap.error.toString(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final all = snap.data!;
          final items = widget.isAdmin ? all : all.where((t) => t.isActive).toList();
          if (items.isEmpty) return const Center(child: Text('No templates yet.'));

          final active = widget.isAdmin ? items.where((t) => t.isActive).toList() : items;
          final inactive = widget.isAdmin ? items.where((t) => !t.isActive).toList() : const <BoeteTemplate>[];

          return ListView(
            children: [
              if (widget.isAdmin && active.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Text('Actief', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ...active.map((t) => _templateTile(t)),
              if (widget.isAdmin && inactive.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text('Inactief', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                ...inactive.map((t) => _templateTile(t)),
              ],
              const SizedBox(height: 90),
            ],
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

  Widget _templateTile(BoeteTemplate t) {
    return ListTile(
      title: Text(t.title),
      subtitle: Text('${t.description}\n€${t.amount.toStringAsFixed(2)}'),
      isThreeLine: true,
      leading: widget.isAdmin
          ? Icon(
              t.isActive ? Icons.circle : Icons.circle_outlined,
              color: t.isActive ? Colors.greenAccent : AppTheme.textSecondary,
              size: 14,
            )
          : null,
      trailing: widget.isAdmin
          ? PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') {
                  await _showEditDialog(context, t);
                } else if (v == 'toggle') {
                  if (t.isActive) {
                    await _service.deactivateTemplate(t);
                  } else {
                    await _service.activateTemplate(t);
                  }
                } else if (v == 'delete') {
                  await _service.deleteTemplate(t);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Wijzig')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(t.isActive ? 'Deactiveer' : 'Activeer'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Verwijder')),
              ],
            )
          : null,
    );
  }

  Future<void> _showEditDialog(BuildContext context, BoeteTemplate tpl) async {
    final title = TextEditingController(text: tpl.title);
    final desc = TextEditingController(text: tpl.description);
    final amount = TextEditingController(text: tpl.amount.toStringAsFixed(2));
    String? error;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Template wijzigen'),
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
              if (error != null)
                Padding(
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
                  setState(() => error = 'Vul alle velden in met een geldig bedrag.');
                  return;
                }
                await _service.updateTemplate(
                  id: tpl.id,
                  groupId: tpl.groupId,
                  title: t,
                  description: d,
                  amount: a,
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Opslaan'),
            ),
          ],
        ),
      ),
    );
  }
}
