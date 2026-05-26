import 'dart:convert';
import 'package:cats/constants.dart';
import 'package:cats/models/settings.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'generated/settings_provider.g.dart';

@riverpod
class Warning extends _$Warning {
  @override
  WarningSettings build() {
    ref.keepAlive();
    _loadSettings();
    return WarningSettings(warnExcludedSelected: defaultWarnExcludedSelected);
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsHelper.loadJson('warning_settings', WarningSettings.fromJson);
    if (settings != null) {
      state = settings;
    }
  }

  void toggleWarnExcludedSelected() {
    state = state.copyWith(warnExcludedSelected: !state.warnExcludedSelected);
    _saveSettings();
  }

  void resetToDefault() {
    state = WarningSettings(warnExcludedSelected: defaultWarnExcludedSelected);
    _saveSettings();
  }

  Future<void> _saveSettings() async {
    await SettingsHelper.saveJson('warning_settings', state, (settings) => settings.toJson());
  }
}

@riverpod
class GlobalPipelineDefaults extends _$GlobalPipelineDefaults {
  @override
  PipelineSettings build() {
    ref.keepAlive();
    _loadSettings();
    return PipelineSettings(defaultRiskScore: defaultRiskScore, averagingMethod: defaultAveragingMethod);
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsHelper.loadJson('pipeline_settings', PipelineSettings.fromJson);
    if (settings != null) {
      state = settings;
    }
  }

  void setDefaultRiskScore(double riskScore) {
    state = state.copyWith(defaultRiskScore: riskScore);
    _saveSettings();
  }

  void setDefaultAveragingMethod(List<bool> averagingMethod) {
    state = state.copyWith(averagingMethod: averagingMethod);
    _saveSettings();
  }

  void resetToDefault() {
    state = PipelineSettings(defaultRiskScore: defaultRiskScore, averagingMethod: defaultAveragingMethod);
    _saveSettings();
  }

  Future<void> _saveSettings() async {
    await SettingsHelper.saveJson('pipeline_settings', state, (settings) => settings.toJson());
  }
}

@riverpod
class AppThemeMode extends _$AppThemeMode {
  @override
  Future<ThemeMode> build() async {
    final savedTheme = await SettingsHelper.loadString('theme_mode');
    if (savedTheme != null) {
      switch (savedTheme) {
        case 'light':
          return ThemeMode.light;
        case 'dark':
          return ThemeMode.dark;
        case 'system':
          return ThemeMode.system;
      }
    }
    return ThemeMode.system; // Default to system theme
  }

  void setThemeMode(ThemeMode themeMode) {
    state = AsyncValue.data(themeMode);
    _saveSettings(themeMode);
  }

  Future<void> _saveSettings(ThemeMode themeMode) async {
    final themeString = switch (themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await SettingsHelper.saveString('theme_mode', themeString);
  }
}

class SettingsHelper {
  static Future<T?> loadJson<T>(String key, T Function(Map<String, dynamic>) fromJson) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(key);
    if (jsonString != null) {
      try {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        return fromJson(json);
      } catch (e) {
        await prefs.remove(key);
        return null;
      }
    }
    return null;
  }

  static Future<void> saveJson<T>(String key, T settings, Map<String, dynamic> Function(T) toJson) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(toJson(settings));
    await prefs.setString(key, json);
  }

  static Future<String?> loadString(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (e) {
      return null;
    }
  }

  static Future<int?> loadInt(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(key);
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveString(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      return;
    }
  }

  static Future<void> saveInt(String key, int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, value);
    } catch (e) {
      return;
    }
  }
}
