import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog.dart';
import 'package:whatsapp_catalog/features/catalog/domain/repositories/catalog_repository.dart';

class CreateCatalog {
  const CreateCatalog(this._repository);

  final CatalogRepository _repository;

  Future<void> call(Catalog catalog) => _repository.upsertCatalog(catalog);
}
