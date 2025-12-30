import 'package:flutter/material.dart';
import '../services/boete_service.dart';
import '../services/payment_round_service.dart';
import '../services/group_service.dart';
import 'templates_screen.dart';
import '../models.dart';
import '../ui.dart';

class BoetesScreen extends StatefulWidget {
  final String? groupId;
  final String? groupName;
  final String currentUserEmail;
  final String currentUid;
  final bool isAdminHere;
  final String? roleLabel;
  final List<AppUser> members;
  final VoidCallback? onRequestGroupPicker;
  final void Function(String id, String name)? onGroupCreated;

  const BoetesScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.currentUserEmail,
    required this.currentUid,
    this.isAdminHere = false,
    this.roleLabel,
    this.members = const [],
    this.onRequestGroupPicker,
    this.onGroupCreated,
  });

  @override
  State<BoetesScreen> createState() => _BoetesScreenState();
}

class _BoetesScreenState extends State<BoetesScreen> {
  final _boeteService = BoeteService();
  final _paymentService = PaymentRoundService();
  final _groupService = GroupService();

  Map<String, double> _paidTotals = {};
  bool _loadingTotals = false;

  @override
  void didUpdateWidget(covariant BoetesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) {
      _reloadPaidTotals();
    }
  }

  @override
  void initState() {
    super.initState();
    _reloadPaidTotals();
  }

  void _reloadPaidTotals() async {
    final gid = widget.groupId;
    if (gid == null) return;
    setState(() => _loadingTotals = true);
    final totals = await _paymentService.fetchTotalPaidForGroup(gid);
    if (mounted) {
      setState(() {
        _paidTotals = totals;
        _loadingTotals = false;
      });
    }
  }

  AppUser? _memberByUid(String? uid) {
    if (uid == null) return null;
    return widget.members.firstWhere(
      (m) => m.id == uid,
      orElse: () => AppUser(id: uid, email: ''),
    );
  }

  double _totalAmount(List<Boete> items) => items.fold(0, (s, b) => s + b.amount);

  double _myTotal(List<Boete> items) {
    return items.where((b) => b.assignedToUid == widget.currentUid).fold(0, (s, b) => s + b.amount);
  }

  double _myOutstanding(List<Boete> items) {
    final paid = _paidTotals[widget.currentUid] ?? 0;
    return (_myTotal(items) - paid).clamp(0, double.infinity);
  }

  double _outstanding(List<Boete> items) {
    final paidSum = _paidTotals.values.fold(0.0, (s, v) => s + v);
    return (_totalAmount(items) - paidSum).clamp(0, double.infinity);
  }

  double _fabBottomOffset(BuildContext context) => 80 + MediaQuery.of(context).padding.bottom;

  Widget _detailRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  List<(AppUser?, double)> _totalsPerUser(List<Boete> items) {
    final grouped = <String, double>{};
    for (final b in items) {
      grouped[b.assignedToUid] = (grouped[b.assignedToUid] ?? 0) + b.amount;
    }
    return grouped.entries
        .map((e) => (_memberByUid(e.key), e.value))
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupId == null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AppCard(
                radius: 22,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Geen BoetePot geselecteerd', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Kies een BoetePot of maak een nieuwe aan.', style: TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: widget.onRequestGroupPicker,
                          child: const Text('Kies BoetePot'),
                        ),
                        OutlinedButton(
                          onPressed: _showCreatePotSheet,
                          child: const Text('Nieuwe BoetePot'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: _fabBottomOffset(context),
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(color: AppTheme.gold.withAlpha(70), blurRadius: 18, spreadRadius: 2),
                ],
              ),
              child: GoldFab(
                icon: Icons.add,
                onPressed: _showCreatePotSheet,
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        StreamBuilder<List<Boete>>(
          stream: _boeteService.watchBoetes(groupId: widget.groupId),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snap.data!;
            return RefreshIndicator(
              onRefresh: () async {
                _reloadPaidTotals();
                await Future.delayed(const Duration(milliseconds: 200));
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.groupName ?? 'BoetePot',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _showCreatePotSheet,
                          icon: const Icon(Icons.add),
                          label: const Text('Nieuwe BoetePot'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _totalsCard(items),
                  const SizedBox(height: 8),
                  _myCard(items),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text(
                      'Boetes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AppCard(
                        child: Text('Nog geen boetes.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
                      ),
                    )
                  else
                    ...items.map((b) => _BoeteRow(
                          boete: b,
                          assignee: _memberByUid(b.assignedToUid),
                          onEdit: widget.isAdminHere ? () => _showEditDialog(b) : null,
                          onDelete: widget.isAdminHere ? () => _confirmDelete(b) : null,
                        )),
                  if (items.isNotEmpty) _totalsPerUserCard(items),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
        Positioned(
          right: 18,
          bottom: _fabBottomOffset(context),
          child: _FabMenu(
            canAdd: widget.isAdminHere,
            onAddBoete: _showAddBoeteDialog,
            onAddFromTemplates: _showAddFromTemplates,
            onCreatePot: _showCreatePotSheet,
            onManageTemplates: widget.isAdminHere
                ? () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TemplatesScreen(
                            groupId: widget.groupId!,
                            isAdmin: widget.isAdminHere,
                            currentMembers: widget.members,
                          ),
                    ))
                : null,
          ),
        ),
        if (_loadingTotals)
          const Positioned(
            top: 12,
            right: 12,
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  Widget _totalsCard(List<Boete> items) {
    final paid = _paidTotals.values.fold(0.0, (s, v) => s + v);
    final open = _outstanding(items);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AppCard(
        radius: 22,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Totaal openstaand', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.groupName ?? 'In deze BoetePot',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.roleLabel != null) ...[
                        const SizedBox(width: 8),
                        AppPill(text: widget.roleLabel!.toUpperCase()),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.04 * 255).round()),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.cardStroke, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Details', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 6),
                            const Icon(Icons.keyboard_arrow_down, size: 18, color: AppTheme.textSecondary),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _detailRow('Totaal', _formatCurrency(_totalAmount(items))),
                        _detailRow('Betaald', _formatCurrency(paid)),
                        _detailRow('Open', _formatCurrency(open), bold: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _AmountRing(amount: open),
          ],
        ),
      ),
    );
  }

  Widget _myCard(List<Boete> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AppCard(
        radius: 22,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            AvatarCircle(title: widget.currentUserEmail, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Jij', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    _memberByUid(widget.currentUid)?.displayName ?? widget.currentUserEmail,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  _detailRow('Betaald', _formatCurrency(_paidTotals[widget.currentUid] ?? 0)),
                  _detailRow('Open', _formatCurrency(_myOutstanding(items)), bold: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalsPerUserCard(List<Boete> items) {
    final rows = _totalsPerUser(items).take(5).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: AppCard(
        radius: 22,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Totals per lid', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...rows.map((row) {
              final user = row.$1;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    AvatarCircle(title: user?.displayName ?? user?.email ?? 'U'),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        user?.displayName?.isNotEmpty == true ? user!.displayName! : (user?.email ?? 'Onbekend'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatCurrency(row.$2),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddBoeteDialog() async {
    final gid = widget.groupId;
    if (gid == null) return;
    final title = TextEditingController();
    final desc = TextEditingController();
    final amount = TextEditingController();
    String selectedUid = widget.currentUid;
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
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add Boete', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                    TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')),
                    TextField(
                      controller: amount,
                      decoration: const InputDecoration(labelText: 'Amount (€)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedUid,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Assign to'),
                      items: widget.members.map((u) {
                        final label = (u.displayName?.isNotEmpty == true) ? u.displayName! : u.email;
                        return DropdownMenuItem(value: u.id, child: Text(label));
                      }).toList(),
                      onChanged: (v) => setState(() => selectedUid = v ?? selectedUid),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(error!, style: const TextStyle(color: Colors.red)),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        const SizedBox(width: 6),
                        FilledButton(
                          onPressed: () async {
                            final t = title.text.trim();
                            final d = desc.text.trim();
                            final a = double.tryParse(amount.text.replaceAll(',', '.'));
                            if (t.isEmpty || d.isEmpty || a == null) {
                              setState(() => error = 'Please fill all fields with a valid amount.');
                              return;
                            }
                            final assigneeEmail = _memberByUid(selectedUid)?.email;
                            await _boeteService.addBoete(
                              title: t,
                              description: d,
                              amount: a,
                              userEmail: widget.currentUserEmail,
                              groupId: gid,
                              assignedToUid: selectedUid,
                              assignedToEmail: assigneeEmail,
                            );
                            if (!mounted) return;
                            Navigator.pop(context);
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditDialog(Boete b) async {
    final title = TextEditingController(text: b.title);
    final desc = TextEditingController(text: b.description);
    final amount = TextEditingController(text: b.amount.toStringAsFixed(2));
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
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Edit Boete', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        const SizedBox(width: 6),
                        FilledButton(
                          onPressed: () async {
                            final t = title.text.trim();
                            final d = desc.text.trim();
                            final a = double.tryParse(amount.text.replaceAll(',', '.'));
                            if (t.isEmpty || d.isEmpty || a == null) {
                              setState(() => error = 'Please fill all fields with a valid amount.');
                              return;
                            }
                            await _boeteService.updateBoete(
                              id: b.id,
                              title: t,
                              description: d,
                              amount: a,
                              groupId: b.groupId,
                            );
                            if (!mounted) return;
                            Navigator.pop(context);
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(Boete b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Boete'),
        content: const Text('Weet je zeker dat je deze boete wil verwijderen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await _boeteService.deleteBoete(b.id);
    }
  }

  Future<void> _showAddFromTemplates() async {
    final gid = widget.groupId;
    if (gid == null) return;
    final selected = <String>{};
    String assignee = widget.currentUid;
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
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add from templates', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: assignee,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Assign to'),
                      items: widget.members.map((u) {
                        final label = (u.displayName?.isNotEmpty == true) ? u.displayName! : u.email;
                        return DropdownMenuItem(value: u.id, child: Text(label));
                      }).toList(),
                      onChanged: (v) => setState(() => assignee = v ?? assignee),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<BoeteTemplate>>(
                      stream: _boeteService.watchTemplates(gid),
                      builder: (context, snap) {
                        if (!snap.hasData) return const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator());
                        final templates = snap.data!;
                        if (templates.isEmpty) {
                          return Text('No templates yet', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary));
                        }
                        return Column(
                          children: templates.map((tpl) {
                            final checked = selected.contains(tpl.id);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(tpl.title, style: const TextStyle(color: AppTheme.textPrimary)),
                              subtitle: Text(tpl.description, style: const TextStyle(color: AppTheme.textSecondary)),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(_formatCurrency(tpl.amount), style: const TextStyle(color: AppTheme.textPrimary)),
                                  const SizedBox(height: 4),
                                  Icon(checked ? Icons.check_circle : Icons.circle_outlined, color: checked ? AppTheme.gold : AppTheme.textSecondary),
                                ],
                              ),
                              onTap: () {
                                setState(() {
                                  if (checked) {
                                    selected.remove(tpl.id);
                                  } else {
                                    selected.add(tpl.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(error!, style: const TextStyle(color: Colors.red)),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        const SizedBox(width: 6),
                        FilledButton(
                          onPressed: () async {
                            final templatesSnap = await _boeteService.watchTemplates(gid).first;
                            final chosen = templatesSnap.where((t) => selected.contains(t.id)).toList();
                            if (chosen.isEmpty) {
                              setState(() => error = 'Select at least one template.');
                              return;
                            }
                            final assigneeEmail = _memberByUid(assignee)?.email;
                            await _boeteService.addBoetesFromTemplates(
                              templates: chosen,
                              assignedToUid: assignee,
                              assignedToEmail: assigneeEmail,
                              groupId: gid,
                              createdByEmail: widget.currentUserEmail,
                            );
                            if (!mounted) return;
                            Navigator.pop(context);
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreatePotSheet() async {
    final name = TextEditingController();
    final emails = TextEditingController();
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
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nieuwe BoetePot', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Naam'),
                    ),
                    TextField(
                      controller: emails,
                      decoration: const InputDecoration(labelText: 'Lid e-mails (comma separated)'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(error!, style: const TextStyle(color: Colors.red)),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        const SizedBox(width: 6),
                        FilledButton(
                          onPressed: () async {
                            final n = name.text.trim();
                            if (n.isEmpty) {
                              setState(() => error = 'Naam is verplicht');
                              return;
                            }
                            final emailList = emails.text
                                .split(',')
                                .map((e) => e.trim().toLowerCase())
                                .where((e) => e.isNotEmpty)
                                .toList();
                            try {
                              final newId = await _groupService.createGroup(
                                name: n,
                                currentUid: widget.currentUid,
                                memberEmails: emailList,
                              );
                              widget.onGroupCreated?.call(newId, n);
                              if (!mounted) return;
                              Navigator.pop(context);
                            } catch (e) {
                              setState(() => error = e.toString());
                            }
                          },
                          child: const Text('Create'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _formatCurrency(double v) => '€${v.toStringAsFixed(2)}';
}

class _BoeteRow extends StatelessWidget {
  const _BoeteRow({
    required this.boete,
    required this.assignee,
    this.onEdit,
    this.onDelete,
  });

  final Boete boete;
  final AppUser? assignee;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  String get _assigneeLabel {
    if (assignee == null) return '';
    return assignee!.displayName?.isNotEmpty == true ? assignee!.displayName! : assignee!.email;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            assignee?.photoURL != null && assignee!.photoURL!.isNotEmpty
                ? CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(assignee!.photoURL!),
                  )
                : AvatarCircle(title: assignee?.displayName ?? assignee?.email ?? boete.title, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(boete.title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(boete.description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Text(_formatDate(boete.dateAdded), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_assigneeLabel.isNotEmpty) AppPill(text: _assigneeLabel),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withAlpha((0.14 * 255).round()),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.cardStroke, width: 1),
                  ),
                  child: Text(
                    '€${boete.amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.gold, fontWeight: FontWeight.bold),
                  ),
                ),
                if (onEdit != null || onDelete != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onEdit != null)
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18, color: AppTheme.textSecondary),
                          onPressed: onEdit,
                        ),
                      if (onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                          onPressed: onDelete,
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _FabMenu extends StatelessWidget {
  const _FabMenu({
    required this.canAdd,
    required this.onAddBoete,
    required this.onAddFromTemplates,
    required this.onCreatePot,
    this.onManageTemplates,
  });

  final bool canAdd;
  final VoidCallback onAddBoete;
  final VoidCallback onAddFromTemplates;
  final VoidCallback onCreatePot;
  final VoidCallback? onManageTemplates;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Acties',
      position: PopupMenuPosition.over,
      onSelected: (v) {
        switch (v) {
          case 'add':
            onAddBoete();
            break;
          case 'templates':
            onAddFromTemplates();
            break;
          case 'createPot':
            onCreatePot();
            break;
          case 'manageTemplates':
            onManageTemplates?.call();
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'add',
          enabled: canAdd,
          child: const Text('Add Boete'),
        ),
        PopupMenuItem(
          value: 'templates',
          enabled: canAdd,
          child: const Text('Add from Templates'),
        ),
        const PopupMenuItem(
          value: 'createPot',
          child: Text('New BoetePot'),
        ),
        if (onManageTemplates != null)
          const PopupMenuItem(
            value: 'manageTemplates',
            child: Text('Manage Templates'),
          ),
      ],
      child: const GoldFab(
        onPressed: null,
        icon: Icons.add,
      ),
    );
  }
}

class _AmountRing extends StatelessWidget {
  const _AmountRing({required this.amount});
  final double amount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.cardStroke, width: 7),
            ),
          ),
          Transform.rotate(
            angle: -3.1415 / 2,
            child: CircularProgressIndicator(
              value: 0.82,
              strokeWidth: 8,
              color: AppTheme.gold,
              backgroundColor: Colors.transparent,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('€${amount.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
              Text('open', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
