import 'package:shared_preferences/shared_preferences.dart';
import 'package:whatsapp_catalog/core/analytics/app_analytics.dart';
import 'package:whatsapp_catalog/core/public_menu/public_menu_client.dart';
import 'package:whatsapp_catalog/core/public_menu/public_menu_link_store.dart';
import 'package:whatsapp_catalog/core/settings/app_settings.dart';
import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog.dart';
import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog_item.dart';
import 'package:whatsapp_catalog/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/shared/view_model.dart';

class ProductEditorViewModel extends ViewModel {
  ProductEditorViewModel({
    required CatalogRepository repository,
    required String catalogId,
    required String? itemId,
  }) : _repository = repository,
       _catalogId = catalogId,
       _itemId = itemId;

  final CatalogRepository _repository;
  final String _catalogId;
  final String? _itemId;

  static String _lastSectionKey(String catalogId) => 'last_section:$catalogId';
  static String _lastSubsectionKey(String catalogId) =>
      'last_subsection:$catalogId';

  Catalog? get catalog => _catalog;
  Catalog? _catalog;
  CatalogItem? get item => _item;
  CatalogItem? _item;

  String? get photoPath => _photoPath;
  String? _photoPath;

  String? get lastSection => _lastSection;
  String? _lastSection;

  String? get lastSubsection => _lastSubsection;
  String? _lastSubsection;

  bool didInitControllers = false;

  String? get validationMessage => _validationMessage;
  String? _validationMessage;

  Future<void> load() async {
    setBusy(value: true);
    try {
      _catalog = await _repository.getCatalog(_catalogId);
      _item = _catalog?.items.where((i) => i.id == _itemId).firstOrNull;
      _photoPath = _item?.photoPath;
      if (_item == null) {
        final prefs = await SharedPreferences.getInstance();
        _lastSection = prefs.getString(_lastSectionKey(_catalogId))?.trim();
        _lastSubsection = prefs
            .getString(_lastSubsectionKey(_catalogId))
            ?.trim();
        if (_lastSection != null && _lastSection!.isEmpty) _lastSection = null;
        if (_lastSubsection != null && _lastSubsection!.isEmpty) {
          _lastSubsection = null;
        }
      }
    } on Exception catch (e) {
      setError(e);
    } finally {
      setBusy(value: false);
    }
  }

  void setPhotoPath(String? value) {
    _photoPath = value;
    notifyListeners();
  }

  Future<bool> save({
    required String title,
    required String priceText,
    required String description,
    required String section,
    required String subsection,
  }) async {
    final catalog = _catalog;
    if (catalog == null) return false;

    final parsedPrice = double.tryParse(priceText.replaceAll(',', '.'));
    if (title.length < 2) {
      _validationMessage = 'Başlık en az 2 karakter olmalı.';
      notifyListeners();
      return false;
    }
    if (parsedPrice == null || parsedPrice < 0) {
      _validationMessage = 'Fiyat geçerli olmalı.';
      notifyListeners();
      return false;
    }

    _validationMessage = null;
    notifyListeners();

    setBusy(value: true);
    try {
      final now = DateTime.now();
      final isCreate = _item == null;
      final cleanedSection = section.trim();
      final cleanedSubsection = subsection.trim();
      final finalSection = cleanedSection.isEmpty ? null : cleanedSection;
      final finalSubsection = cleanedSubsection.isEmpty
          ? null
          : cleanedSubsection;
      final nextItem = (_item == null)
          ? CatalogItem(
              id: now.microsecondsSinceEpoch.toString(),
              title: title,
              price: parsedPrice,
              description: description,
              photoPath: _photoPath,
              section: finalSection,
              subsection: finalSubsection,
            )
          : _item!.copyWith(
              title: title,
              price: parsedPrice,
              description: description,
              photoPath: _photoPath,
              section: finalSection,
              subsection: finalSubsection,
            );

      final nextItems = [
        for (final i in catalog.items)
          if (i.id == nextItem.id) nextItem else i,
        if (_item == null) nextItem,
      ];

      final nextCatalog = catalog.copyWith(items: nextItems, updatedAt: now);
      await _repository.upsertCatalog(nextCatalog);
      await _maybePublishPublicMenu(nextCatalog);
      final prefs = await SharedPreferences.getInstance();
      if (finalSection == null) {
        await prefs.remove(_lastSectionKey(_catalogId));
      } else {
        await prefs.setString(_lastSectionKey(_catalogId), finalSection);
      }
      if (finalSubsection == null) {
        await prefs.remove(_lastSubsectionKey(_catalogId));
      } else {
        await prefs.setString(_lastSubsectionKey(_catalogId), finalSubsection);
      }
      await AppAnalytics.log(isCreate ? 'item_create' : 'item_update');
      return true;
    } on Exception catch (e) {
      setError(e);
      return false;
    } finally {
      setBusy(value: false);
    }
  }

  Future<bool> delete() async {
    final catalog = _catalog;
    final current = _item;
    if (catalog == null || current == null) return false;

    setBusy(value: true);
    try {
      final now = DateTime.now();
      final nextCatalog = catalog.copyWith(
        items: catalog.items
            .where((i) => i.id != current.id)
            .toList(growable: false),
        updatedAt: now,
      );
      await _repository.upsertCatalog(nextCatalog);
      await _maybePublishPublicMenu(nextCatalog);
      await AppAnalytics.log('item_delete');
      return true;
    } on Exception catch (e) {
      setError(e);
      return false;
    } finally {
      setBusy(value: false);
    }
  }

  Future<void> _maybePublishPublicMenu(Catalog catalog) async {
    try {
      final baseUrl = await AppSettings.getPublicMenuBaseUrl();
      if (baseUrl == null || baseUrl.isEmpty) return;
      final link = await PublicMenuLinkStore.get(catalog.id);
      if (link == null) return;
      await PublicMenuClient(baseUrl: baseUrl).updateMenu(
        id: link.id,
        editToken: link.editToken,
        catalog: catalog,
      );
    } on Exception {
      return;
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
