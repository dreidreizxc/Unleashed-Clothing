import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
    this.enabled = true,
    this.compact = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 30.0 : 38.0;
    final canDecrease = enabled && value > min;
    final canIncrease = enabled && value < max;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            size: size,
            onTap: canDecrease ? () => onChanged(value - 1) : null,
            semanticLabel: 'Decrease quantity',
          ),
          Container(
            constraints: BoxConstraints(minWidth: size),
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: compact ? 12 : 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            size: size,
            onTap: canIncrease ? () => onChanged(value + 1) : null,
            semanticLabel: 'Increase quantity',
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.size,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? AppColors.line : AppColors.ink,
          semanticLabel: semanticLabel,
        ),
      ),
    );
  }
}
