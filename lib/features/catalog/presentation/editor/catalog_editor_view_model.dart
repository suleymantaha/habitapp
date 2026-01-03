import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog.dart';
import 'package:whatsapp_catalog/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/shared/view_model.dart';

class CatalogEditorViewModel extends ViewModel {
  CatalogEditorViewModel({
    required CatalogRepository repository,
    required String catalogId,
  }) : _repository = repository,
       _catalogId = catalogId;

  final CatalogRepository _repository;
  final String _catalogId;

  Catalog? get catalog => _catalog;
  Catalog? _catalog;

  Future<void> load() async {
    setBusy(value: true);
    try {
      _catalog = await _repository.getCatalog(_catalogId);
    } on Exception catch (e) {
      setError(e);
    } finally {
      setBusy(value: false);
    }
  }

  Future<void> rename(String name) async {
    final current = _catalog;
    if (current == null) return;
    final trimmed = name.trim();
    if (trimmed.length < 2) return;
    setBusy(value: true);
    try {
      final next = current.copyWith(name: trimmed, updatedAt: DateTime.now());
      await _repository.upsertCatalog(next);
      _catalog = next;
      notifyListeners();
    } on Exception catch (e) {
      setError(e);
    } finally {
      setBusy(value: false);
    }
  }
}
