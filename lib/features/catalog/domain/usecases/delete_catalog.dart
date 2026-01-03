import 'package:whatsapp_catalog/features/catalog/domain/repositories/catalog_repository.dart';

class DeleteCatalog {
  const DeleteCatalog(this._repository);

  final CatalogRepository _repository;

  Future<void> call(String catalogId) => _repository.deleteCatalog(catalogId);
}
