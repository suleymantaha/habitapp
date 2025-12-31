import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog.dart';
import 'package:whatsapp_catalog/features/catalog/domain/repositories/catalog_repository.dart';

class WatchCatalogs {
  const WatchCatalogs(this._repository);

  final CatalogRepository _repository;

  Stream<List<Catalog>> call() => _repository.watchCatalogs();
}

