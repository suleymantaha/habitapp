import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const _keyShareAppUrl = 'share_app_url';
  static const _keyPremiumEnabled = 'premium_enabled';
  static const _keyPublicMenuBaseUrl = 'public_menu_base_url';
  static const _defaultPublicMenuBaseUrl = 'https://myshop-menu.myshop.workers.dev';

  static Future<String?> getShareAppUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyShareAppUrl)?.trim();
    if (value != null && value.isNotEmpty) return value;
    final fallback = prefs.getString(_keyPublicMenuBaseUrl)?.trim();
    return (fallback == null || fallback.isEmpty) ? null : fallback;
  }

  static Future<void> setShareAppUrl(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = value?.trim();
    if (cleaned == null || cleaned.isEmpty) {
      await prefs.remove(_keyShareAppUrl);
      return;
    }
    await prefs.setString(_keyShareAppUrl, cleaned);
  }

  static Future<bool> getPremiumEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPremiumEnabled) ?? false;
  }

  static Future<void> setPremiumEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPremiumEnabled, value);
  }

  static Future<String?> getPublicMenuBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPublicMenuBaseUrl)?.trim();
    final cleaned = _normalizeUrl(raw);
    if (cleaned == null) return _defaultPublicMenuBaseUrl;

    final migrated = _migrateWorkersDevHost(cleaned);
    if (migrated != cleaned) {
      await prefs.setString(_keyPublicMenuBaseUrl, migrated);
      return migrated;
    }
    return cleaned;
  }

  static Future<void> setPublicMenuBaseUrl(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = _normalizeUrl(value?.trim());
    if (cleaned == null || cleaned.isEmpty) {
      await prefs.remove(_keyPublicMenuBaseUrl);
      return;
    }
    await prefs.setString(_keyPublicMenuBaseUrl, cleaned);
  }

  static String? _normalizeUrl(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return null;
    final withoutSlash = v.endsWith('/') ? v.substring(0, v.length - 1) : v;
    return withoutSlash.isEmpty ? null : withoutSlash;
  }

  static String _migrateWorkersDevHost(String value) {
    Uri uri;
    try {
      uri = Uri.parse(value);
    } catch (_) {
      return value;
    }

    final host = uri.host;
    if (host == 'myshop-menu.suleymantahab.workers.dev') {
      return uri.replace(host: 'myshop-menu.myshop.workers.dev').toString();
    }
    if (host == 'whatsapp-catalog-public-menu.suleymantahab.workers.dev') {
      return uri.replace(host: 'myshop-menu.myshop.workers.dev').toString();
    }
    return value;
  }
}
