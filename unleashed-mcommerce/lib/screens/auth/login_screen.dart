import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/validators.dart';
import '../../services/auth_service.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import 'auth_scaffold.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.isPrompt = false});

  /// True when the screen replaces the storefront because a guest started
  /// checkout. In that mode the guest can return to browsing without losing
  /// their local cart.
  final bool isPrompt;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  bool _obscured = true;
  String? _error;

  bool get _busy => _submitting;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await AppState.instance.signIn(
        email: _email.text.trim().toLowerCase(),
        password: _password.text,
      );

      _password.clear();
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Sign-in failed. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _continueBrowsing() {
    AppState.instance.cancelAuthPrompt();
  }

  @override
  Widget build(BuildContext context) {
    final promptMessage = AppState.instance.authPromptMessage;
    return AuthScaffold(
      eyebrow: widget.isPrompt ? 'Secure checkout' : 'Welcome back',
      title: widget.isPrompt
          ? 'Sign in to\ncheck out.'
          : 'Your wardrobe\nis waiting.',
      subtitle: widget.isPrompt
          ? 'Your guest cart is saved on this device. Sign in or create an '
                'account to finish your order Ã¢â‚¬â€ we will bring your cart with '
                'you.'
          : 'Sign in to shop new drops, track orders and message the store.',
      footer: widget.isPrompt
          ? Column(
              children: [
                if (promptMessage != null) ...[
                  Text(
                    promptMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'New to Unleashed?',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            ),
                      child: const Text('Create account'),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _continueBrowsing,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Continue browsing as guest'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your cart stays on this device until you sign in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.45,
                    color: AppColors.muted,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'New to Unleashed?',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        ),
                  child: const Text('Create account'),
                ),
              ],
            ),
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) AuthErrorBanner(message: _error!),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  validator: (value) => Validators.email(value),
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.alternate_email, size: 19),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscured,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: (value) => Validators.required(value, 'Password'),
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 19),
                    suffixIcon: IconButton(
                      tooltip: _obscured ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _obscured = !_obscured),
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 19,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          ),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: 'Sign in',
                  accent: true,
                  loading: _submitting,
                  onPressed: _busy ? null : _submit,
                ),
                const SizedBox(height: 18),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'SECURE CHECKOUT',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Your cart, orders and messages stay tied to your account. '
                  'Never share your password with anyone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
