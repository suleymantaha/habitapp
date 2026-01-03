import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AppAnalytics {
  static const _keyInitialized = 'analytics_initialized';
  static const _keyCounts = 'analytics_counts';
  static const _keyLastEvent = 'analytics_last_event';
  static const _keyLastEventAtMs = 'analytics_last_event_at_ms';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyInitialized) ?? false) return;
    await prefs.setBool(_keyInitialized, true);
  }

  static Future<void> log(String event) async {
    final prefs = await SharedPreferences.getInstance();
    final counts = _readCounts(prefs);
    counts[event] = (counts[event] ?? 0) + 1;
    await prefs.setString(_keyCounts, jsonEncode(counts));
    await prefs.setString(_keyLastEvent, event);
    await prefs.setInt(
      _keyLastEventAtMs,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<Map<String, int>> getCounts() async {
    final prefs = await SharedPreferences.getInstance();
    return _readCounts(prefs);
  }

  static Future<String> buildReport() async {
    final prefs = await SharedPreferences.getInstance();
    final counts = _readCounts(prefs);
    final lastEvent = prefs.getString(_keyLastEvent);
    final lastAtMs = prefs.getInt(_keyLastEventAtMs);

    final buffer = StringBuffer()
      ..writeln('Analytics raporu')
      ..writeln('Tarih: ${DateTime.now().toIso8601String()}');
    if (lastEvent != null && lastAtMs != null) {
      buffer.writeln(
        'Son event: $lastEvent (${DateTime.fromMillisecondsSinceEpoch(lastAtMs).toIso8601String()})',
      );
    }
    buffer.writeln();

    final keys = counts.keys.toList()..sort();
    if (keys.isEmpty) {
      buffer.writeln('Event yok.');
      return buffer.toString().trim();
    }
    for (final k in keys) {
      buffer.writeln('- $k: ${counts[k]}');
    }
    return buffer.toString().trim();
  }

  static Map<String, int> _readCounts(SharedPreferences prefs) {
    final raw = prefs.getString(_keyCounts);
    if (raw == null || raw.isEmpty) return <String, int>{};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, int>{};
    final result = <String, int>{};
    for (final entry in decoded.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is String && value is num) {
        result[key] = value.toInt();
      }
    }
    return result;
  }
}
