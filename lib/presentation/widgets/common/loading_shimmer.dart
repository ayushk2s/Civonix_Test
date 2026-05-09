import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

class CivonixShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const CivonixShimmer({
    super.key,
    required this.width,
    required this.height,
    this.radius = AppSizes.radiusMd,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceHigh,
      highlightColor: AppColors.cardBorder,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceHigh,
      highlightColor: AppColors.cardBorder,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _box(double.infinity, 160),
            const SizedBox(height: AppSizes.md),
            Row(children: [
              Expanded(child: _box(double.infinity, 90)),
              const SizedBox(width: AppSizes.sm),
              Expanded(child: _box(double.infinity, 90)),
            ]),
            const SizedBox(height: AppSizes.md),
            _box(double.infinity, 200),
            const SizedBox(height: AppSizes.md),
            ...List.generate(4, (i) => Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.sm),
              child: _box(double.infinity, 70),
            )),
          ],
        ),
      ),
    );
  }

  Widget _box(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
      );
}

class AnalyticsShimmer extends StatelessWidget {
  const AnalyticsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceHigh,
      highlightColor: AppColors.cardBorder,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          children: [
            _box(double.infinity, 220),
            const SizedBox(height: AppSizes.md),
            ...List.generate(6, (i) => Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.sm),
              child: Row(children: [
                Expanded(child: _box(double.infinity, 90)),
                const SizedBox(width: AppSizes.sm),
                Expanded(child: _box(double.infinity, 90)),
              ]),
            )),
          ],
        ),
      ),
    );
  }

  Widget _box(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
      );
}
