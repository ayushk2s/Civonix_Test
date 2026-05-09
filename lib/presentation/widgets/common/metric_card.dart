import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

enum MetricCardVariant { neutral, gain, loss, warning }

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Widget? icon;
  final MetricCardVariant variant;
  final VoidCallback? onTap;
  final bool isCompact;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.variant = MetricCardVariant.neutral,
    this.onTap,
    this.isCompact = false,
  });

  Color get _valueColor {
    switch (variant) {
      case MetricCardVariant.gain:    return AppColors.gain;
      case MetricCardVariant.loss:    return AppColors.loss;
      case MetricCardVariant.warning: return AppColors.warning;
      case MetricCardVariant.neutral: return AppColors.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isCompact ? AppSizes.sm : AppSizes.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  icon!,
                  const SizedBox(width: AppSizes.xs),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: isCompact ? AppSizes.xs : AppSizes.sm),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _valueColor,
                    fontWeight: FontWeight.w700,
                    fontSize: isCompact ? 16 : 20,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final MetricCardVariant variant;
  final String? tooltip;

  const MetricRow({
    super.key,
    required this.label,
    required this.value,
    this.variant = MetricCardVariant.neutral,
    this.tooltip,
  });

  Color _color(BuildContext context) {
    switch (variant) {
      case MetricCardVariant.gain:    return AppColors.gain;
      case MetricCardVariant.loss:    return AppColors.loss;
      case MetricCardVariant.warning: return AppColors.warning;
      case MetricCardVariant.neutral: return AppColors.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _color(context),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
