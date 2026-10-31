import 'dart:math';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_text_diff/quick_text_diff.dart';

void main() {
  Finder findLine(String text) => find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        widget.textSpan?.toPlainText().replaceFirst(RegExp(r'\n$'), '') == text,
  );

  test('hides unchanged lines and preserves source line numbers', () {
    final diff = TextDiff.compare(
      'same\nold\nsame again\n',
      'same\nnew\nsame again\n',
    );
    expect(diff.addedLines, 1);
    expect(diff.deletedLines, 1);
    expect(diff.rows, hasLength(1));
    expect(diff.rows.single.oldLine!.lineNumber, 2);
    expect(diff.rows.single.newLine!.lineNumber, 2);
    expect(diff.rows.single.oldLine!.text, 'old');
    expect(diff.rows.single.newLine!.text, 'new');
  });

  test('aligns unequal replacement blocks with empty placeholders', () {
    final diff = TextDiff.compare(
      'header\nsize 21 start 176\nsize 21 start 197\nsize 21 start 218\nfooter\n',
      'header\nsdfsdsize 21 start 176\nfooter\n',
    );
    expect(diff.addedLines, 1);
    expect(diff.deletedLines, 3);
    expect(diff.rows, hasLength(3));
    expect(diff.rows.first.oldLine!.lineNumber, 2);
    expect(diff.rows.first.newLine!.lineNumber, 2);
    expect(diff.rows[1].newLine, isNull);
    expect(diff.rows[2].newLine, isNull);
    expect(
      diff.rows.first.newLine!.spans
          .where((span) => span.isChanged)
          .map((span) => span.text)
          .join(),
      'sdfsd',
    );
  });

  test('counts additions, deletions, blank lines and identical input', () {
    expect(TextDiff.compare('', 'one\n\n').addedLines, 2);
    expect(TextDiff.compare('one\n\n', '').deletedLines, 2);
    expect(TextDiff.compare('same\n', 'same\n').rows, isEmpty);
    expect(TextDiff.compare('', '').rows, isEmpty);
    final diff = TextDiff.compare('a\nb\nc\n', 'a\ninsert\nb\nreplace\n');
    expect(diff.addedLines, 2);
    expect(diff.deletedLines, 1);
    expect(
      diff.rows
          .map((row) => [row.oldLine?.lineNumber, row.newLine?.lineNumber])
          .toList(),
      [
        [null, 2],
        [3, 4],
      ],
    );
  });

  test('normalizes CRLF but detects a missing final newline', () {
    expect(TextDiff.compare('a\r\nb\r\n', 'a\nb\n').rows, isEmpty);
    final diff = TextDiff.compare('a\n', 'a');
    expect(diff.addedLines, 1);
    expect(diff.deletedLines, 1);
    expect(diff.rows.single.oldLine!.hasNewline, isTrue);
    expect(diff.rows.single.newLine!.hasNewline, isFalse);
  });

  test('counts only hidden lines between changed blocks', () {
    final diff = TextDiff.compare(
      'prefix\nold first\nshared 1\nshared 2\nold second\nsuffix\n',
      'prefix\nnew first\nshared 1\nshared 2\nnew second\nsuffix\n',
    );
    expect(diff.rows.map((row) => row.collapsedLinesBefore), [0, 2]);
    expect(diff.addedLines, 2);
    expect(diff.deletedLines, 2);
    final asymmetric = TextDiff.compare(
      'deleted 1\ndeleted 2\nshared\nold\n',
      'shared\nnew\nadded\n',
    );
    expect(asymmetric.rows.map((row) => row.collapsedLinesBefore), [
      0,
      0,
      1,
      0,
    ]);
  });

  test('keeps repeated lines and Unicode intact', () {
    final diff = TextDiff.compare('same\nsame\nhello 😀\n', 'same\nhello 🌍\n');
    expect(diff.deletedLines, 2);
    expect(diff.addedLines, 1);
    for (final row in diff.rows) {
      for (final line in [row.oldLine, row.newLine]) {
        if (line != null) {
          expect(line.spans.map((span) => span.text).join(), line.text);
        }
      }
    }
  });

  test('context preserves numbers and counts and merges chained changes', () {
    final oldLines = List.generate(30, (index) => 'line $index\n');
    final newLines = [...oldLines];
    for (final index in [5, 8, 11, 25]) {
      newLines[index] = 'replacement $index\n';
    }
    final diff = TextDiff.compare(
      oldLines.join(),
      newLines.join(),
      surroundingLines: 3,
    );
    expect(diff.rows.map((row) => row.oldLine!.lineNumber), [
      ...List.generate(13, (index) => index + 3),
      ...List.generate(7, (index) => index + 23),
    ]);
    expect(
      diff.rows
          .where((row) => row.collapsedLinesBefore > 0)
          .single
          .collapsedLinesBefore,
      7,
    );
    expect(diff.addedLines, 4);
    expect(diff.deletedLines, 4);
    for (final row in diff.rows.where((row) => !row.isChanged)) {
      expect(row.oldLine!.text, row.newLine!.text);
      expect(row.oldLine!.spans.single.isChanged, isFalse);
    }
  });

  test('context merges touching windows and separates only hidden lines', () {
    for (final gap in [6, 7]) {
      final oldLines = List.generate(gap + 2, (index) => 'line $index\n');
      final newLines = [...oldLines];
      newLines[0] = 'first\n';
      newLines[gap + 1] = 'last\n';
      final diff = TextDiff.compare(
        oldLines.join(),
        newLines.join(),
        surroundingLines: 3,
      );
      expect(diff.rows, hasLength(8));
      expect(
        diff.rows
            .map((row) => row.collapsedLinesBefore)
            .reduce((total, count) => total + count),
        gap - 6,
      );
    }
  });

  test('context aligns source numbers around unequal change blocks', () {
    final diff = TextDiff.compare(
      'deleted 1\ndeleted 2\nshared\nold\n',
      'shared\nnew\nadded\n',
      surroundingLines: 3,
    );
    expect(
      diff.rows.map(
        (row) => [row.oldLine?.lineNumber, row.newLine?.lineNumber],
      ),
      [
        [1, null],
        [2, null],
        [3, 1],
        [4, 2],
        [null, 3],
      ],
    );
    expect(diff.rows[2].isChanged, isFalse);
    expect(diff.addedLines, 2);
    expect(diff.deletedLines, 3);
    expect(diff.rows.every((row) => row.collapsedLinesBefore == 0), isTrue);
  });

  test('context clips at boundaries and keeps identical input empty', () {
    final diff = TextDiff.compare(
      'a\nb\nc\n',
      'changed\nb\nc\n',
      surroundingLines: 3,
    );
    expect(diff.rows, hasLength(3));
    expect(diff.addedLines, 1);
    expect(diff.deletedLines, 1);
    expect(
      TextDiff.compare('same\n', 'same\n', surroundingLines: 3).rows,
      isEmpty,
    );
    expect(
      () => TextDiff.compare('', '', surroundingLines: -1),
      throwsArgumentError,
    );
  });

  test('large inputs still omit unchanged lines between separate edits', () {
    final oldLines = List.generate(66000, (index) => 'line $index\n');
    final newLines = [...oldLines];
    newLines[10] = 'first replacement\n';
    newLines[65990] = 'last replacement\n';
    final diff = TextDiff.compare(oldLines.join(), newLines.join());
    expect(diff.rows, hasLength(2));
    expect(diff.addedLines, 2);
    expect(diff.deletedLines, 2);
    expect(diff.rows.first.oldLine!.lineNumber, 11);
    expect(diff.rows.last.newLine!.lineNumber, 65991);
  });

  test('randomized edits preserve all unchanged anchors and source text', () {
    final random = Random(42);
    for (var sample = 0; sample < 100; sample++) {
      final oldLines = List.generate(30, (index) => 'line $index\n');
      final newLines = <String>[];
      var added = 0;
      var deleted = 0;
      for (var index = 0; index < oldLines.length; index++) {
        if (random.nextBool()) {
          newLines.add('insert $index\n');
          added++;
        }
        if (random.nextInt(4) == 0) {
          deleted++;
        } else {
          newLines.add(oldLines[index]);
        }
      }
      final diff = TextDiff.compare(oldLines.join(), newLines.join());
      expect(diff.addedLines, added);
      expect(diff.deletedLines, deleted);
      for (final row in diff.rows) {
        final oldLine = row.oldLine;
        final newLine = row.newLine;
        if (oldLine != null) {
          expect('${oldLine.text}\n', oldLines[oldLine.lineNumber - 1]);
          expect(newLines, isNot(contains('${oldLine.text}\n')));
        }
        if (newLine != null) {
          expect('${newLine.text}\n', newLines[newLine.lineNumber - 1]);
          expect(oldLines, isNot(contains('${newLine.text}\n')));
        }
      }
    }
  });

  Future<void> pumpDiff(
    WidgetTester tester,
    String oldText,
    String newText, {
    int surroundingLines = 0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickTextDiff(
            oldText: oldText,
            newText: newText,
            surroundingLines: surroundingLines,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'view defaults to three neutral context lines and updates config',
    (tester) async {
      final oldLines = List.generate(9, (index) => 'line $index\n');
      final newLines = [...oldLines]..[4] = 'replacement\n';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickTextDiff(
              oldText: oldLines.join(),
              newText: newLines.join(),
            ),
          ),
        ),
      );
      expect(findLine('line 0'), findsNothing);
      expect(findLine('line 1'), findsNWidgets(2));
      expect(findLine('line 7'), findsNWidgets(2));
      expect(findLine('line 8'), findsNothing);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('-1'), findsOneWidget);
      final contextBox = tester.widget<ColoredBox>(
        find
            .ancestor(
              of: findLine('line 1').first,
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(contextBox.color, const QuickTextDiffColors().background);
      await pumpDiff(
        tester,
        oldLines.join(),
        newLines.join(),
        surroundingLines: 1,
      );
      expect(findLine('line 1'), findsNothing);
      expect(findLine('line 3'), findsNWidgets(2));
      expect(findLine('line 5'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renders summary, selected sides, highlights and hatched gaps', (
    tester,
  ) async {
    await pumpDiff(tester, 'same\nold\nremoved\nsame\n', 'same\nnew\nsame\n');
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('-2'), findsOneWidget);
    expect(find.text('same'), findsNothing);
    expect(findLine('old'), findsOneWidget);
    expect(findLine('new'), findsOneWidget);
    expect(find.byType(SelectionArea), findsNWidgets(2));
    expect(
      tester.getTopLeft(findLine('old')).dy,
      tester.getTopLeft(findLine('new')).dy,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('updates comparison and displays an identical-input state', (
    tester,
  ) async {
    await pumpDiff(tester, 'old', 'new');
    await pumpDiff(tester, 'same', 'same');
    expect(find.text('+0'), findsOneWidget);
    expect(find.text('-0'), findsOneWidget);
    expect(find.text('No changes'), findsOneWidget);
    expect(find.text('old'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('consecutive changed lines use compact spacing without labels', (
    tester,
  ) async {
    await pumpDiff(
      tester,
      'old first\nold second\n',
      'new first\nnew second\n',
    );
    final spacing =
        tester.getTopLeft(findLine('old second')).dy -
        tester.getTopLeft(findLine('old first')).dy;
    expect(spacing, 24);
    expect(find.textContaining('collapsed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'thin collapsed separators align both sides across unequal blocks',
    (tester) async {
      final hidden = List.generate(123, (index) => 'shared $index\n').join();
      await pumpDiff(
        tester,
        'old first\nremoved\n${hidden}old second\n',
        'new first\n${hidden}new second\n',
      );
      expect(find.text('123 collapsed lines'), findsNWidgets(2));
      expect(find.text('shared 0'), findsNothing);
      expect(
        tester.getTopLeft(findLine('old second')).dy,
        tester.getTopLeft(findLine('new second')).dy,
      );
      final labels = find.text('123 collapsed lines');
      expect(
        tester.getTopLeft(labels.at(0)).dy,
        tester.getTopLeft(labels.at(1)).dy,
      );
      expect(tester.getSize(labels.first).height, lessThan(24));
      await pumpDiff(
        tester,
        'old\nshared\nold again\n',
        'new\nshared\nnew again\n',
      );
      expect(find.text('1 collapsed line'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long lines scroll horizontally without overflow', (
    tester,
  ) async {
    await pumpDiff(
      tester,
      '${'long old text ' * 100}\n',
      '${'long new text ' * 100}\n',
    );
    final scrolls = tester.widgetList<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    final horizontal = scrolls
        .where((scroll) => scroll.scrollDirection == Axis.horizontal)
        .toList();
    expect(horizontal, hasLength(2));
    expect(
      horizontal.first.controller!.position.maxScrollExtent,
      greaterThan(0),
    );
    horizontal.first.controller!.jumpTo(100);
    await tester.pump();
    expect(horizontal.last.controller!.offset, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changed rows scroll vertically together', (tester) async {
    await pumpDiff(
      tester,
      List.generate(80, (index) => 'old $index\n').join(),
      List.generate(80, (index) => 'new $index\n').join(),
    );
    final vertical = tester
        .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .singleWhere((scroll) => scroll.scrollDirection == Axis.vertical);
    expect(vertical.controller!.position.maxScrollExtent, greaterThan(0));
    vertical.controller!.jumpTo(120);
    await tester.pump();
    expect(
      tester.getTopLeft(findLine('old 4')).dy,
      tester.getTopLeft(findLine('new 4')).dy,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mouse selection copies source text without gutters or the other side',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      await pumpDiff(
        tester,
        'old first\nold second\n',
        'new first\nnew second\n',
      );
      final first = tester.getRect(findLine('old first'));
      final last = tester.getRect(findLine('old second'));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.down(Offset(first.left, first.center.dy));
      await mouse.moveTo(Offset(last.right + 1, last.center.dy));
      await mouse.up();
      await tester.pump();
      final regions = tester
          .stateList<SelectableRegionState>(find.byType(SelectableRegion))
          .toList();
      regions.first.contextMenuButtonItems
          .singleWhere((item) => item.type == ContextMenuButtonType.copy)
          .onPressed!();
      await tester.pump();
      expect(copied, 'old first\nold second');
      regions.last.selectAll();
      await tester.pump();
      regions.last.contextMenuButtonItems
          .singleWhere((item) => item.type == ContextMenuButtonType.copy)
          .onPressed!();
      await tester.pump();
      expect(copied, 'new first\nnew second');
      await pumpDiff(
        tester,
        'old first\nshared\nold second\n',
        'new first\nshared\nnew second\n',
      );
      final separatedRegions = tester
          .stateList<SelectableRegionState>(find.byType(SelectableRegion))
          .toList();
      expect(find.text('1 collapsed line'), findsNWidgets(2));
      separatedRegions.first.selectAll();
      await tester.pump();
      separatedRegions.first.contextMenuButtonItems
          .singleWhere((item) => item.type == ContextMenuButtonType.copy)
          .onPressed!();
      await tester.pump();
      expect(copied, 'old first\nold second');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('adapts to dark themes and larger text without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const QuickTextDiff(
              oldText: 'before\n',
              newText: 'after\n',
              textStyle: TextStyle(fontSize: 24),
            ),
          ),
        ),
      ),
    );
    final oldText = tester.widget<Text>(find.text('before'));
    expect(oldText.style!.color, const QuickTextDiffColors.dark().deletionText);
    expect(tester.takeException(), isNull);
  });
}
