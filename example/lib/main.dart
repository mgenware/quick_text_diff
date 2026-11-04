import 'package:flutter/material.dart';
import 'package:quick_text_diff/quick_text_diff.dart';

void main() => runApp(const DiffExampleApp());

enum DiffSample {
  logs('ISO file logs'),
  code('Code changes'),
  collapsed('Collapsed context'),
  identical('Identical text'),
  emoji('Emoji changes'),
  longLines('Long lines');

  const DiffSample(this.label);
  final String label;

  (String, String) get texts => switch (this) {
    logs => (
      '[iso file] Read Box type infe size 21 start 134\n'
          '[iso file] Read Box type infe size 21 start 155\n'
          '[iso file] Read Box type infe size 21 start 176\n'
          '[iso file] Read Box type infe size 21 start 197\n'
          '[iso file] Read Box type infe size 21 start 218\n'
          '[iso file] Read Box type infe size 21 start 239\n'
          '[iso file] Read Box type infe size 21 start 260\n',
      '[iso file] Read Box type infe size 21 start 134\n'
          '[iso file] Read Box type infe size 21 start 155\n'
          '[iso file] Read Box type infe sdfsdfe fsize 21 start 176\n'
          '[iso file] Read Box type infe size 21 start 260\n',
    ),
    code => (
      'class Settings {\n'
          '  final String theme = "light";\n'
          '  final int timeout = 30;\n'
          '  final bool debug = true;\n'
          '}\n',
      'class Settings {\n'
          '  final String theme = "dark";\n'
          '  final int timeout = 60;\n'
          '  final bool cache = true;\n'
          '  final int retries = 3;\n'
          '}\n',
    ),
    collapsed => (
      'old first\nold consecutive\n'
          '${List.generate(123, (index) => 'unchanged $index\n').join()}'
          'old second\n',
      'new first\nnew consecutive\n'
          '${List.generate(123, (index) => 'unchanged $index\n').join()}'
          'new second\n',
    ),
    identical => ('Nothing changed here.\n', 'Nothing changed here.\n'),
    emoji => (
      'Status: ready 😀\n'
          'Team: 👨‍👩‍👧‍👦\n'
          'Region: 🇺🇸\n'
          'Note: all systems go ✨\n',
      'Status: shipped 🚀\n'
          'Team: 👨‍👩‍👧‍👦\n'
          'Region: 🇨🇦\n'
          'Note: all systems go ✨\n',
    ),
    longLines => (
      List.generate(
        40,
        (index) => 'old entry $index: ${'original text ' * 12}\n',
      ).join(),
      List.generate(
        40,
        (index) => 'new entry $index: ${'replacement text ' * 12}\n',
      ).join(),
    ),
  };
}

class DiffExampleApp extends StatefulWidget {
  const DiffExampleApp({super.key});

  @override
  State<DiffExampleApp> createState() => _DiffExampleAppState();
}

class _DiffExampleAppState extends State<DiffExampleApp> {
  final _oldText = TextEditingController();
  final _newText = TextEditingController();
  (String, String)? _comparedTexts;
  var _sample = DiffSample.logs;
  var _dark = false;

  static const _codeStyle = TextStyle(
    fontFamily: 'Menlo',
    fontFamilyFallback: ['Consolas', 'monospace'],
    fontSize: 14,
    letterSpacing: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadSample();
    _comparedTexts = (_oldText.text, _newText.text);
  }

  void _loadSample() {
    final (oldText, newText) = _sample.texts;
    _oldText.text = oldText;
    _newText.text = newText;
  }

  @override
  void dispose() {
    _oldText.dispose();
    _newText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (oldText, newText) = _comparedTexts ??= (
      _oldText.text,
      _newText.text,
    );
    return MaterialApp(
      title: 'Quick Text Diff',
      debugShowCheckedModeBanner: false,
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Text(
                      'Quick Text Diff',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 200,
                      child: DropdownButton<DiffSample>(
                        value: _sample,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: [
                          for (final sample in DiffSample.values)
                            DropdownMenuItem(
                              value: sample,
                              child: Text(
                                sample.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (sample) {
                          if (sample == null) return;
                          setState(() {
                            _sample = sample;
                            _loadSample();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      tooltip: 'Swap sides',
                      icon: const Icon(Icons.swap_horiz),
                      onPressed: () => setState(() {
                        final old = _oldText.text;
                        _oldText.text = _newText.text;
                        _newText.text = old;
                      }),
                    ),
                    IconButton(
                      tooltip: 'Reset sample',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => setState(_loadSample),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: _dark ? 'Light theme' : 'Dark theme',
                      icon: Icon(
                        _dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                      ),
                      onPressed: () => setState(() => _dark = !_dark),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  children: [
                    Expanded(child: _editor('Before', _oldText, 'old-input')),
                    const SizedBox(width: 32),
                    Expanded(child: _editor('After', _newText, 'new-input')),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.compare_arrows),
                    label: const Text('Compare'),
                    onPressed: () => setState(() {
                      _comparedTexts = (_oldText.text, _newText.text);
                    }),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: QuickTextDiff(
                  oldText: oldText,
                  newText: newText,
                  textStyle: _codeStyle,
                  columnGap: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ThemeData _theme(Brightness brightness) => ThemeData(
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF178569),
      brightness: brightness,
    ),
    fontFamily: 'Helvetica Neue',
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? const Color(0xFF0D1117)
        : const Color(0xFFFFFFFF),
  );

  Widget _editor(String label, TextEditingController controller, String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 148,
          child: TextField(
            key: ValueKey(key),
            controller: controller,
            style: _codeStyle,
            expands: true,
            minLines: null,
            maxLines: null,
            decoration: const InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ),
      ],
    );
  }
}
