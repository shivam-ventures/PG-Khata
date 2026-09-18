import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_khata/core/theme/app_theme.dart';
import 'package:pg_khata/shared/widgets/primary_button.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );

  testWidgets(
    'expand: true (the default) fills a Column — the intended full-width CTA',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          Column(
            children: [PrimaryButton(label: 'Send OTP', onPressed: () {})],
          ),
        ),
      );

      final buttonWidth = tester.getSize(find.byType(ElevatedButton)).width;
      final screenWidth = tester.getSize(find.byType(Scaffold)).width;
      expect(buttonWidth, screenWidth);
    },
  );

  testWidgets(
    'expand: false sizes to its label instead of starving a Row sibling '
    '(regression: the theme minimumSize is Size.fromHeight, i.e. infinite '
    'min width — without expand:false this button used to claim the whole '
    'Row and squeeze the sibling Text down to ~0 width)',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          Row(
            children: [
              const Expanded(child: Text('Karthik Iyer', maxLines: 1)),
              PrimaryButton(
                label: 'Assign bed',
                onPressed: () {},
                expand: false,
              ),
            ],
          ),
        ),
      );

      final buttonWidth = tester.getSize(find.byType(ElevatedButton)).width;
      final screenWidth = tester.getSize(find.byType(Scaffold)).width;
      // The button must stay compact — nowhere near the full row width —
      // leaving real room for the Expanded sibling.
      expect(buttonWidth, lessThan(screenWidth * 0.5));

      // And the label text must actually have rendered on one line, not
      // been squeezed into a near-zero-width column of single characters.
      final textSize = tester.getSize(find.text('Karthik Iyer'));
      expect(textSize.width, greaterThan(50));
    },
  );
}
