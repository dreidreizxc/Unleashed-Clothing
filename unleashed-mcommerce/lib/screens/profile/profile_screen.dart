import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/errors.dart';
import '../../core/formatters.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/profile_photo_service.dart';
import '../../state/app_state.dart';
import '../../state/shell_tabs.dart';
import '../../widgets/common.dart';
import '../../widgets/editorial.dart';
import '../../widgets/profile_avatar.dart';
import '../chat/chat_screen.dart';
import 'edit_profile_screen.dart';
import 'transactions_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await confirmAction(
      context,
      title: 'Sign out?',
      message:
          'Your cart and orders stay safely on your account. You can sign '
          'back in at any time.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await AppState.instance.signOut();
    } catch (_) {
      if (context.mounted) {
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
    return AppStateBuilder(
      builder: (context, state) {
        final profile = state.profile;
        if (profile == null) {
          if (state.isGuest) {
            return Scaffold(
              backgroundColor: AppColors.paper,
              appBar: AppBar(title: const Text('PROFILE')),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Container(
                    width: double.infinity,
                    color: AppColors.ink,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            AccentMark(size: 6),
                            SizedBox(width: 7),
                            Eyebrow('Guest session', color: Colors.white70),
                            Spacer(),
                            Text(
                              'RIZAL',
                              style: TextStyle(
                                fontSize: 7.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.person_outline,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'GUEST',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.4,
                            height: 0.95,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Browse and shop freely. Sign in only when you are '
                          'ready to check out or want order updates.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.55,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _Notice(
                    message:
                        'Your guest cart is saved on this device. Signing in '
                        'moves it to your account without losing any items.',
                  ),
                  const SizedBox(height: 20),
                  const SectionHeader(
                    title: 'Why sign in?',
                    padding: EdgeInsets.only(bottom: 8),
                  ),
                  const _MenuCard(
                    children: [
                      _GuestBenefit(
                        icon: Icons.receipt_long_outlined,
                        title: 'Order history',
                        subtitle: 'Track every delivery and reorder faster.',
                      ),
                      _GuestBenefit(
                        icon: Icons.notifications_none,
                        title: 'Private alerts',
                        subtitle: 'Get updates about your own orders only.',
                      ),
                      _GuestBenefit(
                        icon: Icons.chat_bubble_outline,
                        title: 'Store messages',
                        subtitle:
                            'Chat directly with the store about an order.',
                        last: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Sign in or create account',
                    icon: Icons.login,
                    onPressed: () => state.requestSignIn(
                      message:
                          'Sign in or create an account to place orders and '
                          'track deliveries. Your guest cart will come with '
                          'you.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Unleashed Clothing Â· Philippines',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.6,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            );
          }
          if (state.profileLoading) {
            return Scaffold(
              appBar: AppBar(title: const Text('PROFILE')),
              body: const AppStateView.loading(
                message: 'Loading your profileâ€¦',
              ),
            );
          }
          return Scaffold(
            appBar: AppBar(title: const Text('PROFILE')),
            body: AppStateView.error(
              title: 'Your profile is unavailable',
              message:
                  state.profileError ??
                  'Your profile could not be loaded. Check your connection and '
                      'try again.',
              onAction: state.refreshProfile,
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.paper,
          appBar: AppBar(
            title: const Text('PROFILE'),
            actions: [
              IconButton(
                tooltip: 'Refresh profile',
                onPressed: state.profileLoading ? null : state.refreshProfile,
                icon: const Icon(Icons.refresh, size: 20),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: state.refreshProfile,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (state.profileError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _Notice(message: state.profileError!),
                  ),
                _ProfileHeader(profile: profile),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          label: 'ORDERS',
                          value: '${profile.totalOrders}',
                        ),
                      ),
                      Container(width: 1, height: 38, color: AppColors.line),
                      Expanded(
                        child: _Stat(
                          label: 'LIFETIME SPEND',
                          value: formatCompactMoney(profile.totalSpent),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionHeader(
                  title: 'Email verification',
                  padding: EdgeInsets.only(bottom: 8),
                ),
                _EmailVerificationCard(
                  email: profile.email,
                  initiallyVerified: state.user?.emailVerified ?? false,
                ),
                const SizedBox(height: 20),
                const SectionHeader(
                  title: 'Account',
                  padding: EdgeInsets.only(bottom: 8),
                ),
                _MenuCard(
                  children: [
                    _MenuTile(
                      icon: Icons.person_outline,
                      title: 'Edit profile',
                      subtitle: 'Name, contact number, birthday and address',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      ),
                    ),
                    _MenuTile(
                      icon: Icons.receipt_long_outlined,
                      title: 'Order history',
                      subtitle: 'Track deliveries and review purchases',
                      trailing: '${profile.totalOrders}',
                      onTap: () => ShellTabs.go(ShellTabs.orders),
                    ),
                    _MenuTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Transaction history',
                      subtitle: 'Payments, COD references and simulations',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TransactionsScreen(),
                        ),
                      ),
                    ),
                    _MenuTile(
                      icon: Icons.chat_bubble_outline,
                      title: 'Messages',
                      subtitle: 'Talk directly to the store',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ChatScreen()),
                      ),
                    ),
                    _MenuTile(
                      icon: Icons.notifications_none,
                      title: 'Notifications',
                      subtitle: 'Order updates and store replies',
                      trailing: state.unreadNotifications > 0
                          ? '${state.unreadNotifications}'
                          : null,
                      onTap: () => ShellTabs.go(ShellTabs.notifications),
                      last: true,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const SectionHeader(
                  title: 'Delivery details',
                  padding: EdgeInsets.only(bottom: 8),
                ),
                _DetailCard(
                  children: [
                    KeyValueRow('Contact', profile.contactNumber),
                    KeyValueRow('Email', profile.email),
                    KeyValueRow('Birthday', formatDate(profile.birthday)),
                    KeyValueRow(
                      'Address',
                      profile.address.isComplete
                          ? profile.address.singleLine
                          : 'Incomplete â€” add your delivery address',
                      valueColor: profile.address.isComplete
                          ? null
                          : AppColors.danger,
                    ),
                    KeyValueRow('Member since', formatDate(profile.createdAt)),
                  ],
                ),
                if (!profile.address.isComplete) ...[
                  const SizedBox(height: 12),
                  _Notice(
                    message:
                        'Your delivery address is incomplete. Orders cannot be '
                        'placed until it is complete.',
                    actionLabel: 'Complete address',
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Sign out',
                  outlined: true,
                  icon: Icons.logout,
                  onPressed: () => _signOut(context),
                ),
                const SizedBox(height: 14),
                Text(
                  '${profile.email}\nUnleashed Clothing Â· Philippines',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.6,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileHeader extends StatefulWidget {
  const _ProfileHeader({required this.profile});

  final UserProfile profile;

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  bool _busy = false;
  double _progress = 0;
  String _busyLabel = '';

  bool get _hasPhoto => (widget.profile.photoUrl ?? '').trim().isNotEmpty;

  void _setBusy(String label, double progress) {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _busyLabel = label;
      _progress = progress;
    });
  }

  void _clearBusy() {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _busyLabel = '';
      _progress = 0;
    });
  }

  Future<void> _showPhotoMenu() async {
    if (_busy) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Eyebrow('Profile photo'),
              ),
              _PhotoAction(
                icon: Icons.photo_camera_outlined,
                label: 'Change profile photo',
                onTap: () => Navigator.of(sheetContext).pop('change'),
              ),
              if (_hasPhoto)
                _PhotoAction(
                  icon: Icons.delete_outline,
                  label: 'Remove profile photo',
                  destructive: true,
                  onTap: () => Navigator.of(sheetContext).pop('remove'),
                ),
              const Divider(height: 1),
              _PhotoAction(
                icon: Icons.close,
                label: 'Cancel',
                muted: true,
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    if (action == 'change') {
      await _changePhoto();
    } else if (action == 'remove') {
      await _removePhoto();
    }
  }

  Future<void> _changePhoto() async {
    _setBusy('Opening gallery', 0.05);
    try {
      final prepared = await ProfilePhotoService.instance.pickFromGallery(
        onProgress: (progress, label) => _setBusy(label, progress),
      );
      if (!mounted) return;
      if (prepared == null) {
        _clearBusy();
        return;
      }

      _setBusy('Review photo', 0.9);
      final confirmed = await _confirmPreview(prepared);
      if (!mounted) return;
      if (confirmed != true) {
        _clearBusy();
        return;
      }

      _setBusy('Saving photo', 0.95);
      await AppState.instance.setProfilePhoto(prepared.dataUri);
      if (!mounted) return;
      setState(() => _progress = 1);
      showAppSnack(context, 'Your profile photo has been updated.');
    } on ProfilePhotoException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } on AuthFailure catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (error, stack) {
      logTechnicalError('profile.photo.change', error, stack);
      if (mounted) {
        showAppSnack(
          context,
          'Your profile photo could not be updated. Please try again.',
          error: true,
        );
      }
    } finally {
      _clearBusy();
    }
  }

  Future<bool?> _confirmPreview(PreparedProfilePhoto photo) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Use this photo?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: AppColors.ink,
              padding: const EdgeInsets.all(18),
              child: Center(
                child: ClipOval(
                  child: Image.memory(
                    photo.bytes,
                    width: 170,
                    height: 170,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'JPG or PNG · ${(photo.bytes.length / 1024).round()} KB · '
              'resized to ${ProfilePhotoService.targetDimension} px',
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('USE PHOTO'),
          ),
        ],
      ),
    );
  }

  Future<void> _removePhoto() async {
    final confirmed = await confirmAction(
      context,
      title: 'Remove profile photo?',
      message:
          'Your initials will be shown instead. You can add a new photo at '
          'any time.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    _setBusy('Removing photo', 0.5);
    try {
      await AppState.instance.setProfilePhoto(null);
      if (mounted) {
        showAppSnack(context, 'Your profile photo has been removed.');
      }
    } on AuthFailure catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (error, stack) {
      logTechnicalError('profile.photo.remove', error, stack);
      if (mounted) {
        showAppSnack(
          context,
          'Your profile photo could not be removed. Please try again.',
          error: true,
        );
      }
    } finally {
      _clearBusy();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return Container(
      width: double.infinity,
      color: AppColors.ink,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              AccentMark(size: 6),
              SizedBox(width: 7),
              Eyebrow('Account', color: Colors.white70),
              Spacer(),
              Text(
                'UNLEASHED',
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProfileAvatar(
                photoUrl: profile.photoUrl,
                initials: profile.initials,
                size: 68,
                onTap: _showPhotoMenu,
                borderColor: Colors.white.withValues(alpha: 0.4),
                fallbackColor: Colors.white.withValues(alpha: 0.08),
                initialsColor: Colors.white,
                badgeColor: AppColors.surface,
                badgeIconColor: AppColors.ink,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.02,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      profile.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'CUSTOMER',
              style: TextStyle(
                fontSize: 7.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
                color: Colors.white,
              ),
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _busyLabel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                Text(
                  '${(_progress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: _progress <= 0
                  ? null
                  : _progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 2,
              color: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.24),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoAction extends StatelessWidget {
  const _PhotoAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? AppColors.accent
        : muted
        ? AppColors.muted
        : AppColors.ink;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailVerificationCard extends StatefulWidget {
  const _EmailVerificationCard({
    required this.email,
    required this.initiallyVerified,
  });

  final String email;
  final bool initiallyVerified;

  @override
  State<_EmailVerificationCard> createState() => _EmailVerificationCardState();
}

class _EmailVerificationCardState extends State<_EmailVerificationCard> {
  static const int _cooldownSeconds = 60;

  late bool _verified;
  bool _sending = false;
  bool _checking = false;
  bool _sentOnce = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _verified =
        widget.initiallyVerified ||
        (AppState.instance.user?.emailVerified ?? false);
  }

  @override
  void didUpdateWidget(covariant _EmailVerificationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyVerified && !_verified) {
      _verified = true;
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = _cooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown -= 1);
      }
    });
  }

  Future<void> _send() async {
    if (_sending || _cooldown > 0) return;
    setState(() => _sending = true);
    try {
      await AppState.instance.sendVerificationEmail();
      if (!mounted) return;
      setState(() => _sentOnce = true);
      _startCooldown();
      showAppSnack(
        context,
        'Verification email sent to ${widget.email}. Check your inbox and '
        'spam folder.',
      );
    } on AuthFailure catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (error, stack) {
      logTechnicalError('profile.emailVerification.send', error, stack);
      if (mounted) {
        showAppSnack(
          context,
          'The verification email could not be sent. Please try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final verified = await AppState.instance.reloadEmailVerified();
      if (!mounted) return;
      setState(() => _verified = verified);
      showAppSnack(
        context,
        verified
            ? 'Your email address is verified.'
            : 'Not verified yet. Open the link in your inbox, then refresh '
                  'again.',
        error: !verified,
      );
    } on AuthFailure catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (error, stack) {
      logTechnicalError('profile.emailVerification.check', error, stack);
      if (mounted) {
        showAppSnack(
          context,
          'Your verification status could not be refreshed. Please try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  color: _verified ? AppColors.ink : AppColors.subtle,
                  alignment: Alignment.center,
                  child: Icon(
                    _verified
                        ? Icons.mark_email_read_outlined
                        : Icons.mark_email_unread_outlined,
                    size: 16,
                    color: _verified ? Colors.white : AppColors.muted,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'EMAIL ADDRESS',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                _StatusPill(verified: _verified),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _verified
                      ? 'You have confirmed ownership of this email address.'
                      : 'Confirm your email to help secure your account. '
                            'Verification is optional and never blocks '
                            'checkout.',
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.5,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 16),
                if (!_verified) ...[
                  PrimaryButton(
                    label: _cooldown > 0
                        ? 'Resend in ${_cooldown}s'
                        : 'Send verification email',
                    icon: Icons.mail_outline,
                    loading: _sending,
                    onPressed: (_sending || _cooldown > 0) ? null : _send,
                  ),
                  const SizedBox(height: 10),
                ],
                PrimaryButton(
                  label: _verified
                      ? 'Refresh verification status'
                      : 'I have verified — refresh status',
                  icon: Icons.refresh,
                  outlined: true,
                  loading: _checking,
                  onPressed: _checking ? null : _check,
                ),
                if (_sentOnce && !_verified) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Open the link in your inbox (check spam too), then '
                    'refresh the status here. You can keep shopping while '
                    'unverified.',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: verified ? AppColors.ink : Colors.transparent,
        border: Border.all(color: verified ? AppColors.ink : AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.check : Icons.remove,
            size: 11,
            color: verified ? Colors.white : AppColors.muted,
          ),
          const SizedBox(width: 4),
          Text(
            verified ? 'VERIFIED' : 'NOT VERIFIED',
            style: TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: verified ? Colors.white : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(children: children),
    );
  }
}

class _GuestBenefit extends StatelessWidget {
  const _GuestBenefit({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.4,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? trailing;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.4,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: const BoxDecoration(color: AppColors.ink),
                child: Text(
                  trailing!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_outward, size: 16, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(children: children),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF1DE),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
