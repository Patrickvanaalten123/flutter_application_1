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

  Future<void> _forgotPassword() async {
    final emailController = TextEditingController(text: _email.text.trim());
    final email = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wachtwoord vergeten'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'E-mailadres'),
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(emailController.text),
            child: const Text('Stuur e-mail'),
          ),
        ],
      ),
    );
    if (email == null) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.sendPasswordResetEmail(email);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Als er een account bestaat voor dit e-mailadres, is er een e-mail verstuurd om je wachtwoord opnieuw in te stellen.',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      // Avoid account enumeration: only show a specific error for invalid email.
      if (e.code == 'invalid-email') {
        setState(() => _error = 'Vul een geldig e-mailadres in.');
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Als er een account bestaat voor dit e-mailadres, is er een e-mail verstuurd om je wachtwoord opnieuw in te stellen.',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
                if (!_isRegister)
                  TextButton(
                    onPressed: _busy ? null : _forgotPassword,
                    child: const Text('Wachtwoord vergeten?'),
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
