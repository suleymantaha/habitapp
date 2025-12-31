import 'package:flutter/widgets.dart';
import 'package:whatsapp_catalog/features/catalog/domain/repositories/catalog_repository.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.catalogRepository,
    required super.child,
  });

  final CatalogRepository catalogRepository;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    if (scope == null) {
      throw StateError('AppScope not found');
    }
    return scope;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) {
    return catalogRepository != oldWidget.catalogRepository;
  }
}

