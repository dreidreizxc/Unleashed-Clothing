import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/validators.dart';
import '../../models/user_profile.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/editorial.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
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

    final current = AppState.instance.profile;
    final user = AppState.instance.user;
    if (current == null || user == null) {
      setState(() => _error = 'Please sign in again to update your profile.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = UserProfile(
        uid: current.uid,
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
      if (!mounted) return;
      showAppSnack(context, 'Your profile has been updated.');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Your changes could not be saved. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = AppState.instance.profile?.email ?? '';
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('EDIT PROFILE'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              textStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
              ),
            ),
            child: const Text('SAVE'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Form(
        key: _formKey,
        child: AutofillGroup(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            children: [
              if (_error != null) ...[
                _Banner(message: _error!),
                const SizedBox(height: 16),
              ],
              const Eyebrow('Personal details'),
              const SizedBox(height: 12),
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
                initialValue: email,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  helperText:
                      'Contact the store if you need to change your sign-in email.',
                  prefixIcon: Icon(Icons.alternate_email, size: 19),
                ),
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
              const SizedBox(height: 22),
              const Eyebrow('Delivery address'),
              const SizedBox(height: 12),
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
                textInputAction: TextInputAction.done,
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
              const SizedBox(height: 26),
              PrimaryButton(
                label: 'Save changes',
                accent: true,
                loading: _saving,
                onPressed: _save,
              ),
              const SizedBox(height: 12),
              const Text(
                'Your address is used for delivery labels. Keep it complete so '
                'checkout is not blocked.',
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
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE9E7),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
