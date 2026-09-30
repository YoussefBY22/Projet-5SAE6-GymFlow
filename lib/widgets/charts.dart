import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/theme.dart';

/// Graphiques fl_chart aux couleurs GymFlow (infobulles marine, texte blanc).

/// Pas de graduation « rond » (1, 2, 5, 10, 20, 50…) pour ~4 graduations.
double niceInterval(double range) {
  final raw = range / 4;
  if (raw <= 1) return 1;
  final magnitude = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  for (final m in const [1, 2, 5, 10]) {
    if (raw <= m * magnitude) return m * magnitude;
  }
  return 10 * magnitude;
}

/// Libellé d'axe masqué au bord haut (évite les chevauchements).
Widget _axisLabel(double v, TitleMeta meta, String text) {
  if (v == meta.max) return const SizedBox.shrink();
  return SideTitleWidget(
    meta: meta,
    child: Text(text, style: AppText.label(size: 10)),
  );
}

FlGridData _grid(double interval) => FlGridData(
  drawVerticalLine: false,
  horizontalInterval: interval,
  getDrawingHorizontalLine: (_) =>
      const FlLine(color: AppColors.divider, strokeWidth: 1),
);

/// Courbe temporelle (poids, inscriptions…).
class GfLineChart extends StatelessWidget {
  const GfLineChart({
    super.key,
    required this.points,
    this.unit = '',
    this.height = 200,
    this.color = AppColors.red,
  });

  final List<(DateTime, double)> points;
  final String unit;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return SizedBox(
        height: height / 2,
        child: Center(
          child: Text('Pas encore assez de données', style: AppText.label()),
        ),
      );
    }
    final values = points.map((p) => p.$2);
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final interval = niceInterval(math.max(1, maxV - minV) * 1.4);
    final minY = ((minV - interval * 0.5) / interval).floor() * interval;
    final maxY = ((maxV + interval * 0.5) / interval).ceil() * interval;
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: math.max(0, minY),
          maxY: maxY,
          gridData: _grid(interval),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: interval,
                getTitlesWidget: (v, meta) =>
                    _axisLabel(v, meta, v.toStringAsFixed(0)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: math.max(1, (points.length / 4).ceilToDouble()),
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (i < 0 || i >= points.length) {
                    return const SizedBox.shrink();
                  }
                  final d = points[i].$1;
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      '${d.day}/${d.month}',
                      style: AppText.label(size: 11),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.navy,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${Fmt.dec1(s.y)} $unit\n${Fmt.date(points[s.x.round()].$1)}',
                    AppText.label(color: AppColors.white, size: 12),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].$2),
              ],
              isCurved: true,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 3,
              dotData: FlDotData(
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 3.5,
                  color: AppColors.white,
                  strokeColor: color,
                  strokeWidth: 2,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 600),
      ),
    );
  }
}

/// Histogramme (volume hebdomadaire, remplissage des cours…).
class GfBarChart extends StatelessWidget {
  const GfBarChart({
    super.key,
    required this.bars,
    this.height = 200,
    this.color = AppColors.navy,
    this.valueLabel,
  });

  final List<(String, double)> bars;
  final double height;
  final Color color;
  final String Function(double)? valueLabel;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty || bars.every((b) => b.$2 <= 0)) {
      return SizedBox(
        height: height / 2,
        child: Center(
          child: Text('Pas encore de données', style: AppText.label()),
        ),
      );
    }
    final maxV = bars.map((b) => b.$2).reduce(math.max);
    final interval = niceInterval(maxV * 1.1);
    final top = ((maxV * 1.1) / interval).ceil() * interval;
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: top,
          gridData: _grid(interval),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: interval,
                getTitlesWidget: (v, meta) => _axisLabel(
                  v,
                  meta,
                  valueLabel?.call(v) ?? v.toStringAsFixed(0),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (i < 0 || i >= bars.length) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      bars[i].$1,
                      style: AppText.label(size: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.navy,
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                valueLabel?.call(rod.toY) ?? rod.toY.toStringAsFixed(0),
                AppText.label(color: AppColors.white, size: 12),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < bars.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: bars[i].$2,
                    color: color,
                    width: 16,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                  ),
                ],
              ),
          ],
        ),
        duration: const Duration(milliseconds: 600),
      ),
    );
  }
}
