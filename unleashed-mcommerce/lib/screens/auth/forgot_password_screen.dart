import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/validators.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import 'auth_scaffold.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _submitting = false;
  String? _error;
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
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
      await AuthService.instance.sendPasswordReset(_email.text);
      if (mounted) setState(() => _sentTo = _email.text.trim().toLowerCase());
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'The reset email could not be sent. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      eyebrow: 'Password help',
      title: _sentTo == null ? 'Reset your\npassword.' : 'Check your\ninbox.',
      subtitle: _sentTo == null
          ? 'Enter the email you used to create your account. We will send a '
                'secure reset link from Firebase.'
          : 'If an account exists for $_sentTo, a password reset link is on the '
                'way. Check your spam folder if it does not arrive shortly.',
      children: _sentTo == null
          ? [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) AuthErrorBanner(message: _error!),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      validator: (value) => Validators.email(value),
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.alternate_email, size: 19),
                      ),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Send reset link',
                      accent: true,
                      loading: _submitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ]
          : [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      color: AppColors.ink,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'RESET LINK SENT',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Follow the link in the email to choose a new password, '
                      'then come back and sign in.',
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
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Back to sign in',
                accent: true,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: 'Use a different email',
                outlined: true,
                onPressed: () => setState(() {
                  _sentTo = null;
                  _error = null;
                }),
              ),
            ],
    );
  }
}
