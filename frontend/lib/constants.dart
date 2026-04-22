import 'package:flutter/material.dart';

const double navRailWidth = 90;
const double datasetCardHeight = 250;
const double datasetCardWidth = 300;
const double moduleOverviewHeight = 180;
const double moduleOverviewWidth = 250;
const double moduleInstanceHeight = 415;
const double moduleInstanceWidth = 300;

const int largeScreenMinSize = 1921;
const int mediumScreenMinSize = 1800;
// const int smallScreenMinSize = 1500;

const String projectUrl = "https://github.com/962012d09b/cats";

// setting fallback values
const String defaultHost = "http://127.0.0.1";
const int defaultPort = 47126;
const String defaultCredentials = "da46d0ec15764ea5e9c79f8506f8e97a";
const bool defaultWarnExcludedSelected = true;
const double defaultRiskScore = 0.5;
const List<bool> defaultAveragingMethod = [true, false];

// this can be set to basically whatever, but there must be an according number of colors in the plotColors list
// also, I think it is sensible to set the user constraints
const int maximumPipelines = 5;

// for preventing floating point errors, used by some widgets
const int precision = 1000;
double roundToPrecision(double value) {
  return (value * precision).roundToDouble() / precision;
}

const List<Color> plotColors = [
  Color.fromARGB(255, 213, 94, 0),
  Color.fromARGB(255, 15, 133, 202),
  Color.fromARGB(255, 240, 228, 66),
  Color.fromARGB(255, 0, 158, 115),
  Color.fromARGB(255, 204, 121, 167),
];

Color plotFpColor = plotColors[0];
Color plotTpColor = plotColors[3];
Color plotUnknownColor = Colors.grey;

enum ColorSeed {
  baseColor('Default', Color.fromARGB(255, 23, 156, 125)),
  indigo('Indigo', Colors.indigo),
  blue('Blue', Colors.blue),
  teal('Teal', Colors.teal),
  green('Green', Colors.green),
  yellow('Yellow', Colors.yellow),
  orange('Orange', Colors.orange),
  deepOrange('Deep Orange', Colors.deepOrange),
  pink('Pink', Colors.pink);

  const ColorSeed(this.label, this.color);
  final String label;
  final Color color;
}

const List<String> screenLabels = ["Main Page", "Settings"];

List<NavigationRailDestination> navRailDestinations = [
  NavigationRailDestination(
    icon: Tooltip(message: screenLabels[0], child: const Icon(Icons.home_outlined)),
    label: Text(screenLabels[0]),
    selectedIcon: Tooltip(message: screenLabels[0], child: const Icon(Icons.home)),
  ),
  NavigationRailDestination(
    icon: Tooltip(message: screenLabels[1], child: const Icon(Icons.settings_outlined)),
    label: Text(screenLabels[1]),
    selectedIcon: Tooltip(message: screenLabels[1], child: const Icon(Icons.settings)),
  ),
];
