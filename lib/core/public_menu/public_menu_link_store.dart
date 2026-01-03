import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PublicMenuLinkStore {
  static const _keyLinks = 'public_menu_links_v1';

  static Future<PublicMenuLink?> get(String catalogId) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _read(prefs);
    final raw = map[catalogId];
    if (raw is! Map) return null;
    final id = raw['id'];
    final editToken = raw['editToken'];
    if (id is! String || editToken is! String) return null;
    return PublicMenuLink(id: id, editToken: editToken);
  }

  static Future<void> set(String catalogId, PublicMenuLink link) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _read(prefs);
    map[catalogId] = {'id': link.id, 'editToken': link.editToken};
    await prefs.setString(_keyLinks, jsonEncode(map));
  }

  static Map<String, Object?> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_keyLinks);
    if (raw == null || raw.isEmpty) return <String, Object?>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, Object?>{};
      return Map<String, Object?>.from(decoded);
    } on Exception {
      return <String, Object?>{};
    }
  }
}

class PublicMenuLink {
  const PublicMenuLink({required this.id, required this.editToken});

  final String id;
  final String editToken;
}
