import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_khata/core/theme/app_theme.dart';
import 'package:pg_khata/shared/widgets/empty_state.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );

  testWidgets('shows title, message, and fires the primary action', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      wrap(
        EmptyState(
          icon: Icons.home_outlined,
          title: 'No properties yet',
          message: "Let's set up your first PG.",
          primaryActionLabel: 'Add Property',
          onPrimaryAction: () => tapped = true,
        ),
      ),
    );

    expect(find.text('No properties yet'), findsOneWidget);
    expect(find.text("Let's set up your first PG."), findsOneWidget);

    await tester.tap(find.text('Add Property'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('renders with no action buttons when none are supplied', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Nothing here',
          message: 'All quiet.',
        ),
      ),
    );

    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
