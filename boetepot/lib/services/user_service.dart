import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models.dart';

class UserService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> ensureUserDoc(User? user, {String? displayName}) async {
    if (user == null) return;
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'email': user.email ?? '',
        if (displayName != null && displayName.isNotEmpty) 'displayName': displayName,
      }, SetOptions(merge: true));
    } else if (displayName != null && displayName.isNotEmpty) {
      await ref.set({'displayName': displayName}, SetOptions(merge: true));
    }
  }

  static Stream<AppUser?> watchMe(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((d) {
      if (!d.exists) return null;
      return AppUser.fromDoc(d);
    });
  }

  static Future<void> setPhotoURL(String uid, String url) {
    return _db.collection('users').doc(uid).set({'photoURL': url}, SetOptions(merge: true));
  }
}