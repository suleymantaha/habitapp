import 'dart:async';

import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog.dart';
import 'package:whatsapp_catalog/features/catalog/domain/repositories/catalog_repository.dart';

class InMemoryCatalogRepository implements CatalogRepository {
  InMemoryCatalogRepository() {
    _emit();
  }
  final _controller = StreamController<List<Catalog>>.broadcast();
  final List<Catalog> _cache = [];

  @override
  Stream<List<Catalog>> watchCatalogs() => _controller.stream;

  @override
  Future<void> upsertCatalog(Catalog catalog) async {
    final index = _cache.indexWhere((c) => c.id == catalog.id);
    if (index == -1) {
      _cache.add(catalog);
    } else {
      _cache[index] = catalog;
    }
    _cache.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _emit();
  }

  @override
  Future<void> deleteCatalog(String catalogId) async {
    _cache.removeWhere((c) => c.id == catalogId);
    _emit();
  }

  @override
  Future<Catalog?> getCatalog(String catalogId) async {
    return _cache.where((c) => c.id == catalogId).firstOrNull;
  }

  void _emit() {
    _controller.add(List.unmodifiable(_cache));
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
