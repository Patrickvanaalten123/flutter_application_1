import 'package:flutter/material.dart';
import '../services/boete_service.dart';
import '../services/payment_round_service.dart';
import '../services/group_service.dart';
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
    final me = _memberByUid(widget.currentUid);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AppCard(
        radius: 22,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            UserAvatar(
              title: me?.displayName ?? widget.currentUserEmail,
              photoUrl: me?.photoURL,
              size: 40,
            ),
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
                    UserAvatar(
                      title: user?.displayName ?? user?.email ?? 'U',
                      photoUrl: user?.photoURL,
                    ),
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

  Future<void> _showEditDialog(Boete b) async {
    final title = TextEditingController(text: b.title);
    final desc = TextEditingController(text: b.description);
    final amount = TextEditingController(text: b.amount.toStringAsFixed(2));
    String? error;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return AppBottomSheet(
          childBuilder: (sheetContext, scrollController) {
            return StatefulBuilder(
              builder: (context, setState) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Edit Boete',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                    const SizedBox(height: 10),
                    TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amount,
                      decoration: const InputDecoration(labelText: 'Amount (€)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(error!, style: const TextStyle(color: Colors.red)),
                      ),
                    const SizedBox(height: 14),
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
                );
              },
            );
          },
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

  Future<void> _showCreatePotSheet() async {
    final name = TextEditingController();
    final emails = TextEditingController();
    String? error;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return AppBottomSheet(
          childBuilder: (sheetContext, scrollController) {
            return StatefulBuilder(
              builder: (context, setState) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Nieuwe BoetePot',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Naam'),
                    ),
                    const SizedBox(height: 10),
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
            );
          },
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
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SizedBox(
        width: double.infinity,
        child: AppCard(
          radius: 22,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(
                title: assignee?.displayName ?? assignee?.email ?? boete.title,
                photoUrl: assignee?.photoURL,
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      boete.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      boete.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(boete.dateAdded),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary, fontSize: 12),
                    ),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (onEdit == null && onDelete == null) return child;

    return _SwipeReveal(
      key: ValueKey('boete-${boete.id}'),
      child: child,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _SwipeActionButton extends StatelessWidget {
  const _SwipeActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 88,
        height: 54,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.cardStroke, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeReveal extends StatefulWidget {
  const _SwipeReveal({
    super.key,
    required this.child,
    required this.onEdit,
    required this.onDelete,
  });

  final Widget child;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<_SwipeReveal> createState() => _SwipeRevealState();
}

class _SwipeRevealState extends State<_SwipeReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const double _buttonWidth = 88;
  static const double _gap = 10;
  static const double _reveal = (_buttonWidth * 2) + _gap;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 170));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() => _controller.animateTo(1, curve: Curves.easeOutCubic);
  void _close() => _controller.animateTo(0, curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (d) {
        // drag left opens, drag right closes
        final delta = -d.primaryDelta!;
        final next = (_controller.value * _reveal + delta) / _reveal;
        _controller.value = next.clamp(0.0, 1.0);
      },
      onHorizontalDragEnd: (_) {
        if (_controller.value > 0.25) {
          _open();
        } else {
          _close();
        }
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final reveal = _controller.value.clamp(0.0, 1.0);
                return IgnorePointer(
                  ignoring: reveal < 0.02,
                  child: Opacity(
                    opacity: reveal,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SwipeActionButton(
                              label: 'Edit',
                              icon: Icons.edit,
                              background: AppTheme.cardFill,
                              foreground: AppTheme.textPrimary,
                              onTap: () {
                                widget.onEdit?.call();
                                _close();
                              },
                            ),
                            const SizedBox(width: _gap),
                            _SwipeActionButton(
                              label: 'Delete',
                              icon: Icons.delete,
                              background: Colors.red.withAlpha((0.22 * 255).round()),
                              foreground: Colors.redAccent,
                              onTap: () {
                                widget.onDelete?.call();
                                _close();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Transform.translate(
                offset: Offset(-_controller.value * _reveal, 0),
                child: widget.child,
              );
            },
          ),
        ],
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
