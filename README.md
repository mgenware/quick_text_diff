# quick_text_diff

[![pub.dev version](https://img.shields.io/pub/v/quick_text_diff.svg)](https://pub.dev/packages/quick_text_diff)

A side-by-side text diff for Flutter desktop.

![Quick Text Diff desktop screenshot](screenshot.avif)

## Features

- Opinionated: always hides unchanged lines, with collapsed-line counts between edits.
- Hides remaining unchanged lines, with collapsed-line counts between sections.
- Selectable text on both sides with original line numbers.
- Added/deleted line summary and inline change highlights.
- Compact, aligned rows with hatched placeholders for missing lines.
- Shared vertical scrolling and independent horizontal scrolling.
- Automatic light/dark themes and customizable styling.

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:quick_text_diff/quick_text_diff.dart';

const Scaffold(
	body: QuickTextDiff(
		oldText: 'unchanged\nold text\nremoved line\n',
		newText: 'unchanged\nnew text\n',
	),
)
```

Use inside a `MaterialApp` with bounded width and height, such as a `Scaffold`
body or an `Expanded` widget. Customize with `textStyle`, `colors`, `lineHeight`,
and `columnGap`. Set `surroundingLines` to change the context size (default: `3`)
or use `0` to show only changed lines. Connected context windows merge into one
section, including chains of multiple edits. Context lines do not affect the
added/deleted summary.

`TextDiff.compare(oldText, newText, surroundingLines: 3)` includes the same context
in the comparison model. Its default remains `0`; context rows have
`isChanged: false`.

Runnable macOS and Windows demo: [example/README.md](example/README.md).
