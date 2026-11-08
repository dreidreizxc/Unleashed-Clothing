import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Fades and lifts its child on first build. Used to give the storefront a
/// calm, editorial entrance without distracting motion.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 18,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> {
  double _t = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _start();
    } else {
      _timer = Timer(widget.delay, _start);
    }
  }

  void _start() {
    if (mounted) setState(() => _t = 1);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _t,
      duration: AppMotion.slow,
      curve: AppMotion.curve,
      child: AnimatedSlide(
        offset: Offset(0, (1 - _t) * widget.offset / 100),
        duration: AppMotion.slow,
        curve: AppMotion.curve,
        child: widget.child,
      ),
    );
  }
}

/// Small uppercase kicker used above headlines.
class Eyebrow extends StatelessWidget {
  const Eyebrow(
    this.text, {
    super.key,
    this.color = AppColors.muted,
    this.fontSize = 9.5,
    this.letterSpacing = 2.2,
  });

  final String text;
  final Color color;
  final double fontSize;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: letterSpacing,
        color: color,
        height: 1.2,
      ),
    );
  }
}

/// A burnt-orange square used as a typographic accent.
class AccentMark extends StatelessWidget {
  const AccentMark({super.key, this.size = 7, this.color = AppColors.accent});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: size, height: size, color: color);
  }
}

/// Editorial section heading with an optional trailing action.
class EditorialSectionHeader extends StatelessWidget {
  const EditorialSectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 30, 20, 14),
    this.accent = false,
  });

  final String eyebrow;
  final String title;
  final Widget? trailing;
  final EdgeInsets padding;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (accent) ...[
                      const AccentMark(),
                      const SizedBox(width: 7),
                    ],
                    Eyebrow(eyebrow),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    height: 0.98,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Slim outlined pill used for category / filter labels.
class OutlinePill extends StatelessWidget {
  const OutlinePill({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? AppColors.ink : AppColors.line,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Sharp, bordered surface used for grouped content.
class EditorialPanel extends StatelessWidget {
  const EditorialPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.surface,
    this.borderColor = AppColors.line,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

/// Brand header used on the storefront tabs.
class EditorialHeader extends StatelessWidget {
  const EditorialHeader({
    super.key,
    this.actions = const [],
    this.showTagline = true,
  });

  final List<Widget> actions;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.paper,
      padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  AccentMark(size: 6),
                  SizedBox(width: 6),
                  Text(
                    'RIZAL',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2),
              Text(
                'UNLEASHED',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  height: 0.95,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}

/// Animated shimmer placeholder used while product imagery or lists load.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 0,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 2, 0),
              end: Alignment(1 + t * 2, 0),
              colors: const [
                AppColors.subtle,
                Color(0xFFE2DED8),
                AppColors.subtle,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Editorial loading state with skeletons that mirror the product grid.
class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 18,
        childAspectRatio: 0.56,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: SkeletonBox(height: double.infinity),
            ),
            SizedBox(height: 10),
            SkeletonBox(width: 120, height: 12),
            SizedBox(height: 8),
            SkeletonBox(width: 64, height: 12),
          ],
        );
      },
    );
  }
}

/// A large editorial statement block used for headers on secondary screens.
class EditorialPageIntro extends StatelessWidget {
  const EditorialPageIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    this.description,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(eyebrow, color: AppColors.muted),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.3,
                    height: 0.96,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    description!,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// Thin rule with an optional inset.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0, this.color = AppColors.line});

  final double indent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: indent),
      child: Container(height: 1, color: color),
    );
  }
}

/// Small status dot with label, used for live availability.
class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    required this.label,
    this.color = AppColors.success,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
            color: color,
          ),
        ),
      ],
    );
  }
}
