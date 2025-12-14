import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  PhoneAuthScreenState createState() => PhoneAuthScreenState();
}

// Made public to avoid library_private_types_in_public_api analyzer info
class PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _verificationId;
  bool _codeSent = false;
  bool _loading = false;
  String? _message;

  void _showMessage(String msg) {
    setState(() => _message = msg);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showMessage('Enter phone number with country code (e.g. +91xxxxxxxxxx)');
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          _showMessage('Auto verification completed. Signing in...');
          try {
            await _auth.signInWithCredential(credential);
            _showMessage('Signed in successfully (auto).');
            setState(() {
              _codeSent = false;
            });
          } on FirebaseAuthException catch (e) {
            _showMessage('Auto sign-in failed: ${e.message}');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _showMessage('Verification failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          _showMessage('OTP sent to $phone');
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
          });
          _showMessage('Auto retrieval timeout. Enter code manually if you received it.');
        },
      );
    } catch (e) {
      _showMessage('Error sending code: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _otpController.text.trim();
    final vid = _verificationId;

    if (vid == null) {
      _showMessage('No verification ID — send OTP first.');
      return;
    }
    if (code.isEmpty) {
      _showMessage('Enter the OTP you received.');
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(verificationId: vid, smsCode: code);
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        _showMessage('Phone authentication successful! UID: ${user.uid}');
        setState(() {
          _codeSent = false;
        });
      } else {
        _showMessage('Sign in failed (null user).');
      }
    } on FirebaseAuthException catch (e) {
      _showMessage('Verification failed: ${e.message}');
    } catch (e) {
      _showMessage('Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    _showMessage('Signed out.');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Widget _buildPhoneInput() {
    return Column(
      children: [
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone (with country code)',
            hintText: '+91 9876543210',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.send),
          label: const Text('Send OTP'),
          onPressed: _loading ? null : _sendCode,
        ),
      ],
    );
  }

  Widget _buildOtpInput() {
    return Column(
      children: [
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Enter OTP',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Verify OTP'),
          onPressed: _loading ? null : _verifyCode,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _loading ? null : _sendCode,
          child: const Text('Resend OTP'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Phone OTP')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (user != null) ...[
              ListTile(
                leading: const Icon(Icons.verified_user),
                title: Text('Signed in: ${user.phoneNumber ?? user.uid}'),
                subtitle: Text('UID: ${user.uid}'),
              ),
              ElevatedButton(onPressed: _signOut, child: const Text('Sign out')),
              const Divider(),
            ],
            _codeSent ? _buildOtpInput() : _buildPhoneInput(),
            const SizedBox(height: 12),
            if (_loading) const CircularProgressIndicator(),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
