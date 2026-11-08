import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/editorial.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
    this.showBack = false,
    this.eyebrow,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? footer;
  final bool showBack;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
              children: [
                Row(
                  children: [
                    if (showBack)
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        tooltip: 'Back',
                      )
                    else
                      const AccentMark(size: 7),
                    const Spacer(),
                    const AppWordmark(fontSize: 14),
                  ],
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.ink),
                  ),
                  child: Text(
                    (eyebrow ?? 'Unleashed Clothing').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                    height: 0.9,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.6,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 26),
                const Hairline(),
                const SizedBox(height: 26),
                ...children,
                if (footer != null) ...[const SizedBox(height: 28), footer!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline error banner used by the authentication forms.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE9E7),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.autofillHints,
    this.helperText,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final VoidCallback? onFieldSubmitted;
  final Iterable<String>? autofillHints;
  final String? helperText;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: (_) => widget.onFieldSubmitted?.call(),
      autofillHints: widget.autofillHints,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        prefixIcon: const Icon(Icons.lock_outline, size: 19),
        suffixIcon: IconButton(
          tooltip: _obscured ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _obscured = !_obscured),
          icon: Icon(
            _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 19,
          ),
        ),
      ),
    );
  }
}
