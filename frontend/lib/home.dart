import 'package:cats/providers/connection_provider.dart';
import 'package:cats/widgets/pipelines/save_load_pipelines_menu.dart';
import 'package:cats/widgets/results/download_results_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cats/constants.dart';
import 'package:cats/screens/main_hub_screen.dart';
import 'package:cats/screens/settings_screen.dart';
import 'package:cats/widgets/pipelines/export_pipe_dialog.dart';
import 'package:cats/widgets/pipelines/import_pipe_dialog.dart';
import 'package:url_launcher/url_launcher_string.dart';

enum ScreenSelected {
  mainHub(0),
  settings(1);

  const ScreenSelected(this.value);
  final int value;
}

class Home extends StatefulWidget {
  const Home({
    super.key,
    required this.useLightMode,
    required this.colorSelected,
    required this.handleBrightnessChange,
    required this.handleColorSelect,
  });

  final bool useLightMode;
  final ColorSeed colorSelected;

  final void Function(bool useLightMode) handleBrightnessChange;
  final void Function(int value) handleColorSelect;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int screenIndex = ScreenSelected.mainHub.value;
  bool useHorizontalLayout = false;

  void handleScreenChange(int screenSelected) {
    setState(() {
      screenIndex = screenSelected;
    });
  }

  Widget createScreenFor(ScreenSelected screenSelected) => switch (screenSelected) {
    ScreenSelected.mainHub => ScreenOne(useHorizontalLayout: useHorizontalLayout),
    ScreenSelected.settings => const SettingsScreen(),
  };

  void toggleLayout() {
    setState(() {
      useHorizontalLayout = !useHorizontalLayout;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Tooltip(message: "All your alerts are belong to us", child: const Text("CATS")),
            SizedBox(width: 10),
            _DemoWarning(),
          ],
        ),
        elevation: 5,
        toolbarHeight: 45,
        actions: [
          Tooltip(
            message: "Download results as JSON",
            child: Padding(padding: const EdgeInsets.only(right: 16), child: DownloadResultsButton()),
          ),
          Tooltip(
            message: "Save or load pipeline configurations",
            child: Padding(padding: const EdgeInsets.only(right: 16), child: SaveLoadPipelinesMenu()),
          ),
          Tooltip(
            message: "Export current pipeline configuration as JSON",
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                iconSize: 22,
                onPressed: () => showDialog(
                  context: context,
                  builder: (BuildContext ctx) => const Dialog(child: ExportPipeDialog()),
                ),
                icon: const Icon(FontAwesomeIcons.fileExport),
              ),
            ),
          ),
          Tooltip(
            message: "Import a JSON pipeline configuration",
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                iconSize: 22,
                onPressed: () => showDialog(
                  context: context,
                  builder: (BuildContext ctx) => const Dialog(child: ImportPipeDialog()),
                ),
                icon: const Icon(FontAwesomeIcons.fileImport),
              ),
            ),
          ),
          Tooltip(
            message: "View on GitHub",
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                onPressed: () => launchUrlString(projectUrl),
                icon: const Icon(FontAwesomeIcons.github),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            minWidth: navRailWidth,
            destinations: navRailDestinations,
            selectedIndex: screenIndex,
            onDestinationSelected: (index) {
              setState(() {
                screenIndex = index;
                handleScreenChange(screenIndex);
              });
            },
            trailing: Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _TrailingActions(
                  handleBrightnessChange: widget.handleBrightnessChange,
                  colorSelected: widget.colorSelected,
                  handleColorSelect: widget.handleColorSelect,
                  handleLayoutToggle: toggleLayout,
                  useHorizontalLayout: useHorizontalLayout,
                ),
              ),
            ),
          ),
          VerticalDivider(thickness: 1, width: 1, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
          createScreenFor(ScreenSelected.values[screenIndex]),
        ],
      ),
    );
  }
}

class _TrailingActions extends StatelessWidget {
  const _TrailingActions({
    required this.handleBrightnessChange,
    required this.colorSelected,
    required this.handleColorSelect,
    required this.useHorizontalLayout,
    required this.handleLayoutToggle,
  });

  final void Function(bool useLightMode) handleBrightnessChange;
  final void Function(int value) handleColorSelect;
  final void Function() handleLayoutToggle;
  final ColorSeed colorSelected;
  final bool useHorizontalLayout;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: _ToggleLayoutButton(useHorizontalLayout: useHorizontalLayout, handleLayoutToggle: handleLayoutToggle),
        ),
        Flexible(child: _BrightnessButton(handleBrightnessChange: handleBrightnessChange)),
        Flexible(
          child: _ColorSeedButton(colorSelected: colorSelected, handleColorSelect: handleColorSelect),
        ),
      ],
    );
  }
}

class _ToggleLayoutButton extends StatelessWidget {
  const _ToggleLayoutButton({required this.useHorizontalLayout, required this.handleLayoutToggle});

  final bool useHorizontalLayout;
  final Function() handleLayoutToggle;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      preferBelow: true,
      message: "Switch layout",
      child: IconButton(
        onPressed: () => handleLayoutToggle(),
        icon: Icon(useHorizontalLayout ? FontAwesomeIcons.tableColumns : Icons.table_rows_outlined),
      ),
    );
  }
}

class _BrightnessButton extends StatelessWidget {
  const _BrightnessButton({required this.handleBrightnessChange});

  final Function handleBrightnessChange;

  @override
  Widget build(BuildContext context) {
    final isBright = Theme.of(context).brightness == Brightness.light;

    return Tooltip(
      preferBelow: true,
      message: "Toggle brightness",
      child: IconButton(
        icon: isBright ? const Icon(Icons.dark_mode_outlined) : const Icon(Icons.light_mode_outlined),
        onPressed: () => handleBrightnessChange(!isBright),
      ),
    );
  }
}

class _ColorSeedButton extends StatelessWidget {
  const _ColorSeedButton({required this.colorSelected, required this.handleColorSelect});

  final void Function(int) handleColorSelect;
  final ColorSeed colorSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      icon: Icon(Icons.palette_outlined, color: colorSelected.color),
      tooltip: "Select a seed color",
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (context) {
        return List.generate(ColorSeed.values.length, (index) {
          ColorSeed currentColor = ColorSeed.values[index];

          return PopupMenuItem(
            value: index,
            enabled: currentColor != colorSelected,
            child: Wrap(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Icon(
                    currentColor == colorSelected ? Icons.color_lens : Icons.color_lens_outlined,
                    color: currentColor.color,
                  ),
                ),
                Padding(padding: const EdgeInsets.only(left: 20), child: Text(currentColor.label)),
              ],
            ),
          );
        });
      },
      onSelected: handleColorSelect,
    );
  }
}

class _DemoWarning extends ConsumerStatefulWidget {
  const _DemoWarning();

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => __DemoWarningState();
}

class __DemoWarningState extends ConsumerState<_DemoWarning> {
  @override
  Widget build(BuildContext context) {
    var currentUri = ref.watch(backendUriProvider);

    if (Uri.parse(defaultHost).host == currentUri.host && defaultPort == currentUri.port) {
      return Tooltip(
        message:
            "Backend operates in read-only mode.\nAll modifying actions (editing or adding datasets/modules, saving, loading) will result in an error.\nVisit the GitHub repo to set up your own instance in 10 seconds!",
        constraints: BoxConstraints(maxWidth: 300),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined, size: 32, color: Theme.of(context).colorScheme.error),
            Text("Using demo backend", style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error)),
          ],
        ),
      );
    } else {
      return Container();
    }
  }
}
