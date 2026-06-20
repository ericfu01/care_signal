import 'package:care_signal/family_check_in_loader.dart';
import 'package:care_signal/wellness_trend_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders auto-scaled Y-axis labels for check-in scores', (tester) async {
    final points = List.generate(
      7,
      (index) => DailyWellnessPoint(
        date: DateTime(2026, 6, index + 1),
        averageScore: 70 + index.toDouble(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WellnessTrendChart(points: points),
        ),
      ),
    );

    expect(find.text('No check-in history yet.'), findsNothing);
    expect(find.textContaining('Complete daily check-ins'), findsNothing);

    final tickFinder = find.byWidgetPredicate(
      (widget) => widget is Text && RegExp(r'^\d+$').hasMatch((widget).data ?? ''),
    );
    expect(tickFinder, findsWidgets);
  });

  testWidgets('shows empty state without data points', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WellnessTrendChart(points: []),
        ),
      ),
    );

    expect(find.text('No check-in history yet.'), findsOneWidget);
  });
}
