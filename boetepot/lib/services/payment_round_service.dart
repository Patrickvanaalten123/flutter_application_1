import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models.dart';

class PaymentRoundService {
  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west2');

  static double computeServiceFee(double baseAmount) {
    if (baseAmount <= 0) return 0;
    final pct = baseAmount >= 100 ? 0.01 : 0.03;
    final fee = baseAmount * pct;
    final withMin = fee < 1 ? 1 : fee;
    return double.parse(withMin.toStringAsFixed(2));
  }

  Stream<List<PaymentRound>> watchRounds(String groupId) {
    return _db.collection('paymentRounds')
      .where('groupId', isEqualTo: groupId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => PaymentRound.fromDoc(d)).toList());
  }

  Stream<List<PaymentObligation>> watchPayments(String roundId) {
    return _db.collection('paymentRounds')
      .doc(roundId)
      .collection('payments')
      .snapshots()
      .map((snap) => snap.docs.map((d) => PaymentObligation.fromDoc(d)).toList());
  }

  Future<void> markPaid({
    required String roundId,
    required String uid,
    required bool paid,
    required String markerUid,
  }) async {
    final ref = _db.collection('paymentRounds').doc(roundId).collection('payments').doc(uid);
    final data = {
      'paid': paid,
      'markedByUid': markerUid,
      'paidAt': paid ? Timestamp.now() : null,
    };
    await ref.set(data, SetOptions(merge: true));
  }

  Future<void> setRoundStatus({required String roundId, required bool isOpen}) async {
    await _db.collection('paymentRounds').doc(roundId).set({
      'status': isOpen ? 'open' : 'closed',
    }, SetOptions(merge: true));
  }

  Future<Uri> createMollieCheckoutForRound({
    required String roundId,
  }) async {
    final callable = _functions.httpsCallable(
      'createMolliePaymentForRound',
      options: HttpsCallableOptions(timeout: const Duration(minutes: 2)),
    );
    try {
      final res = await callable.call({'roundId': roundId});
      final data = (res.data as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      final url = (data['checkoutUrl'] as String?)?.trim() ?? '';
      final uri = Uri.tryParse(url);
      if (uri == null) {
        throw Exception('Ongeldige betaal-URL ontvangen.');
      }
      return uri;
    } on FirebaseFunctionsException catch (e) {
      final msg = (e.message ?? '').trim();
      throw Exception(msg.isNotEmpty ? msg : 'Betaling starten mislukt (${e.code}).');
    }
  }

  // Compute totals already paid across all rounds for a group
  Future<Map<String, double>> fetchTotalPaidForGroup(String groupId) async {
    final rounds = await _db.collection('paymentRounds')
      .where('groupId', isEqualTo: groupId)
      .get();

    final Map<String, double> totals = {};
    for (final r in rounds.docs) {
      final pays = await r.reference.collection('payments').where('paid', isEqualTo: true).get();
      for (final d in pays.docs) {
        final data = d.data();
        final uid = (data['uid'] as String?) ?? d.id;
        final amount = ((data['amount'] as num?) ?? 0).toDouble();
        totals[uid] = (totals[uid] ?? 0) + amount;
      }
    }
    return totals;
  }

  // Create round: aggregate boetes up to asOf, subtract already-paid in previous rounds (<= asOf)
  // ... keep your imports and class

  Future<PaymentRound> createRound({
    required String groupId,
    required DateTime asOf,
    String? note,
    String? paymentLink,
    required bool includeZeroMembers,
    required String currentUid,
  }) async {
    // 1) Fetch group members
    final groupDoc = await _db.collection('groups').doc(groupId).get();
    final g = groupDoc.data() ?? {};
    final members = (g['members'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];

    // 2) Aggregate boetes up to asOf
    final asOfTs = Timestamp.fromDate(asOf);
    final boetesSnap = await _db.collection('boetes')
      .where('groupId', isEqualTo: groupId)
      .where('dateAdded', isLessThanOrEqualTo: asOfTs)
      .get();

    final Map<String, double> totalBoetes = {};
    for (final d in boetesSnap.docs) {
      final data = d.data();
      final uid = (data['assignedToUid'] as String?) ?? '';
      final amount = ((data['amount'] as num?) ?? 0).toDouble();
      if (uid.isEmpty) continue;
      totalBoetes[uid] = (totalBoetes[uid] ?? 0) + amount;
    }

    // 3) Already paid in rounds with asOf <= selected asOf
    final prevRounds = await _db.collection('paymentRounds')
      .where('groupId', isEqualTo: groupId)
      .where('asOf', isLessThanOrEqualTo: asOfTs)
      .get();

    final Map<String, double> alreadyPaid = {};
    for (final r in prevRounds.docs) {
      final pays = await r.reference.collection('payments').where('paid', isEqualTo: true).get();
      for (final p in pays.docs) {
        final pd = p.data();
        final uid = (pd['uid'] as String?) ?? p.id;
        final amount = ((pd['amount'] as num?) ?? 0).toDouble();
        alreadyPaid[uid] = (alreadyPaid[uid] ?? 0) + amount;
      }
    }

    // 3b) Fetch user emails/displayNames for members (so payments have names)
    final Map<String, Map<String, String>> usersByUid = {};
    if (members.isNotEmpty) {
      final chunks = <List<String>>[];
      for (var i = 0; i < members.length; i += 10) {
        chunks.add(members.sublist(i, i + 10 > members.length ? members.length : i + 10));
      }
      for (final chunk in chunks) {
        final snap = await _db.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
        for (final d in snap.docs) {
          final data = d.data();
          usersByUid[d.id] = {
            'email': (data['email'] as String?) ?? '',
            'displayName': (data['displayName'] as String?) ?? '',
          };
        }
      }
    }

    // 4) Create round doc
    final roundRef = await _db.collection('paymentRounds').add({
      'groupId': groupId,
      'createdAt': Timestamp.now(),
      'createdBy': currentUid,
      'status': 'open',
      'note': (note != null && note.isNotEmpty) ? note : null,
      'paymentLink': (paymentLink != null && paymentLink.isNotEmpty) ? paymentLink : null,
      'asOf': asOfTs,
    });

    // 5) Fill payments subcollection
    final batch = _db.batch();
    for (final uid in members) {
      final total = totalBoetes[uid] ?? 0.0;
      final paidSoFar = alreadyPaid[uid] ?? 0.0;
      final due = (total - paidSoFar);
      if (!includeZeroMembers && due <= 0) continue;

      final info = usersByUid[uid] ?? const {'email': '', 'displayName': ''};
      final payRef = roundRef.collection('payments').doc(uid);
      batch.set(payRef, {
        'uid': uid,
        'email': info['email'],
        'displayName': info['displayName'],
        'amount': due < 0 ? 0.0 : due,
        'paid': false,
        'paidAt': null,
        'markedByUid': null,
      }, SetOptions(merge: true));
    }
    await batch.commit();

    // Return the created round
    final created = await roundRef.get();
    return PaymentRound.fromDoc(created);
  }
}
