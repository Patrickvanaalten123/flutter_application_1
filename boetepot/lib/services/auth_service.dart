import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  static Stream<User?> authState() => _auth.authStateChanges();

  static Future<void> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    await UserService.ensureUserDoc(cred.user);
  }

  static Future<void> register(String email, String password, {String? displayName}) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await cred.user?.updateDisplayName(displayName);
    await UserService.ensureUserDoc(cred.user, displayName: displayName);
  }

  static Future<void> signOut() => _auth.signOut();
}