import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/payment_round_service.dart';
import '../models.dart';
import '../ui.dart';

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
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        return Stack(
          children: [
            StreamBuilder<List<PaymentRound>>(
              stream: _service.watchRounds(widget.groupId),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final rounds = snap.data!;

                // On phones: show list only and push to detail page to avoid extreme wrapping.
                if (isCompact) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Betalingen',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            if (widget.isAdminHere)
                              FilledButton.icon(
                                onPressed: _showCreateRoundDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Start ronde'),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                          itemCount: rounds.length,
                          itemBuilder: (_, i) {
                            final r = rounds[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => _PaymentRoundDetailPage(
                                        round: r,
                                        currentUid: widget.currentUid,
                                        isAdminHere: widget.isAdminHere,
                                      ),
                                    ),
                                  );
                                },
                                child: AppCard(
                                  radius: 22,
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: AppTheme.cardFill,
                                        child: const Icon(Icons.calendar_today, size: 16, color: AppTheme.gold),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    r.note?.isNotEmpty == true ? r.note! : _monthYear(r.asOf.toDate()),
                                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                          color: AppTheme.textPrimary,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                StatusPill(status: r.status),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              't/m ${_fmtDate(r.asOf.toDate())}',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                                            ),
                                            Text(
                                              'Aangemaakt ${_fmtDate(r.createdAt.toDate())}',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }

                // On wider screens/tablets: keep split view.
                if (_selectedRound == null && rounds.isNotEmpty) {
                  Future.microtask(() => setState(() => _selectedRound = rounds.first));
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Betalingen',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          if (widget.isAdminHere)
                            FilledButton.icon(
                              onPressed: _showCreateRoundDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Start ronde'),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 6, 8, 90),
                              itemCount: rounds.length,
                              itemBuilder: (_, i) {
                                final r = rounds[i];
                                final selected = _selectedRound?.id == r.id || (_selectedRound == null && i == 0);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () => setState(() => _selectedRound = r),
                                    child: AppCard(
                                      radius: 22,
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: AppTheme.cardFill,
                                            child: const Icon(Icons.calendar_today, size: 16, color: AppTheme.gold),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        r.note?.isNotEmpty == true ? r.note! : _monthYear(r.asOf.toDate()),
                                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                              color: AppTheme.textPrimary,
                                                              fontWeight: FontWeight.w700,
                                                            ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    StatusPill(status: r.status),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  't/m ${_fmtDate(r.asOf.toDate())}',
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                                                ),
                                                Text(
                                                  'Aangemaakt ${_fmtDate(r.createdAt.toDate())}',
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (selected) const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Container(width: 1, color: AppTheme.cardStroke),
                          Expanded(
                            flex: 3,
                            child: _selectedRound == null
                                ? const Center(child: Text('Selecteer een ronde', style: TextStyle(color: AppTheme.textSecondary)))
                                : _PaymentsList(
                                    round: _selectedRound!,
                                    currentUid: widget.currentUid,
                                    isAdminHere: widget.isAdminHere,
                                    onToggleStatus: (isOpen) async {
                                      final previous = _selectedRound!.status;
                                      setState(() => _selectedRound = _selectedRound!.copyWith(status: isOpen ? 'open' : 'closed'));
                                      try {
                                        await _service.setRoundStatus(roundId: _selectedRound!.id, isOpen: isOpen);
                                      } catch (e) {
                                        setState(() => _selectedRound = _selectedRound!.copyWith(status: previous));
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Kan ronde status niet wijzigen: $e')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            if (_loading)
              const Positioned(
                top: 12,
                right: 12,
                child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            if (_error != null)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.textPrimary))),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 18),
                        onPressed: () => setState(() => _error = null),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _fmtDate(DateTime dt) => '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
  String _monthYear(DateTime d) {
    const months = [
      'januari',
      'februari',
      'maart',
      'april',
      'mei',
      'juni',
      'juli',
      'augustus',
      'september',
      'oktober',
      'november',
      'december'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  Future<void> _showCreateRoundDialog() async {
    DateTime asOf = DateTime.now();
    bool includeZero = false;
    final note = TextEditingController();
    String? error;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            left: 12,
            right: 12,
            top: 12,
          ),
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nieuwe betalingsronde', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('T/m datum', style: TextStyle(color: AppTheme.textPrimary)),
                    subtitle: Text(_fmtDate(asOf), style: const TextStyle(color: AppTheme.textSecondary)),
                    trailing: IconButton(
                      icon: const Icon(Icons.date_range, color: AppTheme.textSecondary),
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
                    contentPadding: EdgeInsets.zero,
                    value: includeZero,
                    onChanged: (v) => setState(() => includeZero = v),
                    title: const Text('Leden met €0 meenemen', style: TextStyle(color: AppTheme.textPrimary)),
                  ),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(labelText: 'Notitie (optioneel)'),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(error!, style: const TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      const SizedBox(width: 6),
                      FilledButton(
                        onPressed: () async {
                          try {
                            setState(() => error = null);
                            setState(() => _loading = true);
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
                          } finally {
                            if (mounted) setState(() => _loading = false);
                          }
                        },
                        child: const Text('Aanmaken'),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }
}

class _PaymentRoundDetailPage extends StatelessWidget {
  const _PaymentRoundDetailPage({
    required this.round,
    required this.currentUid,
    required this.isAdminHere,
  });

  final PaymentRound round;
  final String currentUid;
  final bool isAdminHere;

  @override
  Widget build(BuildContext context) {
    return _PaymentRoundDetailPageInner(
      round: round,
      currentUid: currentUid,
      isAdminHere: isAdminHere,
    );
  }
}

class _PaymentRoundDetailPageInner extends StatefulWidget {
  const _PaymentRoundDetailPageInner({
    required this.round,
    required this.currentUid,
    required this.isAdminHere,
  });

  final PaymentRound round;
  final String currentUid;
  final bool isAdminHere;

  @override
  State<_PaymentRoundDetailPageInner> createState() => _PaymentRoundDetailPageInnerState();
}

class _PaymentRoundDetailPageInnerState extends State<_PaymentRoundDetailPageInner> {
  final _service = PaymentRoundService();
  late PaymentRound _round = widget.round;

  Future<void> _toggleStatus(bool isOpen) async {
    final previous = _round.status;
    setState(() => _round = _round.copyWith(status: isOpen ? 'open' : 'closed'));
    try {
      await _service.setRoundStatus(roundId: _round.id, isOpen: isOpen);
    } catch (e) {
      setState(() => _round = _round.copyWith(status: previous));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kan ronde status niet wijzigen: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.cardFill,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.cardStroke, width: 1),
                        ),
                        child: const Icon(Icons.chevron_left, color: AppTheme.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Betalingsronde',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    StatusPill(status: _round.status),
                  ],
                ),
              ),
              Expanded(
                child: _PaymentsList(
                  round: _round,
                  currentUid: widget.currentUid,
                  isAdminHere: widget.isAdminHere,
                  onToggleStatus: _toggleStatus,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentsList extends StatelessWidget {
  final PaymentRound round;
  final String currentUid;
  final bool isAdminHere;
  final ValueChanged<bool> onToggleStatus;

  const _PaymentsList({
    required this.round,
    required this.currentUid,
    required this.isAdminHere,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final service = PaymentRoundService();
    final isOpen = round.status == 'open';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                round.note?.isNotEmpty == true ? round.note! : 'Ronde t/m ${_fmtDate(round.asOf.toDate())}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (isAdminHere)
                Switch(
                  value: isOpen,
                  onChanged: (v) => onToggleStatus(v),
                  thumbColor: WidgetStatePropertyAll(AppTheme.gold),
                ),
              StatusPill(status: round.status),
            ],
          ),
          Text('T/m ${_fmtDate(round.asOf.toDate())}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<PaymentObligation>>(
              stream: service.watchPayments(round.id),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final items = snap.data!;
                if (items.isEmpty) return const Center(child: Text('Geen betalingen in deze ronde', style: TextStyle(color: AppTheme.textSecondary)));
                items.sort((a, b) => b.amount.compareTo(a.amount));
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final p = items[i];
                    return AppCard(
                      child: Row(
                        children: [
                          AvatarCircle(title: p.displayName ?? p.email ?? p.uid),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.displayName?.isNotEmpty == true ? p.displayName! : (p.email ?? p.uid),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  p.paid ? 'Betaald' : 'Open',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: p.paid ? Colors.greenAccent : AppTheme.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('€${p.amount.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                              if (p.paidAt != null)
                                Text(
                                  'op ${_fmtDate(p.paidAt!.toDate())}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                              if (isAdminHere)
                                Switch(
                                  value: p.paid,
                                  onChanged: isOpen
                                      ? (v) => service.markPaid(roundId: round.id, uid: p.uid, paid: v, markerUid: currentUid)
                                      : null,
                                  thumbColor: WidgetStatePropertyAll(AppTheme.gold),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) => '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
}
