import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_config.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/validators.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import 'auth_scaffold.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _contact = TextEditingController();
  final _email = TextEditingController();
  final _street = TextEditingController();
  final _barangay = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();
  final _postal = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  DateTime? _birthday;
  String? _birthdayError;
  bool _acceptedTerms = false;
  bool _termsError = false;
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _middleName,
      _lastName,
      _contact,
      _email,
      _street,
      _barangay,
      _city,
      _province,
      _postal,
      _password,
      _confirm,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select your birthday',
    );
    if (picked == null) return;
    setState(() {
      _birthday = picked;
      _birthdayError = Validators.birthday(picked);
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final formValid = _formKey.currentState?.validate() ?? false;
    final birthdayError = Validators.birthday(_birthday);
    setState(() {
      _birthdayError = birthdayError;
      _termsError = !_acceptedTerms;
    });
    if (!formValid || birthdayError != null || !_acceptedTerms) {
      if (birthdayError != null || !_acceptedTerms) {
        showAppSnack(
          context,
          'Please complete your birthday and accept the store terms.',
          error: true,
        );
      }
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AppState.instance.register(
        RegistrationData(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          middleName: _middleName.text.trim(),
          contactNumber: _contact.text.trim(),
          email: _email.text.trim().toLowerCase(),
          birthday: _birthday!,
          address: PostalAddress(
            street: _street.text.trim(),
            barangay: _barangay.text.trim(),
            city: _city.text.trim(),
            province: _province.text.trim(),
            postalCode: _postal.text.trim(),
          ),
          password: _password.text,
        ),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Account created'),
          content: const Text(
            'Your account has been created successfully. Sign in to continue. Your guest cart '
            'and any checkout you started are still saved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Back to sign in'),
            ),
          ],
        ),
      );
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'We could not create your account. Check your connection and try again.',
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
      eyebrow: 'Create account',
      title: 'Join the\nUnleashed club.',
      subtitle:
          'One account for drops, orders and support. All fields are required '
          'unless marked optional.',
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) AuthErrorBanner(message: _error!),
                const _FormHeading('Personal details'),
                TextFormField(
                  controller: _firstName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.givenName],
                  validator: (value) => Validators.name(value, 'First name'),
                  decoration: const InputDecoration(labelText: 'First name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _middleName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: Validators.middleName,
                  decoration: const InputDecoration(
                    labelText: 'Middle name (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.familyName],
                  validator: (value) => Validators.name(value, 'Last name'),
                  decoration: const InputDecoration(labelText: 'Last name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contact,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                    LengthLimitingTextInputFormatter(16),
                  ],
                  validator: Validators.phone,
                  decoration: const InputDecoration(labelText: 'Mobile number'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) =>
                      Validators.email(value, requireGmail: true),
                  decoration: const InputDecoration(
                    labelText: 'Gmail address',
                    hintText: 'name@gmail.com',
                    helperText: 'A Gmail address is required for your account.',
                  ),
                ),
                const SizedBox(height: 18),
                const _FormHeading('Birthday'),
                InkWell(
                  onTap: _submitting ? null : _pickBirthday,
                  borderRadius: BorderRadius.circular(0),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date of birth',
                      errorText: _birthdayError,
                      prefixIcon: const Icon(Icons.cake_outlined, size: 19),
                      suffixIcon: const Icon(
                        Icons.calendar_today_outlined,
                        size: 17,
                      ),
                    ),
                    child: Text(
                      _birthday == null
                          ? 'Select your birthday'
                          : formatDate(_birthday),
                      style: TextStyle(
                        fontSize: 14,
                        color: _birthday == null
                            ? AppColors.muted
                            : AppColors.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const _FormHeading('Delivery address'),
                TextFormField(
                  controller: _street,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.streetAddressLine1],
                  validator: (value) =>
                      Validators.required(value, 'House number and street'),
                  decoration: const InputDecoration(
                    labelText: 'House number, building, street',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _barangay,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (value) => Validators.required(value, 'Barangay'),
                  decoration: const InputDecoration(labelText: 'Barangay'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _city,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      Validators.required(value, 'City or municipality'),
                  decoration: const InputDecoration(
                    labelText: 'City / municipality',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _province,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (value) => Validators.required(value, 'Province'),
                  decoration: const InputDecoration(labelText: 'Province'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _postal,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  validator: Validators.postalCode,
                  decoration: const InputDecoration(
                    labelText: 'Postal code',
                    hintText: '1000',
                  ),
                ),
                const SizedBox(height: 18),
                const _FormHeading('Account security'),
                TextFormField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) => Validators.password(
                    value,
                    minimumLength: AppConfig.minPasswordLength,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    helperText:
                        'At least ${AppConfig.minPasswordLength} characters with a letter and a number.',
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 19,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) =>
                      Validators.confirmPassword(value, _password.text),
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    suffixIcon: IconButton(
                      tooltip: _obscureConfirm
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 19,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _acceptedTerms,
                      activeColor: AppColors.ink,
                      onChanged: _submitting
                          ? null
                          : (value) => setState(() {
                              _acceptedTerms = value ?? false;
                              _termsError = false;
                            }),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'I agree to the store terms and privacy policy, and '
                          'confirm my delivery details are complete.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: _termsError
                                ? AppColors.danger
                                : AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Create account',
                  accent: true,
                  loading: _submitting,
                  onPressed: _submit,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your email and password are all you need to create an account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
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

class _FormHeading extends StatelessWidget {
  const _FormHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
          color: AppColors.muted,
        ),
      ),
    );
  }
}
