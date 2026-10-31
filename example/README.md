# quick_text_diff_example

A native macOS and Windows demo using the parent `quick_text_diff` package
through a local path dependency.

## Run

From the repository root on macOS:

```sh
cd example
flutter pub get
flutter run -d macos
```

On Windows:

```sh
cd example
flutter pub get
flutter run -d windows
```

macOS requires Xcode with its command-line tools configured. Windows requires
Visual Studio with the Desktop development with C++ workload. Use
`flutter doctor` to check your local toolchain.

## Demo

Edit or paste into the Before and After inputs, then click **Compare** to update
the diff. Editing inputs, swapping sides, and loading or resetting samples keep
the previous comparison visible until Compare is clicked. The sample menu includes
ISO file logs, code changes, collapsed context, identical text, and long lines. Toolbar actions
swap sides, reset the selected sample, and switch between light and dark themes.

Comparisons still run synchronously when requested; large inputs can pause the
app during Compare, but pasting no longer triggers two separate diff calculations.

Only macOS and Windows runners are included. No web or mobile target is required.

## Validate

```sh
flutter test
flutter analyze
```
