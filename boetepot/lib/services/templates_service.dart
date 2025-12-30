import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';

class TemplatesService {
  final _db = FirebaseFirestore.instance;

  Stream<List<BoeteTemplate>> watchTemplates(String groupId) {
    return _db.collection('boeteTemplates')
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
      'createdBy': createdBy,
      'isActive': true,
    });
  }

  Future<void> deactivateTemplate(BoeteTemplate tpl) async {
    await _db.collection('boeteTemplates').doc(tpl.id).set({'isActive': false}, SetOptions(merge: true));
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