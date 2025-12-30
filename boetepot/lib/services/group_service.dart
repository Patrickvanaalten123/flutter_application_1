import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';

class GroupService {
  final _db = FirebaseFirestore.instance;

  Stream<List<BoetePotGroup>> watchGroupsFor(String uid) {
    final base = _db.collection('groups').where('members', arrayContains: uid);
    return base.orderBy('name').snapshots().map(
          (snap) => snap.docs.map((d) => BoetePotGroup.fromDoc(d)).toList(),
        );
  }

  Future<String> createGroup({
    required String name,
    required String currentUid,
    List<String> memberEmails = const [],
  }) async {
    final trimmedEmails = memberEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();

    // lookup users by email (chunked)
    final Set<String> memberUids = {currentUid};
    for (var i = 0; i < trimmedEmails.length; i += 10) {
      final chunk = trimmedEmails.sublist(i, i + 10 > trimmedEmails.length ? trimmedEmails.length : i + 10);
      final snap = await _db.collection('users').where('email', whereIn: chunk).get();
      memberUids.addAll(snap.docs.map((d) => d.id));
    }

    final roles = <String, String>{currentUid: 'admin'};
    for (final uid in memberUids) {
      roles.putIfAbsent(uid, () => 'member');
    }

    final ref = _db.collection('groups').doc();
    await ref.set({
      'name': name,
      'members': memberUids.toList(),
      'roles': roles,
      'createdAt': Timestamp.now(),
      'createdBy': currentUid,
    });
    return ref.id;
  }

  // Members + roles for a single group with roles normalized to UID keys
  Stream<({List<AppUser> members, Map<String, String> roles})> watchGroupMembers(String groupId) {
    final docRef = _db.collection('groups').doc(groupId);
    return docRef.snapshots().asyncMap((snap) async {
      final data = snap.data() ?? {};
      final memberUIDs = (data['members'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
      final rawRoles = (data['roles'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? <String, String>{};

      if (memberUIDs.isEmpty) {
        return (members: <AppUser>[], roles: rawRoles);
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

      // Normalize roles: map email keys to UID keys where possible
      final Map<String, String> normalized = {};
      for (final entry in rawRoles.entries) {
        final key = entry.key;
        final role = entry.value;
        if (key.contains('@')) {
          final match = collected.firstWhere(
            (u) => u.email.toLowerCase() == key.toLowerCase(),
            orElse: () => AppUser(id: '', email: ''),
          );
          if (match.id.isNotEmpty) {
            normalized[match.id] = role;
          } else {
            // keep as-is if we couldn't resolve
            normalized[key] = role;
          }
        } else {
          normalized[key] = role;
        }
      }

      return (members: collected, roles: normalized);
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
