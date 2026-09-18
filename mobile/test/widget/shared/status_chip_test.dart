import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_khata/core/theme/app_theme.dart';
import 'package:pg_khata/shared/widgets/semantic_tone.dart';
import 'package:pg_khata/shared/widgets/status_chip.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );

  testWidgets('renders its label', (tester) async {
    await tester.pumpWidget(
      wrap(const StatusChip(label: 'Paid', tone: SemanticTone.success)),
    );

    expect(find.text('Paid'), findsOneWidget);
  });

  testWidgets('renders distinct labels for each tone', (tester) async {
    await tester.pumpWidget(
      wrap(
        const Column(
          children: [
            StatusChip(label: 'Reported', tone: SemanticTone.danger),
            StatusChip(label: 'In Progress', tone: SemanticTone.warning),
            StatusChip(label: 'Resolved', tone: SemanticTone.success),
          ],
        ),
      ),
    );

    expect(find.text('Reported'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Resolved'), findsOneWidget);
  });
}
