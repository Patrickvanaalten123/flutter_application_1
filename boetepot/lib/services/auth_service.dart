import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_service.dart';
import 'notifications_service.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static Stream<User?> authState() => _auth.authStateChanges();

  static Future<void> signIn(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    final cred = await _auth.signInWithEmailAndPassword(email: normalizedEmail, password: password);
    await UserService.ensureUserDoc(cred.user);
    await _ensureAdminField(cred.user);
  }

  static Future<void> register(String email, String password, {String? displayName}) async {
    final normalizedEmail = email.trim().toLowerCase();
    final cred = await _auth.createUserWithEmailAndPassword(email: normalizedEmail, password: password);
    if (displayName != null && displayName.isNotEmpty) {
      await cred.user?.updateDisplayName(displayName);
    }
    await UserService.ensureUserDoc(cred.user, displayName: displayName);
    await _ensureAdminField(cred.user);
  }

  static Future<void> signOut() async {
    await NotificationsService.cleanupOnSignOut();
    await _auth.signOut();
  }

  static Stream<bool> watchIsAdmin(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      final data = doc.data();
      return (data?['isAdmin'] as bool?) ?? false;
    });
  }

  static Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(name);
    await user.reload();
    await _db.collection('users').doc(user.uid).set({'displayName': name}, SetOptions(merge: true));
  }

  static Future<void> updateEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;
    final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
    await user.reauthenticateWithCredential(cred);
    // Use verifyBeforeUpdateEmail for current plugin version (sends confirmation email)
    await user.verifyBeforeUpdateEmail(newEmail);
    await _db.collection('users').doc(user.uid).set({'email': newEmail.toLowerCase()}, SetOptions(merge: true));
  }

  static Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;
    final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }

  static Future<void> _ensureAdminField(User? user) async {
    if (user == null) return;
    final ref = _db.collection('users').doc(user.uid);
    await ref.set({'isAdmin': FieldValue.delete()}, SetOptions(merge: true));
  }
}
