import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_text_diff/quick_text_diff.dart';
import 'package:quick_text_diff_example/main.dart';

void main() {
  testWidgets(
    'editing both inputs waits for Compare before updating the diff',
    (tester) async {
      await tester.pumpWidget(const DiffExampleApp());
      expect(find.text('Quick Text Diff'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('-4'), findsOneWidget);
      final initial = tester.widget<QuickTextDiff>(find.byType(QuickTextDiff));
      await tester.enterText(
        find.byKey(const ValueKey('old-input')),
        'before\n',
      );
      await tester.pump();
      expect(
        tester.widget<QuickTextDiff>(find.byType(QuickTextDiff)).oldText,
        initial.oldText,
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-input')),
        'after\n',
      );
      await tester.pump();
      expect(
        tester.widget<QuickTextDiff>(find.byType(QuickTextDiff)).newText,
        initial.newText,
      );
      expect(find.text('-4'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Compare'));
      await tester.pump();
      final diff = tester.widget<QuickTextDiff>(find.byType(QuickTextDiff));
      expect(diff.oldText, 'before\n');
      expect(diff.newText, 'after\n');
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('-1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('swaps sides, resets sample and toggles the theme', (
    tester,
  ) async {
    await tester.pumpWidget(const DiffExampleApp());
    await tester.tap(find.byTooltip('Swap sides'));
    await tester.pump();
    expect(find.text('-4'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Compare'));
    await tester.pump();
    expect(find.text('+4'), findsOneWidget);
    expect(find.text('-1'), findsOneWidget);
    await tester.tap(find.byTooltip('Reset sample'));
    await tester.pump();
    expect(find.text('+4'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Compare'));
    await tester.pump();
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('-4'), findsOneWidget);
    await tester.tap(find.byTooltip('Dark theme'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsed sample shows hidden context between compact blocks', (
    tester,
  ) async {
    await tester.pumpWidget(const DiffExampleApp());
    await tester.tap(find.byType(DropdownButton<DiffSample>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collapsed context').last);
    await tester.pumpAndSettle();
    expect(find.text('-4'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Compare'));
    await tester.pumpAndSettle();
    expect(find.text('123 collapsed lines'), findsNWidgets(2));
    expect(find.text('+3'), findsOneWidget);
    expect(find.text('-3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sample selector loads the no-changes state', (tester) async {
    await tester.pumpWidget(const DiffExampleApp());
    await tester.tap(find.byType(DropdownButton<DiffSample>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Identical text').last);
    await tester.pumpAndSettle();
    expect(find.text('-4'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Compare'));
    await tester.pumpAndSettle();
    expect(find.text('No changes'), findsOneWidget);
    expect(find.text('+0'), findsOneWidget);
    expect(find.text('-0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'large pastes and unrelated rebuilds keep the previous comparison',
    (tester) async {
      await tester.pumpWidget(const DiffExampleApp());
      final initial = tester.widget<QuickTextDiff>(find.byType(QuickTextDiff));
      final before = List.generate(5000, (index) => 'before $index\n').join();
      final after = List.generate(5000, (index) => 'after $index\n').join();
      await tester.enterText(find.byKey(const ValueKey('old-input')), before);
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('new-input')), after);
      await tester.pump();
      await tester.tap(find.byTooltip('Dark theme'));
      await tester.pumpAndSettle();
      final unchanged = tester.widget<QuickTextDiff>(
        find.byType(QuickTextDiff),
      );
      expect(unchanged.oldText, initial.oldText);
      expect(unchanged.newText, initial.newText);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('-4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
