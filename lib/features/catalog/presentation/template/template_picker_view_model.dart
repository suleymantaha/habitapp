import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog.dart';
import 'package:whatsapp_catalog/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/shared/view_model.dart';

class TemplateItemVm {
  const TemplateItemVm({required this.id, required this.title, required this.subtitle});

  final String id;
  final String title;
  final String subtitle;
}

class TemplatePickerViewModel extends ViewModel {
  TemplatePickerViewModel({required CatalogRepository repository, required String catalogId})
      : _repository = repository,
        _catalogId = catalogId;

  final CatalogRepository _repository;
  final String _catalogId;

  Catalog? _catalog;

  String? get selectedTemplateId => _catalog?.selectedTemplateId;

  List<TemplateItemVm> get templates => const [
        TemplateItemVm(
          id: 'minimal_green',
          title: 'Minimal Green',
          subtitle: 'Temiz görünüm, hızlı okuma',
        ),
        TemplateItemVm(
          id: 'soft_food',
          title: 'Soft Food',
          subtitle: 'Yemek menüsü odaklı',
        ),
        TemplateItemVm(
          id: 'beauty_clean',
          title: 'Beauty Clean',
          subtitle: 'Salon hizmetleri için',
        ),
        TemplateItemVm(
          id: 'boutique_bold',
          title: 'Boutique Bold',
          subtitle: 'Ürün kataloğu için güçlü vurgu',
        ),
      ];

  Future<void> load() async {
    setBusy(true);
    try {
      _catalog = await _repository.getCatalog(_catalogId);
    } catch (e) {
      setError(e);
    } finally {
      setBusy(false);
    }
  }

  Future<void> select(String templateId) async {
    final catalog = _catalog;
    if (catalog == null) return;

    setBusy(true);
    try {
      final next = catalog.copyWith(
        selectedTemplateId: templateId,
        updatedAt: DateTime.now(),
      );
      await _repository.upsertCatalog(next);
      _catalog = next;
      notifyListeners();
    } catch (e) {
      setError(e);
    } finally {
      setBusy(false);
    }
  }
}

