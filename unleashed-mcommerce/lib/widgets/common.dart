import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../state/app_state.dart';
import 'editorial.dart';

/// Rebuilds whenever the global [AppState] changes.
class AppStateBuilder extends StatelessWidget {
  const AppStateBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, AppState state) builder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) => builder(context, AppState.instance),
    );
  }
}

/// Compact UNLEASHED wordmark used in app bars.
class AppWordmark extends StatelessWidget {
  const AppWordmark({super.key, this.fontSize = 17, this.onDark = false});

  final double fontSize;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = onDark ? Colors.white : AppColors.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: fontSize * 0.28,
          height: fontSize * 0.28,
          color: onDark ? Colors.white : AppColors.accent,
        ),
        const SizedBox(width: 8),
        Text(
          'UNLEASHED',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.6,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Section heading kept for compatibility; renders the editorial variant.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 12),
    this.eyebrow = '',
  });

  final String title;
  final Widget? trailing;
  final EdgeInsets padding;
  final String eyebrow;

  @override
  Widget build(BuildContext context) {
    return EditorialSectionHeader(
      eyebrow: eyebrow.isEmpty ? 'UNLEASHED' : eyebrow,
      title: title,
      trailing: trailing,
      padding: padding,
      accent: eyebrow.isEmpty,
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.outlined = false,
    this.expand = true,
    this.accent = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool outlined;
  final bool expand;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final spinnerColor = outlined ? AppColors.ink : Colors.white;
    final child = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: spinnerColor,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17),
                const SizedBox(width: 9),
              ],
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final button = outlined
        ? OutlinedButton(
            onPressed: loading ? null : onPressed,
            child: child,
          )
        : ElevatedButton(
            onPressed: loading ? null : onPressed,
            style: accent
                ? ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.line,
                    disabledForegroundColor: AppColors.muted,
                  )
                : null,
            child: child,
          );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class AppStateView extends StatelessWidget {
  const AppStateView.loading({super.key, this.message = 'Loading…'})
    : icon = null,
      title = null,
      actionLabel = null,
      onAction = null,
      isError = false;

  const AppStateView.empty({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  }) : isError = false;

  const AppStateView.error({
    super.key,
    this.title = 'Something went wrong',
    this.message,
    this.actionLabel = 'Try again',
    this.onAction,
  }) : icon = Icons.cloud_off_outlined,
       isError = true;

  final IconData? icon;
  final String? title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  bool get _isLoading => icon == null && title == null && !isError;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            ),
            const SizedBox(height: 16),
            Eyebrow(message ?? 'LOADING', color: AppColors.muted),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : 320,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 40, 32, 56),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: isError
                            ? AppColors.danger.withValues(alpha: 0.07)
                            : AppColors.ink,
                      ),
                      child: Icon(
                        icon ?? Icons.inbox_outlined,
                        size: 30,
                        color: isError ? AppColors.danger : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      (title ?? '').toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.05,
                      ),
                    ),
                    if (message != null && message!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.55,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(height: 26),
                      SizedBox(
                        width: 210,
                        child: PrimaryButton(
                          label: actionLabel!,
                          onPressed: onAction,
                          outlined: isError,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

void showAppSnack(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: error ? AppColors.accent : Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              error ? Icons.close : Icons.check,
              size: 12,
              color: error ? Colors.white : AppColors.ink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
      duration: Duration(seconds: error ? 4 : 3),
    ),
  );
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel.toUpperCase()),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: destructive ? AppColors.accent : AppColors.ink,
          ),
          child: Text(confirmLabel.toUpperCase()),
        ),
      ],
    ),
  );
  return result ?? false;
}

class KeyValueRow extends StatelessWidget {
  const KeyValueRow(
    this.label,
    this.value, {
    super.key,
    this.valueColor,
    this.strong = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: AppColors.muted,
                height: 1.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: strong ? 16 : 13,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
                color: valueColor ?? AppColors.ink,
                height: 1.35,
                letterSpacing: strong ? -0.4 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.helper,
  });

  final String label;
  final Widget child;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 7),
        child,
        if (helper != null) ...[
          const SizedBox(height: 5),
          Text(helper!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}
