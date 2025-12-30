import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';

class BoeteService {
  final _db = FirebaseFirestore.instance;

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
    String? assignedToEmail,
  }) async {
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
    return _db
        .collection('boeteTemplates')
        .where('groupId', isEqualTo: groupId)
        .where('isActive', isEqualTo: true)
        .orderBy('title')
        .snapshots()
        .map((snap) => snap.docs.map((d) => BoeteTemplate.fromDoc(d)).toList());
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
