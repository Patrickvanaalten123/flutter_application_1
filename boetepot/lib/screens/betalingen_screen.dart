import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/payment_round_service.dart';
import '../models.dart';

class BetalingenScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String currentUid;
  final bool isAdminHere;

  const BetalingenScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.currentUid,
    required this.isAdminHere,
  });

  @override
  State<BetalingenScreen> createState() => _BetalingenScreenState();
}

class _BetalingenScreenState extends State<BetalingenScreen> {
  final _service = PaymentRoundService();
  PaymentRound? _selectedRound;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left: rounds list
        Expanded(
          flex: 2,
          child: StreamBuilder<List<PaymentRound>>(
            stream: _service.watchRounds(widget.groupId),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final rounds = snap.data!;
              return Scaffold(
                body: ListView.separated(
                  itemCount: rounds.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = rounds[i];
                    final isOpen = r.status == 'open';
                    return ListTile(
                      title: Text('As of: ${_fmtDate(r.asOf.toDate())}'),
                      subtitle: Text(r.note?.isNotEmpty == true ? r.note! : (isOpen ? 'Open' : 'Closed')),
                      trailing: Icon(isOpen ? Icons.lock_open : Icons.lock, color: isOpen ? Colors.green : Colors.red),
                      selected: _selectedRound?.id == r.id,
                      onTap: () => setState(() => _selectedRound = r),
                      onLongPress: widget.isAdminHere ? () async {
                        final newOpen = !(r.status == 'open');
                        await _service.setRoundStatus(roundId: r.id, isOpen: newOpen);
                      } : null,
                    );
                  },
                ),
                floatingActionButton: widget.isAdminHere ? FloatingActionButton.extended(
                  onPressed: () => _showCreateRoundDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Start round'),
                ) : null,
              );
            },
          ),
        ),
        const VerticalDivider(width: 1),
        // Right: payments for selected round
        Expanded(
          flex: 3,
          child: _selectedRound == null
              ? const Center(child: Text('Select a round'))
              : _PaymentsList(
                  round: _selectedRound!,
                  currentUid: widget.currentUid,
                ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime dt) => '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';

  Future<void> _showCreateRoundDialog(BuildContext context) async {
    DateTime asOf = DateTime.now();
    bool includeZero = false;
    final note = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Start betalingsronde'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('T/m datum'),
                subtitle: Text(_fmtDate(asOf)),
                trailing: IconButton(
                  icon: const Icon(Icons.date_range),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: asOf,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => asOf = DateTime(picked.year, picked.month, picked.day));
                  },
                ),
              ),
              SwitchListTile(
                value: includeZero,
                onChanged: (v) => setState(() => includeZero = v),
                title: const Text('Leden met €0 meenemen'),
              ),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Notitie (optioneel)'),
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
                try {
                  final me = FirebaseAuth.instance.currentUser!;
                  final round = await _service.createRound(
                    groupId: widget.groupId,
                    asOf: asOf,
                    note: note.text.trim().isEmpty ? null : note.text.trim(),
                    includeZeroMembers: includeZero,
                    currentUid: me.uid,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    setState(() => _selectedRound = round);
                  }
                } catch (e) {
                  setState(() => error = e.toString());
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentsList extends StatelessWidget {
  final PaymentRound round;
  final String currentUid;
  const _PaymentsList({required this.round, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    final service = PaymentRoundService();
    final isOpen = round.status == 'open';
    return StreamBuilder<List<PaymentObligation>>(
      stream: service.watchPayments(round.id),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final items = snap.data!;
        if (items.isEmpty) return const Center(child: Text('No obligations in this round.'));
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = items[i];
            return CheckboxListTile(
              title: Text(p.displayName?.isNotEmpty == true ? p.displayName! : (p.email ?? p.uid)),
              subtitle: Text('€${p.amount.toStringAsFixed(2)}'),
              value: p.paid,
              onChanged: isOpen ? (v) async {
                await service.markPaid(roundId: round.id, uid: p.uid, paid: v ?? false, markerUid: currentUid);
              } : null,
            );
          },
        );
      },
    );
  }
}