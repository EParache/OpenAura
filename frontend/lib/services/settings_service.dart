// Deteccion automatica de URL de API.
// Desktop: IP LAN. Web: URLs relativas. AURA_API_URL tiene prioridad.
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class SettingsService {
  String _baseUrl;
  static const _envVar = 'AURA_API_URL';
  static const _port = 8000;

  SettingsService._(this._baseUrl);

  String get baseUrl => _baseUrl;

  static Future<SettingsService> detect() async {
    if (kIsWeb) return SettingsService._('');
    final env = Platform.environment[_envVar];
    if (env != null && env.isNotEmpty) {
      return SettingsService._(_normalize(env));
    }
    final ip = await _localIp();
    return SettingsService._('http://$ip:$_port');
  }

  void updateUrl(String url) {
    _baseUrl = _normalize(url);
  }

  static String _normalize(String url) {
    if (url.isEmpty) return url;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static Future<String> _localIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return 'localhost';
  }
}
