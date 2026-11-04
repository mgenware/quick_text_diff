library;

import 'dart:math' as math;

import 'package:diff_match_patch/diff_match_patch.dart' as engine;
import 'package:diffutil_dart/diffutil.dart' as sequence;
import 'package:flutter/material.dart';

/// A changed fragment of a line, or an unchanged fragment within a replacement.
@immutable
class TextDiffSpan {
  const TextDiffSpan(this.text, {required this.isChanged});

  final String text;
  final bool isChanged;
}

/// One source line. Line numbers are one-based.
@immutable
class TextDiffLine {
  TextDiffLine({
    required this.lineNumber,
    required this.text,
    required this.hasNewline,
    required List<TextDiffSpan> spans,
  }) : spans = List.unmodifiable(spans);

  final int lineNumber;
  final String text;
  final bool hasNewline;
  final List<TextDiffSpan> spans;
}

/// An aligned pair of lines. A null side is an empty placeholder.
@immutable
class TextDiffRow {
  const TextDiffRow({
    this.oldLine,
    this.newLine,
    this.collapsedLinesBefore = 0,
    this.isChanged = true,
  });

  final TextDiffLine? oldLine;
  final TextDiffLine? newLine;
  final bool isChanged;

  /// Hidden unchanged lines between this row and the preceding changed block.
  final int collapsedLinesBefore;
}

/// Line-level differences with character highlights inside replacements.
///
/// Unchanged lines are included only when requested. CRLF is normalized to LF, but a missing
/// final newline is a change. A replacement counts as a deletion and an addition.
@immutable
class TextDiff {
  TextDiff._(List<TextDiffRow> rows)
    : rows = List.unmodifiable(rows),
      addedLines = rows
          .where((row) => row.isChanged && row.newLine != null)
          .length,
      deletedLines = rows
          .where((row) => row.isChanged && row.oldLine != null)
          .length;

  factory TextDiff.compare(
    String oldText,
    String newText, {
    int surroundingLines = 0,
  }) {
    if (surroundingLines < 0) {
      throw ArgumentError.value(
        surroundingLines,
        'surroundingLines',
        'Must be non-negative',
      );
    }
    final oldLines = _splitLines(oldText);
    final newLines = _splitLines(newText);
    final alignment = List<int?>.generate(oldLines.length, (index) => index);
    final updates = sequence.calculateListDiff(
      oldLines,
      newLines,
      detectMoves: false,
    );
    for (final update in updates.getUpdates(batch: false)) {
      switch (update) {
        case sequence.Remove(:final position, :final count):
          alignment.removeRange(position, position + count);
        case sequence.Insert(:final position, :final count):
          alignment.insertAll(position, List<int?>.filled(count, null));
        case sequence.Change() || sequence.Move():
          throw StateError('Line diffs must contain only inserts and removes.');
      }
    }
    final rows = <TextDiffRow>[];
    var oldIndex = 0;
    var newIndex = 0;
    var collapsedLines = 0;
    void appendContext({required bool followingChange}) {
      final leading = rows.isEmpty
          ? 0
          : math.min(surroundingLines, collapsedLines);
      final trailing = followingChange
          ? math.min(surroundingLines, collapsedLines)
          : 0;
      var hidden = 0;
      for (var offset = 0; offset < collapsedLines; offset++) {
        if (offset >= leading && offset < collapsedLines - trailing) {
          hidden++;
          continue;
        }
        TextDiffLine buildContextLine(List<String> source, int index) {
          final raw = source[index];
          final text = _displayText(raw);
          return TextDiffLine(
            lineNumber: index + 1,
            text: text,
            hasNewline: raw.endsWith('\n'),
            spans: [TextDiffSpan(text, isChanged: false)],
          );
        }

        rows.add(
          TextDiffRow(
            oldLine: buildContextLine(
              oldLines,
              oldIndex - collapsedLines + offset,
            ),
            newLine: buildContextLine(
              newLines,
              newIndex - collapsedLines + offset,
            ),
            isChanged: false,
            collapsedLinesBefore: rows.isEmpty ? 0 : hidden,
          ),
        );
        hidden = 0;
      }
      collapsedLines = hidden;
    }

    void appendBlock(int oldEnd, int newEnd) {
      final deletedCount = oldEnd - oldIndex;
      final addedCount = newEnd - newIndex;
      if (deletedCount > 0 || addedCount > 0) {
        appendContext(followingChange: true);
      }
      for (var row = 0; row < math.max(deletedCount, addedCount); row++) {
        final oldNumber = row < deletedCount ? oldIndex + row : null;
        final newNumber = row < addedCount ? newIndex + row : null;
        final oldLine = oldNumber == null ? null : oldLines[oldNumber];
        final newLine = newNumber == null ? null : newLines[newNumber];
        final fragments = _diffGraphemes(
          _displayText(oldLine ?? ''),
          _displayText(newLine ?? ''),
        );
        TextDiffLine? buildLine(String? raw, int? number, int excluded) {
          if (raw == null || number == null) return null;
          return TextDiffLine(
            lineNumber: number + 1,
            text: _displayText(raw),
            hasNewline: raw.endsWith('\n'),
            spans: [
              for (final fragment in fragments)
                if (fragment.operation != excluded)
                  TextDiffSpan(
                    fragment.text,
                    isChanged: fragment.operation != engine.DIFF_EQUAL,
                  ),
            ],
          );
        }

        rows.add(
          TextDiffRow(
            oldLine: buildLine(oldLine, oldNumber, engine.DIFF_INSERT),
            newLine: buildLine(newLine, newNumber, engine.DIFF_DELETE),
            collapsedLinesBefore: row == 0 && rows.isNotEmpty
                ? collapsedLines
                : 0,
          ),
        );
      }
      if (deletedCount > 0 || addedCount > 0) collapsedLines = 0;
    }

    for (var newAnchor = 0; newAnchor < alignment.length; newAnchor++) {
      final oldAnchor = alignment[newAnchor];
      if (oldAnchor == null) continue;
      appendBlock(oldAnchor, newAnchor);
      oldIndex = oldAnchor + 1;
      newIndex = newAnchor + 1;
      collapsedLines++;
    }
    appendBlock(oldLines.length, newLines.length);
    appendContext(followingChange: false);
    return TextDiff._(rows);
  }

