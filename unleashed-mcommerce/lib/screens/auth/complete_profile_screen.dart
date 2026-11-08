import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/validators.dart';
import '../../models/user_profile.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/editorial.dart';
import 'auth_scaffold.dart';

/// Collects any delivery details missing from an account profile.
///
/// [AuthGate] shows this screen before the main shell while
/// `UserProfile.needsCompletion` is true. Saving sets the profile on
/// [AppState], which immediately rebuilds the gate into the storefront.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _contact = TextEditingController();
  final _street = TextEditingController();
  final _barangay = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();
  final _postal = TextEditingController();

  DateTime? _birthday;
  String? _birthdayError;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = AppState.instance.profile;
    if (profile != null) {
      _firstName.text = profile.firstName;
      _middleName.text = profile.middleName ?? '';
      _lastName.text = profile.lastName;
      _contact.text = profile.contactNumber;
      _street.text = profile.address.street;
      _barangay.text = profile.address.barangay;
      _city.text = profile.address.city;
      _province.text = profile.address.province;
      _postal.text = profile.address.postalCode;
      _birthday = profile.birthday;
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _middleName,
      _lastName,
      _contact,
      _street,
      _barangay,
      _city,
      _province,
      _postal,
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

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final formValid = _formKey.currentState?.validate() ?? false;
    final birthdayError = Validators.birthday(_birthday);
    setState(() => _birthdayError = birthdayError);
    if (!formValid || birthdayError != null) {
      if (birthdayError != null) {
        showAppSnack(context, birthdayError, error: true);
      }
      return;
    }

    final user = AppState.instance.user;
    final current = AppState.instance.profile;
    if (user == null || current == null) {
      setState(() => _error = 'Please sign in again to finish your profile.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = UserProfile(
        uid: user.uid,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        middleName: _middleName.text.trim().isEmpty
            ? null
            : _middleName.text.trim(),
        contactNumber: Validators.normalisePhone(_contact.text.trim()),
        email: current.email.isEmpty
            ? (user.email ?? '').toLowerCase()
            : current.email,
        birthday: _birthday,
        address: PostalAddress(
          street: _street.text.trim(),
          barangay: _barangay.text.trim(),
          city: _city.text.trim(),
          province: _province.text.trim(),
          postalCode: _postal.text.trim(),
        ),
        role: current.role,
        totalOrders: current.totalOrders,
        totalSpent: current.totalSpent,
        photoUrl: current.photoUrl,
        createdAt: current.createdAt,
        updatedAt: current.updatedAt,
        isActive: current.isActive,
      );
      await AppState.instance.saveProfile(updated);
      if (mounted) showAppSnack(context, 'Your profile is complete.');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Your details could not be saved. Check your connection and try '
              'again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await AppState.instance.signOut();
    } catch (_) {
      if (mounted) {
        showAppSnack(
          context,
          'Could not sign out. Please try again.',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email =
        AppState.instance.profile?.email ?? AppState.instance.user?.email ?? '';
    return AuthScaffold(
      eyebrow: 'Almost there',
      title: 'Finish your\nprofile.',
      subtitle:
          'Add the delivery details needed to place an order. Your guest cart '
          'will be waiting.',
      footer: TextButton.icon(
        onPressed: _saving ? null : _signOut,
        icon: const Icon(Icons.logout, size: 16),
        label: const Text('Sign out'),
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
                  initialValue: email,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.alternate_email, size: 19),
                    helperText: 'From your account.',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _firstName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
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
                  validator: (value) => Validators.name(value, 'Last name'),
                  decoration: const InputDecoration(labelText: 'Last name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contact,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                    LengthLimitingTextInputFormatter(16),
                  ],
                  validator: Validators.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    hintText: '09171234567',
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _saving ? null : _pickBirthday,
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
                const Eyebrow('Delivery address'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _street,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
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
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  validator: Validators.postalCode,
                  onFieldSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'Postal code',
                    hintText: '1000',
                  ),
                ),
                const SizedBox(height: 22),
                PrimaryButton(
                  label: 'Save and continue',
                  accent: true,
                  loading: _saving,
                  onPressed: _save,
                ),
                const SizedBox(height: 12),
                const Text(
                  'You can change these details any time from your profile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
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
