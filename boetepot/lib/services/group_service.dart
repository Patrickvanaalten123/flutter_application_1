import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';

class GroupService {
  final _db = FirebaseFirestore.instance;

  // List groups where user is a member
  Stream<List<BoetePotGroup>> watchGroupsFor(String uid) {
    final base = _db.collection('groups').where('members', arrayContains: uid);
    return base.orderBy('name').snapshots().map(
          (snap) => snap.docs.map((d) => BoetePotGroup.fromDoc(d)).toList(),
        );
  }

  // Members + roles of a single group
  Stream<({List<AppUser> members, Map<String, String> roles})> watchGroupMembers(String groupId) {
    final docRef = _db.collection('groups').doc(groupId);
    return docRef.snapshots().asyncMap((snap) async {
      final data = snap.data() ?? {};
      final memberUIDs = (data['members'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
      final roles = (data['roles'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? <String, String>{};

      if (memberUIDs.isEmpty) {
        return (members: <AppUser>[], roles: roles);
      }

      // chunked fetch (max 10 per 'in' query)
      final chunks = <List<String>>[];
      for (var i = 0; i < memberUIDs.length; i += 10) {
        chunks.add(memberUIDs.sublist(i, i + 10 > memberUIDs.length ? memberUIDs.length : i + 10));
      }

      final List<AppUser> collected = [];
      for (final chunk in chunks) {
        final q = await _db.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
        collected.addAll(q.docs.map((d) => AppUser.fromDoc(d)));
      }

      collected.sort((a, b) => (a.displayName ?? a.email).compareTo(b.displayName ?? b.email));
      return (members: collected, roles: roles);
    });
  }

  Future<void> addMembers(String groupId, List<String> emails) async {
    final trimmed = emails.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet().toList();
    if (trimmed.isEmpty) return;
    final chunks = <List<String>>[];
    for (var i = 0; i < trimmed.length; i += 10) {
      chunks.add(trimmed.sublist(i, i + 10 > trimmed.length ? trimmed.length : i + 10));
    }
    final List<String> uids = [];
    for (final chunk in chunks) {
      final snap = await _db.collection('users').where('email', whereIn: chunk).get();
      uids.addAll(snap.docs.map((d) => d.id));
    }
    if (uids.isEmpty) return;

    final updates = <String, dynamic>{};
    for (final uid in uids) {
      updates['roles.$uid'] = 'member';
    }

    final ref = _db.collection('groups').doc(groupId);
    await ref.update({
      'members': FieldValue.arrayUnion(uids),
      ...updates,
    });
  }

  Future<void> removeMember(String groupId, String uid) async {
    final ref = _db.collection('groups').doc(groupId);
    await ref.update({
      'members': FieldValue.arrayRemove([uid]),
      'roles.$uid': FieldValue.delete(),
    });
  }

  Future<void> setRole(String groupId, String uid, String role) async {
    const allowed = {'admin', 'boeteAssigner', 'member'};
    if (!allowed.contains(role)) {
      throw Exception('Invalid role');
    }
    final ref = _db.collection('groups').doc(groupId);
    await ref.update({'roles.$uid': role});
  }
}