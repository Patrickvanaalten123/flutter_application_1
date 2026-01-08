import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';

class GroupService {
  final _db = FirebaseFirestore.instance;

  /// Robust group listing: read from `userGroups/{uid}/groups/*` to avoid
  /// Firestore rules/queries issues with membership-based `list`.
  Stream<List<GroupLink>> watchGroupsFor(String uid) {
    final col = _db.collection('userGroups').doc(uid).collection('groups');
    return col.snapshots().map((snap) {
      final items = snap.docs
          .where((d) => d.id != '_meta')
          .map((d) => GroupLink.fromDoc(d))
          .toList();
      items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return items;
    });
  }

  DocumentReference<Map<String, dynamic>> _metaRef(String uid) {
    return _db.collection('userGroups').doc(uid).collection('groups').doc('_meta');
  }

  Future<bool> hasMigratedLinks(String uid) async {
    final snap = await _metaRef(uid).get();
    return snap.exists == true;
  }

  Future<void> markLinksMigrated(String uid) async {
    await _metaRef(uid).set(
      {
        'migratedAt': FieldValue.serverTimestamp(),
        'version': 1,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> upsertUserGroupLink({
    required String uid,
    required String groupId,
    required String name,
    required String role,
    required int memberCount,
    WriteBatch? batch,
  }) async {
    final ref = _db.collection('userGroups').doc(uid).collection('groups').doc(groupId);
    final data = <String, dynamic>{
      'name': name,
      'role': role,
      'memberCount': memberCount,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (batch != null) {
      batch.set(ref, data, SetOptions(merge: true));
    } else {
      await ref.set(data, SetOptions(merge: true));
    }
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
    final batch = _db.batch();
    batch.set(ref, {
      'name': name,
      'members': memberUids.toList(),
      'roles': roles,
      'createdAt': Timestamp.now(),
      'createdBy': currentUid,
    });

    final memberCount = memberUids.length;
    for (final uid in memberUids) {
      final role = roles[uid] ?? 'member';
      await upsertUserGroupLink(
        uid: uid,
        groupId: ref.id,
        name: name,
        role: role,
        memberCount: memberCount,
        batch: batch,
      );
    }

    await batch.commit();
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
    // Fetch group name for link docs (best-effort).
    final groupSnap = await ref.get();
    final gName = (groupSnap.data()?['name'] as String?) ?? 'BoetePot';
    final currentMembers = (groupSnap.data()?['members'] as List?)?.length ?? 0;
    final newMemberCount = currentMembers + uids.length;

    final batch = _db.batch();
    batch.update(ref, {
      'members': FieldValue.arrayUnion(uids),
      ...updates,
    });

    for (final uid in uids) {
      await upsertUserGroupLink(
        uid: uid,
        groupId: groupId,
        name: gName,
        role: 'member',
        memberCount: newMemberCount,
        batch: batch,
      );
    }

    await batch.commit();
  }

  Future<void> removeMember(String groupId, String uid) async {
    final ref = _db.collection('groups').doc(groupId);
    final batch = _db.batch();
    batch.update(ref, {
      'members': FieldValue.arrayRemove([uid]),
      'roles.$uid': FieldValue.delete(),
    });
    final linkRef = _db.collection('userGroups').doc(uid).collection('groups').doc(groupId);
    batch.delete(linkRef);
    await batch.commit();
  }

  Future<void> setRole(String groupId, String uid, String role) async {
    const allowed = {'admin', 'boeteAssigner', 'member'};
    if (!allowed.contains(role)) {
      throw Exception('Invalid role');
    }
    final ref = _db.collection('groups').doc(groupId);
    final groupSnap = await ref.get();
    final gName = (groupSnap.data()?['name'] as String?) ?? 'BoetePot';
    final memberCount = (groupSnap.data()?['members'] as List?)?.length ?? 0;

    final batch = _db.batch();
    batch.update(ref, {'roles.$uid': role});
    await upsertUserGroupLink(
      uid: uid,
      groupId: groupId,
      name: gName,
      role: role,
      memberCount: memberCount,
      batch: batch,
    );
    await batch.commit();
  }

  /// One-time migration helper: while `/groups` is still readable, create missing
  /// `userGroups/{uid}/groups/{groupId}` docs for the current user.
  Future<void> migrateLinksForUser(String uid) async {
    final groupsSnap = await _db.collection('groups').where('members', arrayContains: uid).get();
    if (groupsSnap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final d in groupsSnap.docs) {
      final data = d.data();
      final name = (data['name'] as String?) ?? '';
      final roles = (data['roles'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? <String, String>{};
      final role = roles[uid] ?? 'member';
      final memberCount = (data['members'] as List?)?.length ?? 0;
      await upsertUserGroupLink(
        uid: uid,
        groupId: d.id,
        name: name,
        role: role,
        memberCount: memberCount,
        batch: batch,
      );
    }
    await batch.commit();
  }
}
