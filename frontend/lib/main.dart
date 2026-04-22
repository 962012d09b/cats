import 'package:flutter/material.dart';
import 'package:cats/home.dart';
import 'package:cats/constants.dart';
import 'package:cats/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: CatsApp()));
}

class CatsApp extends ConsumerWidget {
  const CatsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeAsync = ref.watch(appThemeModeProvider);

    return themeAsync.when(
      loading:
          () => MaterialApp(
            theme: ThemeData(brightness: Brightness.light),
            darkTheme: ThemeData(brightness: Brightness.dark),
            home: const Scaffold(body: Center(child: CircularProgressIndicator())),
          ),
      error: (error, stack) => _CatsMainApp(themeMode: ThemeMode.system), // Fallback
      data: (themeMode) => _CatsMainApp(themeMode: themeMode),
    );
  }
}

class _CatsMainApp extends ConsumerStatefulWidget {
  const _CatsMainApp({this.themeMode});

  final ThemeMode? themeMode;

  @override
  ConsumerState<_CatsMainApp> createState() => _CatsMainAppState();
}

class _CatsMainAppState extends ConsumerState<_CatsMainApp> {
  ColorSeed colorSelected = ColorSeed.baseColor;
  Key key = UniqueKey();

  void handleBrightnessChange(bool useLightMode) {
    final newThemeMode = useLightMode ? ThemeMode.light : ThemeMode.dark;
    ref.read(appThemeModeProvider.notifier).setThemeMode(newThemeMode);
  }

  void handleColorSelect(int value) {
    setState(() {
      colorSelected = ColorSeed.values[value];
    });
  }

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = widget.themeMode ?? ThemeMode.system;

    final useLightMode = switch (themeMode) {
      ThemeMode.system => View.of(context).platformDispatcher.platformBrightness == Brightness.light,
      ThemeMode.light => true,
      ThemeMode.dark => false,
    };

    return MaterialApp(
      key: key,
      debugShowCheckedModeBanner: false,
      title: "CATS",
      themeMode: themeMode,
      theme: ThemeData(
        colorSchemeSeed: colorSelected.color,
        useMaterial3: true,
        brightness: Brightness.light,
        tooltipTheme: TooltipThemeData(waitDuration: Duration(milliseconds: 700)),
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: colorSelected.color,
        brightness: Brightness.dark,
        tooltipTheme: TooltipThemeData(waitDuration: Duration(milliseconds: 700)),
      ),
      home: Home(
        useLightMode: useLightMode,
        colorSelected: colorSelected,
        handleBrightnessChange: handleBrightnessChange,
        handleColorSelect: handleColorSelect,
      ),
    );
  }
}
