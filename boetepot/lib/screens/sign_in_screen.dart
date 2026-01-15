import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isRegister = false;
  final _displayName = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    try {
      if (_isRegister) {
        await AuthService.register(_email.text.trim().toLowerCase(), _password.text, displayName: _displayName.text.trim());
      } else {
        await AuthService.signIn(_email.text.trim().toLowerCase(), _password.text);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BoetePot – Inloggen')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isRegister)
                  TextField(
                    controller: _displayName,
                    decoration: const InputDecoration(labelText: 'Weergavenaam'),
                  ),
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'E-mailadres'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'Wachtwoord'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_isRegister ? 'Account aanmaken' : 'Inloggen'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _isRegister = !_isRegister),
                  child: Text(_isRegister ? 'Heb je al een account? Log in' : 'Nog geen account? Registreren'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