  final List<TextDiffRow> rows;
  final int addedLines;
  final int deletedLines;

  static List<String> _splitLines(String text) =>
      RegExp(r'[^\n]*\n|[^\n]+$')
          .allMatches(text.replaceAll('\r\n', '\n'))
          .map((match) => match.group(0)!)
          .toList();

  static String _displayText(String text) =>
      text.endsWith('\n') ? text.substring(0, text.length - 1) : text;

  static List<engine.Diff> _diffGraphemes(String oldText, String newText) {
    final graphemeToCodeUnit = <String, int>{};
    final codeUnitToGrapheme = <int, String>{};
    var nextCodeUnit = 0;
    var exhaustedTokens = false;

    String encode(String text) {
      final codeUnits = <int>[];
      for (final grapheme in text.characters) {
        var codeUnit = graphemeToCodeUnit[grapheme];
        if (codeUnit == null) {
          while (nextCodeUnit >= 0xD800 && nextCodeUnit <= 0xDFFF) {
            nextCodeUnit++;
          }
          if (nextCodeUnit > 0xFFFF) {
            exhaustedTokens = true;
            return text;
          }
          codeUnit = nextCodeUnit++;
          graphemeToCodeUnit[grapheme] = codeUnit;
          codeUnitToGrapheme[codeUnit] = grapheme;
        }
        codeUnits.add(codeUnit);
      }
      return String.fromCharCodes(codeUnits);
    }

    final encodedOld = encode(oldText);
    final encodedNew = encode(newText);
    if (exhaustedTokens) {
      return [
        engine.Diff(engine.DIFF_DELETE, oldText),
        engine.Diff(engine.DIFF_INSERT, newText),
      ];
    }

    final fragments = engine.diff(encodedOld, encodedNew, checklines: false);
    engine.cleanupSemantic(fragments);
    String decode(String text) {
      final result = StringBuffer();
      for (final codeUnit in text.codeUnits) {
        result.write(codeUnitToGrapheme[codeUnit]!);
      }
      return result.toString();
    }

    return [
      for (final fragment in fragments)
        engine.Diff(fragment.operation, decode(fragment.text)),
    ];
  }
}

/// Colors for the diff surface. Defaults adapt to the surrounding theme.
@immutable
class QuickTextDiffColors {
  const QuickTextDiffColors({
    this.background = const Color(0xFFFFFFFF),
    this.foreground = const Color(0xFF24292F),
    this.muted = const Color(0xFF8C959F),
    this.addition = const Color(0xFFDAF5EF),
    this.deletion = const Color(0xFFFDE9E7),
    this.additionHighlight = const Color(0xFFA6E3D5),
    this.deletionHighlight = const Color(0xFFFFB8AD),
    this.additionText = const Color(0xFF116149),
    this.deletionText = const Color(0xFF7B3027),
    this.additionCount = const Color(0xFF1A7F37),
    this.deletionCount = const Color(0xFFCF222E),
    this.divider = const Color(0xFFD8DEE4),
  });

