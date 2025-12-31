import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog.dart';
import 'package:whatsapp_catalog/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/shared/view_model.dart';
import 'package:whatsapp_catalog/core/share/whatsapp_share.dart';

class ExportShareViewModel extends ViewModel {
  ExportShareViewModel({required CatalogRepository repository, required String catalogId})
      : _repository = repository,
        _catalogId = catalogId;

  final CatalogRepository _repository;
  final String _catalogId;

  Catalog? get catalog => _catalog;
  Catalog? _catalog;

  String get shareText => _shareText ?? '';
  String? _shareText;

  String get whatsappUrl => _whatsappUrl ?? '';
  String? _whatsappUrl;

  Future<void> load() async {
    setBusy(true);
    try {
      _catalog = await _repository.getCatalog(_catalogId);
      final c = _catalog;
      if (c != null) {
        _shareText = buildCatalogShareText(
          catalogName: c.name,
          currencyCode: c.currencyCode,
          items: [
            for (final i in c.items) CatalogShareItem(title: i.title, price: i.price),
          ],
        );
        _whatsappUrl = buildWhatsAppSendUrl(text: _shareText!);
      }
    } catch (e) {
      setError(e);
    } finally {
      setBusy(false);
    }
  }
}
