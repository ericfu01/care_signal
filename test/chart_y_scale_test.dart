import 'package:care_signal/chart_y_scale.dart';
import 'package:care_signal/family_check_in_loader.dart';
import 'package:flutter_test/flutter_test.dart';

DailyWellnessPoint _point(double score, {int day = 1}) {
  return DailyWellnessPoint(
    date: DateTime(2026, 6, day),
    averageScore: score,
  );
}

void main() {
  group('ChartYScale', () {
    test('uses full 0–100 range when no scores', () {
      const scale = ChartYScale(minY: 0, maxY: 100, ticks: [100, 75, 50, 25, 0]);
      final empty = ChartYScale.fromPoints(const []);
      expect(empty.minY, scale.minY);
      expect(empty.maxY, scale.maxY);
      expect(empty.ticks, scale.ticks);
    });

    test('auto-scales around clustered scores', () {
      final scale = ChartYScale.fromPoints([
        _point(72),
        _point(78),
        _point(75),
      ]);
      expect(scale.minY, lessThan(72));
      expect(scale.maxY, greaterThan(78));
      expect(scale.maxY - scale.minY, greaterThanOrEqualTo(16));
      expect(scale.ticks.length, 5);
    });

    test('pads single score with minimum span', () {
      final scale = ChartYScale.fromPoints([_point(55)]);
      expect(scale.minY, lessThan(55));
      expect(scale.maxY, greaterThan(55));
      expect(scale.maxY - scale.minY, greaterThanOrEqualTo(16));
    });

    test('clamps to absolute 0–100 bounds', () {
      final scale = ChartYScale.fromPoints([
        _point(2),
        _point(5),
      ]);
      expect(scale.minY, greaterThanOrEqualTo(0));
      expect(scale.maxY, lessThanOrEqualTo(100));
    });

    test('normalizeScore maps values into chart range', () {
      final scale = ChartYScale.fromPoints([
        _point(40),
        _point(60),
      ]);
      expect(scale.normalizeScore(scale.minY), closeTo(0, 0.001));
      expect(scale.normalizeScore(scale.maxY), closeTo(1, 0.001));
      expect(scale.normalizeScore(50), closeTo(0.5, 0.15));
    });
  });
}
