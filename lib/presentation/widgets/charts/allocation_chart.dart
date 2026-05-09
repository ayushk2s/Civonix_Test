import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/portfolio.dart';

class AllocationPieChart extends StatefulWidget {
  final List<HoldingEntity> holdings;

  const AllocationPieChart({super.key, required this.holdings});

  @override
  State<AllocationPieChart> createState() => _AllocationPieChartState();
}

class _AllocationPieChartState extends State<AllocationPieChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final top = widget.holdings.take(7).toList();

    return Row(
      children: [
        SizedBox(
          width: 160,
          height: 160,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (_, resp) {
                  setState(() {
                    _touched = resp?.touchedSection?.touchedSectionIndex ?? -1;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: top.asMap().entries.map((e) {
                final isTouched = e.key == _touched;
                return PieChartSectionData(
                  color: AppColors.allocationColors[e.key % AppColors.allocationColors.length],
                  value: e.value.allocationPct * 100,
                  radius: isTouched ? 55 : 45,
                  title: '',
                  showTitle: false,
                );
              }).toList(),
            ),
            duration: const Duration(milliseconds: 300),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: top.asMap().entries.map((e) {
              final color = AppColors.allocationColors[e.key % AppColors.allocationColors.length];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.value.symbol,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      Fmt.pct(e.value.allocationPct, showSign: false),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