  const QuickTextDiffColors.dark()
    : background = const Color(0xFF0D1117),
      foreground = const Color(0xFFE6EDF3),
      muted = const Color(0xFF8B949E),
      addition = const Color(0xFF12352D),
      deletion = const Color(0xFF3D2023),
      additionHighlight = const Color(0xFF226A52),
      deletionHighlight = const Color(0xFF803D42),
      additionText = const Color(0xFFAFF5D4),
      deletionText = const Color(0xFFFFC1BA),
      additionCount = const Color(0xFF3FB950),
      deletionCount = const Color(0xFFF85149),
      divider = const Color(0xFF30363D);

  final Color background;
  final Color foreground;
  final Color muted;
  final Color addition;
  final Color deletion;
  final Color additionHighlight;
  final Color deletionHighlight;
  final Color additionText;
  final Color deletionText;
  final Color additionCount;
  final Color deletionCount;
  final Color divider;
}

/// A desktop split diff with selectable text and surrounding unchanged lines.
///
/// Give this widget bounded width and height, for example with [Expanded].
/// Vertical scrolling is shared; each side scrolls horizontally independently.
class QuickTextDiff extends StatefulWidget {
  const QuickTextDiff({
    super.key,
    required this.oldText,
    required this.newText,
    this.textStyle,
    this.colors,
    this.lineHeight = 24,
    this.columnGap = 32,
    this.surroundingLines = 3,
  }) : assert(lineHeight > 0),
       assert(columnGap >= 0),
       assert(surroundingLines >= 0);

  final String oldText;
  final String newText;
  final TextStyle? textStyle;
  final QuickTextDiffColors? colors;
  final double lineHeight;
  final double columnGap;

  /// Unchanged lines shown before and after each change. Overlapping windows merge.
  final int surroundingLines;

  @override
  State<QuickTextDiff> createState() => _QuickTextDiffState();
}

class _QuickTextDiffState extends State<QuickTextDiff> {
  late TextDiff _diff;
  final _vertical = ScrollController();
  final _oldHorizontal = ScrollController();
  final _newHorizontal = ScrollController();

  @override
  void initState() {
    super.initState();
    _compare();
  }

