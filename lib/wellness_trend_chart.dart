import 'package:flutter/material.dart';

import 'chart_y_scale.dart';
import 'family_check_in_loader.dart';

const _chartTopPad = 8.0;
const _chartBottomPad = 4.0;
const _chartAxisWidth = 36.0;

/// Line chart of daily family wellness scores with an auto-scaled Y axis.
class WellnessTrendChart extends StatelessWidget {
  const WellnessTrendChart({
    required this.points,
    this.height = 160,
    super.key,
  });

  final List<DailyWellnessPoint> points;
  final double height;

  static const _lineColor = Color(0xFF0E9F7B);
  static const _fillTop = Color(0x6626A69A);
  static const _fillBottom = Color(0x0526A69A);

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No check-in history yet.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black45,
                ),
          ),
        ),
      );
    }

    final hasAnyData = points.any((p) => p.hasData);
    if (!hasAnyData) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Complete daily check-ins to see your trend.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black45,
                ),
          ),
        ),
      );
    }

    final yScale = ChartYScale.fromPoints(points);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: height,
              child: _ChartYLabels(height: height, scale: yScale),
            ),
            Expanded(
              child: SizedBox(
                height: height,
                child: CustomPaint(
                  painter: _WellnessTrendPainter(
                    points: points,
                    yScale: yScale,
                    lineColor: _lineColor,
                    fillTop: _fillTop,
                    fillBottom: _fillBottom,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: _chartAxisWidth),
            Expanded(child: _ChartXLabels(points: points)),
          ],
        ),
      ],
    );
  }
}

class _ChartYLabels extends StatelessWidget {
  const _ChartYLabels({
    required this.height,
    required this.scale,
  });

  final double height;
  final ChartYScale scale;

  static const axisWidth = _chartAxisWidth;
  static const topPad = _chartTopPad;
  static const bottomPad = _chartBottomPad;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.black45,
          fontWeight: FontWeight.w600,
          fontSize: 10,
          height: 1,
        );
    final chartHeight = height - topPad - bottomPad;
    final ticks = scale.ticks;

    return SizedBox(
      width: axisWidth,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < ticks.length; i++)
            Positioned(
              left: 0,
              right: 2,
              top: ticks.length == 1
                  ? topPad + chartHeight / 2 - 6
                  : topPad + chartHeight * i / (ticks.length - 1) - 6,
              child: Text(
                '${ticks[i]}',
                textAlign: TextAlign.right,
                style: style,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartXLabels extends StatelessWidget {
  const _ChartXLabels({required this.points});

  final List<DailyWellnessPoint> points;

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final indices = _labelIndices();
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.black45,
          fontWeight: FontWeight.w600,
          height: 1.2,
        );
    final lastStyle = style?.copyWith(
      color: Colors.black87,
      fontWeight: FontWeight.bold,
    );

    return _EvenLabelRow(
      points: points,
      indices: indices,
      formatLabel: _formatLabel,
      style: style,
      lastStyle: lastStyle,
    );
  }

  List<int> _labelIndices() {
    if (points.length <= 7) {
      return List.generate(points.length, (i) => i);
    }
    const target = 6;
    final indices = <int>{};
    for (var i = 0; i < target; i++) {
      indices.add(
        (i * (points.length - 1) / (target - 1)).round(),
      );
    }
    return indices.toList()..sort();
  }

  String _formatLabel(DateTime date) {
    if (points.length <= 7) {
      return _weekdays[date.weekday - 1];
    }
    return '${date.month}/${date.day}';
  }
}

class _EvenLabelRow extends StatelessWidget {
  const _EvenLabelRow({
    required this.points,
    required this.indices,
    required this.formatLabel,
    this.style,
    this.lastStyle,
  });

  final List<DailyWellnessPoint> points;
  final List<int> indices;
  final String Function(DateTime date) formatLabel;
  final TextStyle? style;
  final TextStyle? lastStyle;

  @override
  Widget build(BuildContext context) {
    if (indices.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final i in indices)
          Text(
            formatLabel(points[i].date),
            maxLines: 1,
            softWrap: false,
            style: i == points.length - 1 ? lastStyle : style,
          ),
      ],
    );
  }
}

class _WellnessTrendPainter extends CustomPainter {
  _WellnessTrendPainter({
    required this.points,
    required this.yScale,
    required this.lineColor,
    required this.fillTop,
    required this.fillBottom,
  });

  final List<DailyWellnessPoint> points;
  final ChartYScale yScale;
  final Color lineColor;
  final Color fillTop;
  final Color fillBottom;

  static const _gridLines = 4;
  static const topPad = _chartTopPad;
  static const bottomPad = _chartBottomPad;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) return;

    final chartHeight = size.height - topPad - bottomPad;

    final gridPaint = Paint()
      ..color = const Color(0xFFEFF1F4)
      ..strokeWidth = 1;

    for (var i = 0; i <= _gridLines; i++) {
      final y = topPad + chartHeight * i / _gridLines;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final plotted = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final score = points[i].averageScore;
      if (score != null) {
        plotted.add(_pointAt(size, i, score, topPad, chartHeight));
      }
    }

    if (plotted.isEmpty) return;

    if (plotted.length == 1) {
      final point = plotted.first;
      const stubHalfWidth = 18.0;
      canvas.drawLine(
        Offset(point.dx - stubHalfWidth, point.dy),
        Offset(point.dx + stubHalfWidth, point.dy),
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    } else {
      final baseline = topPad + chartHeight;
      final fillPath = Path()
        ..moveTo(plotted.first.dx, baseline)
        ..lineTo(plotted.first.dx, plotted.first.dy);
      for (var i = 1; i < plotted.length; i++) {
        fillPath.lineTo(plotted[i].dx, plotted[i].dy);
      }
      fillPath
        ..lineTo(plotted.last.dx, baseline)
        ..close();

      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [fillTop, fillBottom],
          ).createShader(Rect.fromLTWH(0, topPad, size.width, chartHeight)),
      );

      final linePath = Path()..moveTo(plotted.first.dx, plotted.first.dy);
      for (var i = 1; i < plotted.length; i++) {
        linePath.lineTo(plotted[i].dx, plotted[i].dy);
      }
      canvas.drawPath(
        linePath,
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    for (final point in plotted) {
      canvas.drawCircle(point, 5.5, Paint()..color = lineColor);
      canvas.drawCircle(point, 2.5, Paint()..color = Colors.white);
    }
  }

  Offset _pointAt(
    Size size,
    int index,
    double score,
    double topPad,
    double chartHeight,
  ) {
    final x = points.length == 1
        ? size.width / 2
        : size.width * index / (points.length - 1);
    final normalized = yScale.normalizeScore(score);
    final y = topPad + chartHeight * (1 - normalized);
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant _WellnessTrendPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.yScale.minY != yScale.minY ||
        oldDelegate.yScale.maxY != yScale.maxY;
  }
}
