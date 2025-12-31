import 'dart:async';

import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog.dart';
import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog_item.dart';
import 'package:whatsapp_catalog/features/catalog/domain/usecases/create_catalog.dart';
import 'package:whatsapp_catalog/features/catalog/domain/usecases/delete_catalog.dart';
import 'package:whatsapp_catalog/features/catalog/domain/usecases/watch_catalogs.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/shared/view_model.dart';
import 'package:whatsapp_catalog/core/analytics/app_analytics.dart';

class HomeViewModel extends ViewModel {
  HomeViewModel({
    required WatchCatalogs watchCatalogs,
    required CreateCatalog createCatalog,
    required DeleteCatalog deleteCatalog,
  }) : _watchCatalogs = watchCatalogs,
       _createCatalog = createCatalog,
       _deleteCatalog = deleteCatalog;

  final WatchCatalogs _watchCatalogs;
  final CreateCatalog _createCatalog;
  final DeleteCatalog _deleteCatalog;

  List<Catalog> get catalogs => _catalogs;
  List<Catalog> _catalogs = const [];

  StreamSubscription<List<Catalog>>? _subscription;

  void start() {
    _subscription ??= _watchCatalogs().listen((items) {
      _catalogs = items;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<String?> createCatalog({
    required String name,
    required String currencyCode,
    String templateId = 'minimal_green',
  }) async {
    setBusy(true);
    setError(null);
    try {
      final now = DateTime.now();
      final id = now.microsecondsSinceEpoch.toString();
      final catalog = Catalog(
        id: id,
        name: name,
        items: const [],
        selectedTemplateId: templateId,
        currencyCode: currencyCode,
        updatedAt: now,
      );
      await _createCatalog(catalog);
      await AppAnalytics.log('catalog_create');
      return id;
    } catch (e) {
      setError(e);
      return null;
    } finally {
      setBusy(false);
    }
  }

  Future<bool> deleteCatalog(String catalogId) async {
    setBusy(true);
    setError(null);
    try {
      await _deleteCatalog(catalogId);
      await AppAnalytics.log('catalog_delete');
      return true;
    } catch (e) {
      setError(e);
      return false;
    } finally {
      setBusy(false);
    }
  }

  Future<bool> restoreCatalog(Catalog catalog) async {
    setBusy(true);
    setError(null);
    try {
      await _createCatalog(catalog);
      await AppAnalytics.log('catalog_restore');
      return true;
    } catch (e) {
      setError(e);
      return false;
    } finally {
      setBusy(false);
    }
  }

  Future<String?> createDemoCatalog() async {
    setBusy(true);
    setError(null);
    try {
      final now = DateTime.now();
      final id = now.microsecondsSinceEpoch.toString();
      final demo = Catalog(
        id: id,
        name: 'Örnek Menü',
        items: const [
          CatalogItem(
            id: 'i1',
            title: 'Ev yapımı mantı',
            price: 180,
            description: '500g, yoğurt ve sos ayrı',
            photoPath: null,
            section: 'Ana yemek',
            subsection: 'Ev yapımı',
          ),
          CatalogItem(
            id: 'i2',
            title: 'Çiğ köfte dürüm',
            price: 90,
            description: 'Acı/acı değil seçeneği',
            photoPath: null,
            section: 'Dürümler',
            subsection: '',
          ),
          CatalogItem(
            id: 'i3',
            title: 'Trileçe',
            price: 75,
            description: 'Dilim',
            photoPath: null,
            section: 'Tatlı',
            subsection: '',
          ),
        ],
        selectedTemplateId: 'soft_food',
        currencyCode: 'TRY',
        updatedAt: now,
      );
      await _createCatalog(demo);
      await AppAnalytics.log('catalog_create_demo');
      return id;
    } catch (e) {
      setError(e);
      return null;
    } finally {
      setBusy(false);
    }
  }
}
