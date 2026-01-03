import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:whatsapp_catalog/features/catalog/data/serializers/catalog_json.dart';
import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog.dart';
import 'package:whatsapp_catalog/features/catalog/domain/repositories/catalog_repository.dart';

class SharedPrefsCatalogRepository implements CatalogRepository {
  SharedPrefsCatalogRepository._(this._prefs, this._cache);
  static const _keyCatalogs = 'catalogs_v1';

  final _controller = StreamController<List<Catalog>>.broadcast();
  final List<Catalog> _cache;
  final SharedPreferences _prefs;

  static Future<SharedPrefsCatalogRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    final cache = _readFromPrefs(prefs);
    return SharedPrefsCatalogRepository._(prefs, cache);
  }

  @override
  Stream<List<Catalog>> watchCatalogs() async* {
    yield List.unmodifiable(_cache);
    yield* _controller.stream;
  }

  @override
  Future<void> upsertCatalog(Catalog catalog) async {
    final index = _cache.indexWhere((c) => c.id == catalog.id);
    if (index == -1) {
      _cache.add(catalog);
    } else {
      _cache[index] = catalog;
    }
    _cache.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persist();
    _emit();
  }

  @override
  Future<void> deleteCatalog(String catalogId) async {
    _cache.removeWhere((c) => c.id == catalogId);
    await _persist();
    _emit();
  }

  @override
  Future<Catalog?> getCatalog(String catalogId) async {
    return _cache.where((c) => c.id == catalogId).firstOrNull;
  }

  Future<void> _persist() async {
    final jsonList = [for (final c in _cache) catalogToJson(c)];
    await _prefs.setString(_keyCatalogs, jsonEncode(jsonList));
  }

  void _emit() {
    _controller.add(List.unmodifiable(_cache));
  }

  static List<Catalog> _readFromPrefs(SharedPreferences prefs) {
    final raw = prefs.getString(_keyCatalogs);
    if (raw == null || raw.isEmpty) return <Catalog>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Catalog>[];
      final result = <Catalog>[];
      for (final entry in decoded) {
        if (entry is Map) {
          result.add(catalogFromJson(Map<String, Object?>.from(entry)));
        }
      }
      result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return result;
    } on Exception {
      return <Catalog>[];
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
