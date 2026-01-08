import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models.dart';

class TemplatesService {
  final _db = FirebaseFirestore.instance;

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
            // Missing composite index for the ordered query; fall back to a simpler query and sort client-side.
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

    // Primary: match SwiftUI query. If this needs a composite index, we fall back automatically.
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

  /// Admin view: include active + inactive templates.
  Stream<List<BoeteTemplate>> watchAllTemplates(String groupId) {
    final controller = StreamController<List<BoeteTemplate>>();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;

    void emitFromSnapshot(QuerySnapshot<Map<String, dynamic>> snap, {required bool sortByTitle}) {
      final items = snap.docs.map((d) => BoeteTemplate.fromDoc(d)).toList();
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

    // Prefer a stable ordering if possible. If index missing, fall back and sort locally.
    listenTo(
      query: _db.collection('boeteTemplates').where('groupId', isEqualTo: groupId).orderBy('title'),
      sortByTitle: false,
      allowFallbackOnIndexError: true,
    );

    controller.onCancel = () => sub?.cancel();
    return controller.stream;
  }

  Future<List<BoeteTemplate>> fetchTemplatesOnce(String groupId) async {
    try {
      final snap = await _db
          .collection('boeteTemplates')
          .where('groupId', isEqualTo: groupId)
          .where('isActive', isEqualTo: true)
          .orderBy('title')
          .get();
      return snap.docs.map((d) => BoeteTemplate.fromDoc(d)).where((t) => t.isActive).toList();
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;
      // Fallback (no composite index needed), sort locally.
      final snap = await _db.collection('boeteTemplates').where('groupId', isEqualTo: groupId).get();
      final items = snap.docs.map((d) => BoeteTemplate.fromDoc(d)).where((t) => t.isActive).toList();
      items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      return items;
    }
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
      'createdBy': createdBy,
      'isActive': true,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> updateTemplate({
    required String id,
    required String groupId,
    required String title,
    required String description,
    required double amount,
  }) async {
    await _db.collection('boeteTemplates').doc(id).set(
      {
        'groupId': groupId,
        'title': title,
        'description': description,
        'amount': amount,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> deactivateTemplate(BoeteTemplate tpl) async {
    await _db.collection('boeteTemplates').doc(tpl.id).set({'isActive': false}, SetOptions(merge: true));
  }

  Future<void> activateTemplate(BoeteTemplate tpl) async {
    await _db.collection('boeteTemplates').doc(tpl.id).set({'isActive': true}, SetOptions(merge: true));
  }

  Future<void> deleteTemplate(BoeteTemplate tpl) async {
    await _db.collection('boeteTemplates').doc(tpl.id).delete();
  }

  Future<void> addBoetesFromTemplates({
    required List<BoeteTemplate> templates,
    required String assignedToUid,
    String? assignedToEmail,
    required String groupId,
    required String createdByEmail,
  }) async {
    if (templates.isEmpty) return;
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
