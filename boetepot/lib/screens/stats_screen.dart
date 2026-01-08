import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/payment_round_service.dart';
import '../services/boete_service.dart';
import '../services/group_service.dart';
import '../models.dart';
import '../ui.dart';

class StatsScreen extends StatefulWidget {
  final String groupId;
  final String currentUid;
  const StatsScreen({super.key, required this.groupId, required this.currentUid});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _pay = PaymentRoundService();
  final _boete = BoeteService();
  final _group = GroupService();

  Map<String, double> _paidTotals = {};
  List<AppUser> _members = [];

  @override
  void initState() {
    super.initState();
    _group.watchGroupMembers(widget.groupId).listen((data) {
      setState(() => _members = data.members);
    });
    _reload();
  }

  Future<void> _reload() async {
    final paid = await _pay.fetchTotalPaidForGroup(widget.groupId);
    if (mounted) setState(() => _paidTotals = paid);
  }

  @override
  Widget build(BuildContext context) {
    final memberByUid = {for (final m in _members) m.id: m};

    return StreamBuilder<List<Boete>>(
      stream: _boete.watchBoetes(groupId: widget.groupId),
      builder: (context, snap) {
        final boetes = snap.data ?? [];
        final totalAmount = boetes.fold(0.0, (sum, b) => sum + b.amount);

        final paidSum = _paidTotals.values.fold(0.0, (s, v) => s + v);
        final outstanding = (totalAmount - paidSum).clamp(0.0, double.infinity);

        final myTotal = boetes.where((b) => b.assignedToUid == widget.currentUid).fold(0.0, (s, b) => s + b.amount);
        final myPaid = _paidTotals[widget.currentUid] ?? 0.0;
        final myOutstanding = (myTotal - myPaid).clamp(0.0, double.infinity);

        final totalsByUser = <String, double>{};
        for (final b in boetes) {
          totalsByUser[b.assignedToUid] = (totalsByUser[b.assignedToUid] ?? 0.0) + b.amount;
        }
        final sortedTotals = totalsByUser.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final countsByUser = <String, int>{};
        for (final b in boetes) {
          countsByUser[b.assignedToUid] = (countsByUser[b.assignedToUid] ?? 0) + 1;
        }
        final largestBoete = boetes.isEmpty ? null : (boetes..sort((a, b) => b.amount.compareTo(a.amount))).first;

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
            children: [
              _overviewCard(outstanding, totalAmount, paidSum),
              const SizedBox(height: 10),
              _myCard(myOutstanding, myPaid),
              const SizedBox(height: 10),
              _listCard(
                title: 'Wie betaalt het meest?',
                rows: _paidTotals.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)),
                labelFor: (uid) => _label(uid, memberByUid),
                valueFor: (uid) => _formatCurrency(_paidTotals[uid] ?? 0),
                photoFor: (uid) => memberByUid[uid]?.photoURL,
              ),
              const SizedBox(height: 10),
              _listCard(
                title: 'Wie heeft de meeste boetes?',
                rows: countsByUser.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)),
                labelFor: (uid) => _label(uid, memberByUid),
                valueFor: (uid) => '${countsByUser[uid] ?? 0}',
                photoFor: (uid) => memberByUid[uid]?.photoURL,
              ),
              const SizedBox(height: 10),
              _listCard(
                title: 'Totals per lid',
                rows: sortedTotals,
                labelFor: (uid) => _label(uid, memberByUid),
                valueFor: (uid) => _formatCurrency(totalsByUser[uid] ?? 0),
                photoFor: (uid) => memberByUid[uid]?.photoURL,
              ),
              const SizedBox(height: 10),
              _largestCard(largestBoete, memberByUid),
            ],
          ),
        );
      },
    );
  }

  Widget _overviewCard(double outstanding, double total, double paid) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Totaal openstaand', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(_formatCurrency(outstanding), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              _chip('Boetes', _formatCurrency(total)),
              const SizedBox(width: 8),
              _chip('Betaald', _formatCurrency(paid)),
              const SizedBox(width: 8),
              _chip('Open', _formatCurrency(outstanding), emphasize: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _myCard(double outstanding, double paid) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final me = _members.firstWhere((m) => m.id == widget.currentUid, orElse: () => AppUser(id: widget.currentUid, email: email));
    final title = me.displayName ?? email;
    return AppCard(
      child: Row(
        children: [
          UserAvatar(
            title: title.isNotEmpty ? title : 'J',
            photoUrl: me.photoURL,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Jij', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                Text('Open: ${_formatCurrency(outstanding)}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                Text('Betaald: ${_formatCurrency(paid)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listCard({
    required String title,
    required List<MapEntry<String, dynamic>> rows,
    required String Function(String uid) labelFor,
    required String Function(String uid) valueFor,
    String? Function(String uid)? photoFor,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text('Geen data', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary))
          else
            ...rows.take(5).map((e) {
              final uid = e.key;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    UserAvatar(
                      title: labelFor(uid),
                      photoUrl: photoFor?.call(uid),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(labelFor(uid), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                    ),
                    Text(valueFor(uid), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _largestCard(Boete? boete, Map<String, AppUser> memberByUid) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Grootste boete', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (boete == null)
            Text('Geen boetes', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(boete.title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(boete.description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    UserAvatar(
                      title: _label(boete.assignedToUid, memberByUid),
                      photoUrl: memberByUid[boete.assignedToUid]?.photoURL,
                    ),
                    const SizedBox(width: 8),
                    Text(_label(boete.assignedToUid, memberByUid), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                    const Spacer(),
                    Text(_formatCurrency(boete.amount), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _chip(String title, String value, {bool emphasize = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardStroke, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: emphasize ? AppTheme.gold : AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  String _label(String uid, Map<String, AppUser> memberByUid) {
    final u = memberByUid[uid];
    return u?.displayName?.isNotEmpty == true ? u!.displayName! : (u?.email ?? uid);
  }

  String _formatCurrency(double v) => '€${v.toStringAsFixed(2)}';
}
