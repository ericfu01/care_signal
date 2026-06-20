import 'family_check_in_loader.dart';

const chartAbsoluteMinScore = 0.0;
const chartAbsoluteMaxScore = 100.0;

/// Y-axis range derived from visible check-in scores (clamped to 0–100).
class ChartYScale {
  const ChartYScale({
    required this.minY,
    required this.maxY,
    required this.ticks,
  });

  final double minY;
  final double maxY;
  final List<int> ticks;

  static ChartYScale fromPoints(List<DailyWellnessPoint> points) {
    final scores = points
        .map((point) => point.averageScore)
        .whereType<double>()
        .toList();
    if (scores.isEmpty) {
      return const ChartYScale(
        minY: 0,
        maxY: 100,
        ticks: [100, 75, 50, 25, 0],
      );
    }

    final dataMin = scores.reduce((a, b) => a < b ? a : b);
    final dataMax = scores.reduce((a, b) => a > b ? a : b);

    double minY;
    double maxY;

    if (dataMin == dataMax) {
      const singlePointPadding = 12.0;
      minY = (dataMin - singlePointPadding).clamp(
        chartAbsoluteMinScore,
        chartAbsoluteMaxScore,
      );
      maxY = (dataMax + singlePointPadding).clamp(
        chartAbsoluteMinScore,
        chartAbsoluteMaxScore,
      );
    } else {
      final range = dataMax - dataMin;
      final padding = (range * 0.12).clamp(4.0, 16.0);
      minY = (dataMin - padding).clamp(chartAbsoluteMinScore, chartAbsoluteMaxScore);
      maxY = (dataMax + padding).clamp(chartAbsoluteMinScore, chartAbsoluteMaxScore);
    }

    const minSpan = 16.0;
    if (maxY - minY < minSpan) {
      final mid = (dataMin + dataMax) / 2;
      minY = (mid - minSpan / 2).clamp(chartAbsoluteMinScore, chartAbsoluteMaxScore);
      maxY = (mid + minSpan / 2).clamp(chartAbsoluteMinScore, chartAbsoluteMaxScore);
      if (maxY - minY < minSpan) {
        if (minY <= chartAbsoluteMinScore) {
          maxY = (minY + minSpan).clamp(chartAbsoluteMinScore, chartAbsoluteMaxScore);
        } else if (maxY >= chartAbsoluteMaxScore) {
          minY = (maxY - minSpan).clamp(chartAbsoluteMinScore, chartAbsoluteMaxScore);
        }
      }
    }

    final ticks = List<int>.generate(5, (index) {
      final value = maxY - (maxY - minY) * index / 4;
      return value.round();
    });

    return ChartYScale(minY: minY, maxY: maxY, ticks: ticks);
  }

  double normalizeScore(double score) {
    final span = maxY - minY;
    if (span <= 0) return 0.5;
    return ((score - minY) / span).clamp(0.0, 1.0);
  }
}
