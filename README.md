# quick_text_diff

A GitHub-style split text diff for Flutter desktop and desktop-sized web apps.
Unchanged lines are always hidden, with no expand-context control.

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:quick_text_diff/quick_text_diff.dart';

class DiffScreen extends StatelessWidget {
	const DiffScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return const Scaffold(
			body: QuickTextDiff(
				oldText: 'unchanged\nsize 21 start 176\nremoved line\n',
				newText: 'unchanged\nsdfsdsize 21 start 176\n',
			),
		);
	}
}
```

Use inside a `MaterialApp`. Provide bounded width and height: a `Scaffold` body,
`Expanded` in a column, or a `SizedBox` with explicit dimensions.

## Behavior

- Old text on the left, new text on the right, with original line numbers.
- Green `+N` and red `-N` changed-line counts at the top.
- Tinted changed rows and stronger character-level replacement highlights.
- Hatched placeholders keep additions and deletions aligned across both sides.
- Consecutive changed rows use a compact 24-pixel default height. Thin
  `N collapsed lines` separators mark hidden context between changed blocks.
- Select and copy text across rows independently in each column. Line numbers,
  counts, collapsed-line labels, placeholders, and newline annotations are not
  included in selection.
- Shared vertical scrolling and independent horizontal scrolling. Lines do not wrap.
- Light and dark palettes follow the surrounding Flutter theme.

A modified line counts as one deletion and one addition. Empty input has zero
lines; a blank line counts as a line. CRLF is normalized to LF, but changing the
final newline is a change, annotated with `\ No newline at end of file`.
Identical inputs show `+0 -0` and an empty `No changes` state.
Selection only copies visible changed lines, not hidden context.

## Styling

```dart
QuickTextDiff(
	oldText: before,
	newText: after,
	textStyle: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 16),
	lineHeight: 36,
	columnGap: 48,
	colors: const QuickTextDiffColors.dark(),
)
```

The default font is monospace. Custom fonts must be supplied by your application.
Use `QuickTextDiffColors(...)` to customize individual colors. Text scaling is
respected; row heights grow as needed to keep both sides aligned. `lineHeight`
sets the minimum changed-row height; collapsed separators stay thin independently.

## Diff Data

```dart
final diff = TextDiff.compare(before, after);
print('+${diff.addedLines} -${diff.deletedLines}');
for (final row in diff.rows) {
	print('${row.oldLine?.lineNumber} -> ${row.newLine?.lineNumber}');
}
```

Rows, lines, and highlight spans are immutable. Adjacent deletions and additions
are paired by position within each changed block. Moved lines are represented as
deletions and additions. `row.collapsedLinesBefore` counts hidden unchanged lines
between a changed block and the preceding one; it is zero for the first block
and for consecutive rows. Comparisons run synchronously and are cached by the
widget until either input changes; the view builds all changed rows to support
continuous selection, so this is intended for ordinary text files rather than
unbounded log streams.

Line alignment uses `diffutil_dart` (Myers); inline highlights use
`diff_match_patch`. No custom diff engine or platform plugin is required.

## Development

```sh
flutter pub get
flutter test
flutter analyze
```
