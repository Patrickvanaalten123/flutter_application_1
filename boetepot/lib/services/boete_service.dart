import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models.dart';

class BoeteService {
  final _db = FirebaseFirestore.instance;

  Future<void> _assertCanIssueBoete({
    required String groupId,
    required String actorUid,
  }) async {
    if (actorUid.isEmpty) {
      throw Exception('Je bent niet ingelogd.');
    }
    final snap = await _db.collection('groups').doc(groupId).get();
    final data = snap.data() ?? <String, dynamic>{};
    final roles = (data['roles'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? <String, String>{};
    final members = (data['members'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final role = roles[actorUid] ?? 'member';

    final allowed = role == 'admin' || role == 'boeteAssigner';
    if (!members.contains(actorUid) || !allowed) {
      throw Exception('Je hebt geen rechten om boetes uit te delen in deze BoetePot.');
    }
  }

  Stream<List<Boete>> watchBoetes({
    String? groupId,
    String? userEmail,
    int limit = 100,
  }) {
    Query<Map<String, dynamic>> q = _db.collection('boetes');
    if (groupId != null) q = q.where('groupId', isEqualTo: groupId);
    if (userEmail != null) q = q.where('userEmail', isEqualTo: userEmail);
    q = q.orderBy('dateAdded', descending: true).limit(limit);
    return q.snapshots().map((snap) => snap.docs.map((d) => Boete.fromDoc(d)).toList());
  }

  Future<void> addBoete({
    required String title,
    required String description,
    required double amount,
    required String userEmail,
    required String groupId,
    required String assignedToUid,
    required String createdByUid,
    String? assignedToEmail,
  }) async {
    await _assertCanIssueBoete(groupId: groupId, actorUid: createdByUid);
    await _db.collection('boetes').add({
      'title': title,
      'description': description,
      'amount': amount,
      'userEmail': userEmail,
      'groupId': groupId,
      'dateAdded': Timestamp.now(),
      'assignedToUid': assignedToUid,
      'assignedToEmail': assignedToEmail,
    });
  }

  Future<void> updateBoete({
    required String id,
    required String title,
    required String description,
    required double amount,
    required String groupId, // always send back groupId like iOS
  }) async {
    await _db.collection('boetes').doc(id).update({
      'title': title,
      'description': description,
      'amount': amount,
      'groupId': groupId,
    });
  }

  Future<void> deleteBoete(String id) async {
    await _db.collection('boetes').doc(id).delete();
  }

  // Templates
  Stream<List<BoeteTemplate>> watchTemplates(String groupId) {
    final controller = StreamController<List<BoeteTemplate>>();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;

    void emitFromSnapshot(QuerySnapshot<Map<String, dynamic>> snap, {required bool sortByTitle}) {
      final items = snap.docs.map((d) => BoeteTemplate.fromDoc(d)).where((t) => t.isActive).toList();
      if (sortByTitle) {
        items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      }
      controller.add(items);
    }

    void listenTo({
      required Query<Map<String, dynamic>> query,
      required bool sortByTitle,
      required bool allowFallbackOnIndexError,
    }) {
      sub?.cancel();
      sub = query.snapshots().listen(
        (snap) => emitFromSnapshot(snap, sortByTitle: sortByTitle),
        onError: (Object err, StackTrace st) {
          final isIndexError = err is FirebaseException && err.code == 'failed-precondition';
          if (allowFallbackOnIndexError && isIndexError) {
            listenTo(
              query: _db.collection('boeteTemplates').where('groupId', isEqualTo: groupId),
              sortByTitle: true,
              allowFallbackOnIndexError: false,
            );
            return;
          }
          controller.addError(err, st);
        },
      );
    }

    listenTo(
      query: _db
          .collection('boeteTemplates')
          .where('groupId', isEqualTo: groupId)
          .where('isActive', isEqualTo: true)
          .orderBy('title'),
      sortByTitle: false,
      allowFallbackOnIndexError: true,
    );

    controller.onCancel = () => sub?.cancel();
    return controller.stream;
  }

  Future<void> createTemplate({
    required String groupId,
    required String title,
    required String description,
    required double amount,
    required String createdBy,
  }) async {
    await _db.collection('boeteTemplates').add({
      'groupId': groupId,
      'title': title,
      'description': description,
      'amount': amount,
      'isActive': true,
      'createdBy': createdBy,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> updateTemplate(BoeteTemplate tpl) async {
    await _db.collection('boeteTemplates').doc(tpl.id).set({
      'groupId': tpl.groupId,
      'title': tpl.title,
      'description': tpl.description,
      'amount': tpl.amount,
      'isActive': tpl.isActive,
      'createdBy': tpl.createdBy,
    }, SetOptions(merge: true));
  }

  Future<void> deleteTemplate(BoeteTemplate tpl) async {
    await _db.collection('boeteTemplates').doc(tpl.id).delete();
  }

  Future<void> addBoetesFromTemplates({
    required List<BoeteTemplate> templates,
    required String assignedToUid,
    required String? assignedToEmail,
    required String groupId,
    required String createdByEmail,
    required String createdByUid,
  }) async {
    if (templates.isEmpty) return;
    await _assertCanIssueBoete(groupId: groupId, actorUid: createdByUid);
    final batch = _db.batch();
    for (final tpl in templates) {
      final ref = _db.collection('boetes').doc();
      batch.set(ref, {
        'groupId': groupId,
        'title': tpl.title,
        'description': tpl.description,
        'amount': tpl.amount,
        'userEmail': createdByEmail,
        'assignedToUid': assignedToUid,
        'assignedToEmail': assignedToEmail,
        'dateAdded': Timestamp.now(),
      });
    }
    await batch.commit();
  }
}
