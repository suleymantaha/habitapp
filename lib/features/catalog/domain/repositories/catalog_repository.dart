import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog.dart';

abstract interface class CatalogRepository {
  Stream<List<Catalog>> watchCatalogs();
  Future<void> upsertCatalog(Catalog catalog);
  Future<void> deleteCatalog(String catalogId);
  Future<Catalog?> getCatalog(String catalogId);
}
