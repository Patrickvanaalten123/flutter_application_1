import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models.dart';

class UserService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> ensureUserDoc(User? user, {String? displayName}) async {
    if (user == null) return;
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    final email = (user.email ?? '').toLowerCase();
    if (!snap.exists) {
      await ref.set({
        'email': email,
        if (displayName != null && displayName.isNotEmpty) 'displayName': displayName,
        'isAdmin': false,
        'preferences': const UserPreferences().toMap(),
      }, SetOptions(merge: true));
    } else if (displayName != null && displayName.isNotEmpty) {
      await ref.set({'displayName': displayName, 'email': email}, SetOptions(merge: true));
    } else if (email.isNotEmpty && (snap.data()?['email'] as String?) != email) {
      await ref.set({'email': email}, SetOptions(merge: true));
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

  static Future<void> setDisplayName(String uid, String name) {
    return _db.collection('users').doc(uid).set({'displayName': name}, SetOptions(merge: true));
  }

  static Future<void> setPreferredGroup(String uid, String groupId) {
    return _db.collection('users').doc(uid).set({'preferredGroupId': groupId}, SetOptions(merge: true));
  }

  static Future<void> setNotifications(String uid, bool enabled) {
    return _db.collection('users').doc(uid).set({
      'preferences': {
        'notificationsEnabled': enabled,
      },
    }, SetOptions(merge: true));
  }

  static Future<void> setPaymentRoundNotifications(String uid, bool enabled) {
    return _db.collection('users').doc(uid).set({
      'preferences': {
        'paymentRoundNotificationsEnabled': enabled,
      },
    }, SetOptions(merge: true));
  }

  static Future<void> setBoeteNotifications(String uid, bool enabled) {
    return _db.collection('users').doc(uid).set({
      'preferences': {
        'boeteNotificationsEnabled': enabled,
      },
    }, SetOptions(merge: true));
  }

  static Future<void> setAdmin(String uid, bool isAdmin) {
    return _db.collection('users').doc(uid).set({'isAdmin': isAdmin}, SetOptions(merge: true));
  }
}
