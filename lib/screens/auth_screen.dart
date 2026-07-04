import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';
import '../src/app_state.dart';

enum _AuthMode { login, signup, forgotPassword }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  _AuthMode _mode = _AuthMode.login;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView(screenName: 'auth_screen');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.isEmpty || connectivity.contains(ConnectivityResult.none)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Please connect and try again.'),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    String message = 'Please try again.';
    bool success = false;

    try {
      if (_mode == _AuthMode.login) {
        final credential = await AuthService.signInWithEmail(email, password);
        if (credential?.user != null) {
          success = true;
          message = 'Welcome back!';
          await AnalyticsService.logEvent('auth_login', parameters: {
            'email': email,
          });
          await AnalyticsService.setUserId(credential!.user!.uid);
          Provider.of<AppState>(context, listen: false)
              .setAuthenticated(true, uid: credential.user!.uid);
        } else {
          message = 'Login failed. Check your email and password.';
        }
      } else if (_mode == _AuthMode.signup) {
        final credential = await AuthService.createUserWithEmail(email, password);
        if (credential?.user != null) {
          success = true;
          message = 'Account created successfully.';
          await AnalyticsService.logEvent('auth_signup', parameters: {
            'email': email,
          });
          await AnalyticsService.setUserId(credential!.user!.uid);
          Provider.of<AppState>(context, listen: false)
              .setAuthenticated(true, uid: credential.user!.uid);
        } else {
          message = AuthService.lastError ?? 'Sign up failed. Please try again.';
        }
      } else if (_mode == _AuthMode.forgotPassword) {
        final sent = await AuthService.sendPasswordResetEmail(email);
        if (sent) {
          success = true;
          message = 'Password reset email sent to $email.';
          await AnalyticsService.logEvent('auth_forgot_password', parameters: {
            'email': email,
          });
        } else {
          message = AuthService.lastError ?? 'Could not send password reset email. Please verify your email.';
        }
      }
    } catch (e) {
      message = 'Authentication error: $e';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  void _switchMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
    });
  }

  String _title() {
    switch (_mode) {
      case _AuthMode.login:
        return 'Sign In';
      case _AuthMode.signup:
        return 'Create Account';
      case _AuthMode.forgotPassword:
        return 'Reset Password';
    }
  }

  String _primaryButton() {
    switch (_mode) {
      case _AuthMode.login:
        return 'Login';
      case _AuthMode.signup:
        return 'Create Account';
      case _AuthMode.forgotPassword:
        return 'Send Reset Email';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_title()),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Silent SOS',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Secure your safety with a personal account. Sign in to restore your session or create a new account.',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!value.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_mode != _AuthMode.forgotPassword) ...[
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.length < 6) {
                              return 'Enter at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_mode == _AuthMode.signup) ...[
                        TextFormField(
                          controller: _confirmController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm Password',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(_primaryButton()),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_mode == _AuthMode.login)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => _switchMode(_AuthMode.forgotPassword),
                            child: const Text('Forgot password?'),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        children: [
                          if (_mode != _AuthMode.login)
                            TextButton(
                              onPressed: () => _switchMode(_AuthMode.login),
                              child: const Text('Already have an account? Login'),
                            ),
                          if (_mode != _AuthMode.signup)
                            TextButton(
                              onPressed: () => _switchMode(_AuthMode.signup),
                              child: const Text('Create new account'),
                            ),
                          if (_mode == _AuthMode.forgotPassword)
                            TextButton(
                              onPressed: () => _switchMode(_AuthMode.login),
                              child: const Text('Back to login'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