  @override
  void didUpdateWidget(QuickTextDiff oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.oldText != widget.oldText ||
        oldWidget.newText != widget.newText ||
        oldWidget.surroundingLines != widget.surroundingLines) {
      _compare();
    }
  }

  void _compare() {
    _diff = TextDiff.compare(
      widget.oldText,
      widget.newText,
      surroundingLines: widget.surroundingLines,
    );
  }

  @override
  void reassemble() {
    super.reassemble();
    _compare();
  }

  @override
  void dispose() {
    _vertical.dispose();
    _oldHorizontal.dispose();
    _newHorizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        widget.colors ??
        (Theme.of(context).brightness == Brightness.dark
            ? const QuickTextDiffColors.dark()
            : const QuickTextDiffColors());
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: 14,
      height: 1.4,
      color: colors.foreground,
      letterSpacing: 0,
    ).merge(widget.textStyle);
    final painter = TextPainter(
      text: TextSpan(text: 'Mg', style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final textHeight = painter.height;
    final rowHeight = math.max(widget.lineHeight, textHeight + 4);
    painter.dispose();
    return Material(
      color: colors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label:
                '${_diff.addedLines} added lines, '
                '${_diff.deletedLines} deleted lines',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    '+${_diff.addedLines}',
                    style: style.copyWith(
                      color: colors.additionCount,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '-${_diff.deletedLines}',
                    style: style.copyWith(
                      color: colors.deletionCount,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _diff.rows.isEmpty
                ? Center(
                    child: Text(
                      'No changes',
                      style: style.copyWith(color: colors.muted),
                    ),
                  )
                : Scrollbar(
                    controller: _vertical,
                    thumbVisibility: true,
                    notificationPredicate: (notification) =>
                        notification.metrics.axis == Axis.vertical,
                    child: SingleChildScrollView(
                      controller: _vertical,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _pane(
                              true,
                              colors,
                              style,
                              rowHeight,
                              textHeight,
                            ),
                          ),
                          SizedBox(width: widget.columnGap),
                          Expanded(
                            child: _pane(
                              false,
                              colors,
                              style,
                              rowHeight,
                              textHeight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _pane(
    bool isOld,
    QuickTextDiffColors colors,
    TextStyle style,
    double rowHeight,
    double textHeight,
  ) {
    final controller = isOld ? _oldHorizontal : _newHorizontal;
    final lines = _diff.rows
        .map((row) => isOld ? row.oldLine : row.newLine)
        .toList();
    final lastLine = lines.lastWhere(
      (line) => line != null,
      orElse: () => null,
    );
    final gutterWidth = math.max(
      56.0,
      ((isOld ? widget.oldText : widget.newText)
                  .split('\n')
                  .length
                  .toString()
                  .length *
              (style.fontSize ?? 14.0)) +
          24.0,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        var contentWidth = constraints.maxWidth;
        final painter = TextPainter(
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        );
        for (final line in lines) {
          if (line == null) continue;
          painter.text = TextSpan(
            text:
                '${line.text}${line.hasNewline ? '' : '  \\ No newline at end of file'}',
            style: style,
          );
          painter.layout();
          contentWidth = math.max(
            contentWidth,
            painter.width + gutterWidth + 32,
          );
        }
        painter.dispose();
        final separatorHeight = math.max(
          20.0,
          MediaQuery.textScalerOf(context).scale(11) * 1.4 + 4,
        );
        return Scrollbar(
          controller: controller,
          thumbVisibility: true,
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: contentWidth,
              child: SelectionArea(
                child: Column(
                  children: [
                    for (final (index, line) in lines.indexed) ...[
                      if (_diff.rows[index].collapsedLinesBefore > 0)
                        SelectionContainer.disabled(
                          child: Container(
                            height: separatorHeight,
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.only(left: gutterWidth + 16),
                            decoration: BoxDecoration(
                              border: Border.symmetric(
                                horizontal: BorderSide(color: colors.divider),
                              ),
                            ),
                            child: Text(
                              '${_diff.rows[index].collapsedLinesBefore} '
                              'collapsed ${_diff.rows[index].collapsedLinesBefore == 1 ? 'line' : 'lines'}',
                              style: style.copyWith(
                                fontSize: 11,
                                color: colors.muted,
                              ),
                            ),
                          ),
                        ),
                      SizedBox(
                        height: rowHeight,
                        child: line == null
                            ? CustomPaint(
                                painter: _GapPainter(colors.divider),
                                child: const SizedBox.expand(),
                              )
                            : ColoredBox(
                                color: !_diff.rows[index].isChanged
                                    ? colors.background
                                    : isOld
                                    ? colors.deletion
                                    : colors.addition,
                                child: Row(
                                  children: [
                                    SelectionContainer.disabled(
                                      child: Container(
                                        width: gutterWidth,
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(
                                          right: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            right: BorderSide(
                                              color: colors.divider,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          '${line.lineNumber}',
                                          style: style.copyWith(
                                            color: colors.muted,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    ClipRect(
                                      child: SizedBox(
                                        height: rowHeight,
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            top: (rowHeight - textHeight) / 2,
                                          ),
                                          child: Text.rich(
                                            TextSpan(
                                              children: [
                                                for (final span in line.spans)
                                                  TextSpan(
                                                    text: span.text,
                                                    style: span.isChanged
                                                        ? TextStyle(
                                                            backgroundColor:
                                                                isOld
                                                                ? colors
                                                                      .deletionHighlight
                                                                : colors
                                                                      .additionHighlight,
                                                          )
                                                        : null,
                                                  ),
                                                if (line != lastLine)
                                                  const TextSpan(
                                                    text: '\n',
                                                    style: TextStyle(
                                                      fontSize: 0,
                                                      height: 0,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            style: style.copyWith(
                                              color:
                                                  !_diff.rows[index].isChanged
                                                  ? colors.foreground
                                                  : isOld
                                                  ? colors.deletionText
                                                  : colors.additionText,
                                            ),
                                            softWrap: false,
                                            textDirection: TextDirection.ltr,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (!line.hasNewline)
                                      SelectionContainer.disabled(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 16,
                                          ),
                                          child: Text(
                                            r'\ No newline at end of file',
                                            style: style.copyWith(
                                              color: colors.muted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GapPainter extends CustomPainter {
  const _GapPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var offset = -size.height; offset < size.width; offset += 8) {
      canvas.drawLine(
        Offset(offset, size.height),
        Offset(offset + size.height, 0),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GapPainter oldDelegate) => oldDelegate.color != color;
}
