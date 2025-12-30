import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';

class BoeteService {
  final _db = FirebaseFirestore.instance;

  Stream<List<Boete>> watchBoetes(String groupId) {
    return _db
        .collection('boetes')
        .where('groupId', isEqualTo: groupId)
        .orderBy('dateAdded', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Boete.fromDoc(d)).toList());
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
}