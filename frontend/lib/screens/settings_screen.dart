import 'package:cats/widgets/settings/pipeline_default_settings.dart';
import 'package:cats/widgets/settings/reset_all.dart';
import 'package:cats/widgets/settings/warning_settings.dart';
import 'package:flutter/material.dart';
import 'package:cats/widgets/settings/backend_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const List<String> _categories = ["Backend", "Pipeline Defaults", "Warnings"];
  int _selectedIndex = 0;
  int _resetKey = 0;

  List<Widget> get _settingsWidgets => [
    BackendSettingsScreen(key: ValueKey('backend_$_resetKey')),
    PipelineDefaultSettingsScreen(key: ValueKey('pipeline_$_resetKey')),
    WarningsSettingScreen(key: ValueKey('warnings_$_resetKey')),
  ];

  void _handleReset() {
    setState(() {
      _resetKey++; // Increment key to force widget rebuilds
    });
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.primary),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Settings", style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    ...[
                      for (var i = 0; i < _categories.length; i++)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedIndex = i;
                            });
                          },
                          child: Container(
                            color:
                                _selectedIndex == i
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : Theme.of(context).colorScheme.surface,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              child: Text(_categories[i]),
                            ),
                          ),
                        ),
                    ],
                    Expanded(child: Container()),
                    RestoreDefaultsButton(onReset: _handleReset),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(child: SingleChildScrollView(child: _settingsWidgets[_selectedIndex])),
          ],
        ),
      ),
    );
  }
}
