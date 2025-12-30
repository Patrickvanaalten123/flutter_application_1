import 'package:flutter/material.dart';
import '../services/boete_service.dart';
import '../models.dart';
import 'templates_screen.dart';

class BoetesScreen extends StatelessWidget {
  final String? groupId;
  final String? groupName;
  final String currentUserEmail;
  final String currentUid;
  final bool isAdminHere;

  const BoetesScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.currentUserEmail,
    required this.currentUid,
    this.isAdminHere = false,
  });

  @override
  Widget build(BuildContext context) {
    if (groupId == null) {
      return const Center(child: Text('Select a group first.'));
    }
    final service = BoeteService();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: Container(), // keep app bar in HomeShell
      ),
      body: StreamBuilder<List<Boete>>(
        stream: service.watchBoetes(groupId!),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) return const Center(child: Text('Nog geen boetes.'));
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final b = items[i];
              return ListTile(
                title: Text(b.title),
                subtitle: Text('${b.description}\n${_formatDate(b.dateAdded)}'),
                isThreeLine: true,
                trailing: Text('€${b.amount.toStringAsFixed(2)}'),
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAdminHere)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: FloatingActionButton.extended(
                heroTag: 'fabTemplates',
                label: const Text('Templates'),
                icon: const Icon(Icons.library_books),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TemplatesScreen(groupId: groupId!, isAdmin: isAdminHere, currentMembers: const []),
                  ));
                },
              ),
            ),
          FloatingActionButton.extended(
            heroTag: 'fabAddBoete',
            onPressed: () async {
              await _showAddBoeteDialog(context, service);
            },
            label: const Text('Add Boete'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showAddBoeteDialog(BuildContext context, BoeteService service) async {
    final title = TextEditingController();
    final desc = TextEditingController();
    final amount = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Add Boete ${groupName != null ? '– $groupName' : ''}'),
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
                  padding: const EdgeInsets.only(top: 8.0),
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
                  await service.addBoete(
                    title: t,
                    description: d,
                    amount: a,
                    userEmail: currentUserEmail,
                    groupId: groupId!,
                    assignedToUid: currentUid, // assign to self for now
                    assignedToEmail: currentUserEmail,
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }
}