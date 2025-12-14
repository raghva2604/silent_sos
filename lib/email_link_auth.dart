import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class EmailLinkAuthPage extends StatefulWidget {
  final bool testMode;
  const EmailLinkAuthPage({super.key, this.testMode = false});

  @override
  State<EmailLinkAuthPage> createState() => _EmailLinkAuthPageState();
}

class _EmailLinkAuthPageState extends State<EmailLinkAuthPage> {
  FirebaseAuth? _auth;
  final _emailController = TextEditingController();
  final TextEditingController _debugLinkController = TextEditingController();

  String? _message;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _auth = widget.testMode ? null : FirebaseAuth.instance;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedEmail();
      _handleIncomingLink();
    });
  }
  // NOTE: To integrate Firebase Dynamic Links for mobile deep-link handling,
  // add `firebase_dynamic_links` to `pubspec.yaml` and implement listeners.
  // Example (once you add the dependency):
  //
  // final PendingDynamicLinkData? initialLink = await FirebaseDynamicLinks.instance.getInitialLink();
  // if (initialLink?.link != null) await _handleIncomingLink(linkOverride: initialLink!.link.toString());
  // FirebaseDynamicLinks.instance.onLink.listen((dynamicLinkData) async {
  //   await _handleIncomingLink(linkOverride: dynamicLinkData.link.toString());
  // });
  //
  // I attempted to add `firebase_dynamic_links` but the project's current
  // `firebase_core` and other plugins are not compatible with available
  // `firebase_dynamic_links` versions. If you want me to try again and
  // upgrade/downgrade firebase packages, tell me and I'll attempt to resolve
  // the version solver by adjusting `pubspec.yaml`.

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('email_for_signin');
    if (s != null && s.isNotEmpty) setState(() => _savedEmail = s);
  }

  String? _savedEmail;

  // If you want to support Firebase Dynamic Links for mobile deep-links,
  // add `firebase_dynamic_links` to pubspec.yaml and implement a listener
  // similar to the following (example, do NOT include here unless you add the package):
  //
  // final PendingDynamicLinkData? initialLink = await FirebaseDynamicLinks.instance.getInitialLink();
  // if (initialLink?.link != null) await _handleIncomingLink(linkOverride: initialLink!.link.toString());
  // FirebaseDynamicLinks.instance.onLink.listen((dynamicLinkData) async {
  //   await _handleIncomingLink(linkOverride: dynamicLinkData.link.toString());
  // });

  Future<void> _handleIncomingLink({String? linkOverride}) async {
    try {
      if (widget.testMode) {
        // In test mode, treat any non-empty override as a successful sign-in.
        final link = linkOverride ?? Uri.base.toString();
        if (link.isEmpty) return;
        final prefs = await SharedPreferences.getInstance();
        final storedEmail = prefs.getString('email_for_signin') ?? '';
        if (storedEmail.isEmpty) {
          _setMsg('Open the link from the same device where you requested it, or store the email locally.');
          return;
        }
        // Simulate a short delay like a network call
        await Future.delayed(const Duration(milliseconds: 250));
        _setMsg('Test sign-in completed for $storedEmail');
        return;
      }

      final link = linkOverride ?? Uri.base.toString();
      final isLink = _auth!.isSignInWithEmailLink(link);
      if (!isLink) return;

      final prefs = await SharedPreferences.getInstance();
      final storedEmail = prefs.getString('email_for_signin') ?? '';
      if (storedEmail.isEmpty) {
        _setMsg('Open the link from the same device where you requested it, or store the email locally.');
        return;
      }

      final result = await _auth!.signInWithEmailLink(email: storedEmail, emailLink: link);
      _setMsg('Signed in: ${result.user?.uid}');
    } catch (e) {
      if (e is FirebaseAuthException) {
        _setMsg('Sign-in failed: ${e.message}');
      } else {
        _setMsg('Sign-in error: $e');
      }
    }
  }

  // Debug helper: simulate an incoming link for local development
  Future<void> _simulateIncomingLink(String link) async {
    await _handleIncomingLink(linkOverride: link);
  }

  void _setMsg(String m) => setState(() => _message = m);

  Future<void> _sendSignInLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _setMsg('Enter an email.');
      return;
    }

    setState(() => _loading = true);

    final actionCodeSettings = ActionCodeSettings(
      url: 'https://your-app.example.com/finishSignIn',
      handleCodeInApp: true,
      iOSBundleId: 'com.example.ios',
      androidPackageName: 'com.example.android',
      androidInstallApp: true,
      androidMinimumVersion: '12',
    );

    try {
      if (widget.testMode) {
        // In test mode we don't call Firebase; just persist and show a message.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('email_for_signin', email);
        _setMsg('Test sign-in link sent to $email. Open it on the same device to complete sign-in.');
      } else {
        await _auth!.sendSignInLinkToEmail(email: email, actionCodeSettings: actionCodeSettings);
        // Persist the email so it can be used when the app opens via the link
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('email_for_signin', email);
        _setMsg('Sign-in link sent to $email. Open it on the same device to complete sign-in.');
      }
    } on FirebaseAuthException catch (e) {
      _setMsg('Failed to send link: ${e.message}');
    } catch (e) {
      _setMsg('Failed to send link: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    if (_auth != null) await _auth!.signOut();
    _setMsg('Signed out.');
    setState(() {});
  }

  @override
  void dispose() {
    _emailController.dispose();
    _debugLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth?.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Email Link OTP (Passwordless)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          if (user != null)
            ListTile(
              leading: const Icon(Icons.verified_user),
              title: Text('Signed in: ${user.email ?? user.uid}'),
              subtitle: Text('UID: ${user.uid}'),
            ),
          if (user != null)
            ElevatedButton.icon(onPressed: _signOut, icon: const Icon(Icons.logout), label: const Text('Sign out')),
          const SizedBox(height: 12),
          if (_savedEmail != null) Card(color: Colors.green.shade700, child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [const Icon(Icons.info_outline, color: Colors.white), const SizedBox(width:8), Expanded(child: Text('Stored email for sign-in: ')), Text(_savedEmail!, style: const TextStyle(fontWeight: FontWeight.bold))]))),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading ? null : _sendSignInLink,
            child: _loading ? const CircularProgressIndicator() : const Text('Send Sign-in Link (OTP via email link)'),
          ),
          const SizedBox(height: 12),
          if (kDebugMode) ...[
            const Divider(),
            const Text('Debug / testing helpers', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _debugLinkController,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Simulate incoming link (paste link here)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: () => _simulateIncomingLink(_debugLinkController.text.trim()), child: const Text('Simulate incoming link')),
          ],
          const SizedBox(height: 12),
          if (_message != null) Text(_message!),
        ]),
      ),
    );
  }
}
