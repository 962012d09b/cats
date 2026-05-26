import 'package:cats/constants.dart';
import 'package:cats/providers/settings_provider.dart';
import 'package:cats/utility/http_utility.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:http/http.dart' as http;

part 'generated/connection_provider.g.dart';

@riverpod
class BackendUri extends _$BackendUri {
  static Uri _parseDefault() {
    final parsed = Uri.parse(defaultHost);
    return Uri(scheme: parsed.scheme, host: parsed.host, port: defaultPort);
  }

  @override
  Uri build() {
    ref.keepAlive();
    _loadSettings();
    return _parseDefault();
  }

  Future<void> _loadSettings() async {
    final scheme = await SettingsHelper.loadString('backend_scheme');
    final host = await SettingsHelper.loadString('backend_host');
    final port = await SettingsHelper.loadInt('backend_port');
    final def = _parseDefault();

    state = Uri(scheme: scheme ?? def.scheme, host: host ?? def.host, port: port ?? defaultPort);
  }

  void setHost(String input) {
    final parsed = Uri.tryParse(input);
    final String scheme;
    final String host;
    if (parsed != null && parsed.host.isNotEmpty) {
      scheme = parsed.scheme.isNotEmpty ? parsed.scheme : 'http';
      host = parsed.host;
    } else {
      scheme = 'http';
      host = input;
    }
    if (host != state.host || scheme != state.scheme) {
      state = Uri(scheme: scheme, host: host, port: state.port);
      _saveSettings();
    }
  }

  void setPort(int port) {
    if (port != state.port) {
      state = Uri(scheme: state.scheme, host: state.host, port: port);
      _saveSettings();
    }
  }

  void resetToDefault() {
    state = _parseDefault();
    _saveSettings();
  }

  Future<void> _saveSettings() async {
    await SettingsHelper.saveString('backend_scheme', state.scheme);
    await SettingsHelper.saveString('backend_host', state.host);
    await SettingsHelper.saveInt('backend_port', state.port);
  }

  Future<void> resetDatabase() async {
    final response = await http.delete(
      state.replace(path: "/api/reinitialize_db"),
      headers: ref.read(credentialsHeaderProvider),
    );

    verifyResponse(response);

    ref.invalidateSelf();
  }
}

@riverpod
class Credentials extends _$Credentials {
  @override
  String build() {
    _loadSettings();
    return defaultCredentials;
  }

  Future<void> _loadSettings() async {
    final savedCredentials = await SettingsHelper.loadString('backend_credentials');
    if (savedCredentials != null) {
      state = savedCredentials;
    }
  }

  void set(String password) {
    if (password != state) {
      state = password;
      _saveSettings();
    }
  }

  void resetToDefault() {
    state = defaultCredentials;
    _saveSettings();
  }

  Future<void> _saveSettings() async {
    await SettingsHelper.saveString('backend_credentials', state);
  }
}

@riverpod
class CredentialsHeader extends _$CredentialsHeader {
  @override
  Map<String, String> build() {
    ref.keepAlive();
    String password = ref.watch(credentialsProvider);
    return {"Authorization": "Bearer $password"};
  }
}
