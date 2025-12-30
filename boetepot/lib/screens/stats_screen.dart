import 'package:flutter/material.dart';
import '../services/payment_round_service.dart';
import '../services/boete_service.dart';
import '../models.dart';

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

  double _totalAmount = 0;
  Map<String, double> _paidTotals = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final paid = await _pay.fetchTotalPaidForGroup(widget.groupId);
    setState(() => _paidTotals = paid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Boete>>(
      stream: _boete.watchBoetes(widget.groupId),
      builder: (context, snap) {
        final boetes = snap.data ?? [];
        _totalAmount = boetes.fold(0.0, (sum, b) => sum + b.amount);

        final outstanding = _totalAmount - _paidTotals.values.fold(0.0, (s, v) => s + v);
        final myTotal = boetes.where((b) => b.assignedToUid == widget.currentUid).fold(0.0, (s, b) => s + b.amount);
        final myPaid = _paidTotals[widget.currentUid] ?? 0.0;
        final myOutstanding = (myTotal - myPaid).clamp(0.0, double.infinity);

        final totalsByUser = <String, double>{};
        for (final b in boetes) {
          totalsByUser[b.assignedToUid] = (totalsByUser[b.assignedToUid] ?? 0.0) + b.amount;
        }
        final sortedTotals = totalsByUser.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: const Text('Totaal openstaand'),
                  subtitle: Text('In deze BoetePot'),
                  trailing: Text('€${outstanding.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  title: const Text('Jij (open)'),
                  subtitle: Text('Betaald: €${myPaid.toStringAsFixed(2)}'),
                  trailing: Text('€${myOutstanding.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Totals per lid', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...sortedTotals.take(10).map((e) => ListTile(
                    title: Text(e.key),
                    trailing: Text('€${e.value.toStringAsFixed(2)}'),
                  )),
            ],
          ),
        );
      },
    );
  }
}