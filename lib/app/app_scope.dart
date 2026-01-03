import 'package:flutter/material.dart';
import 'package:whatsapp_catalog/features/catalog/domain/repositories/catalog_repository.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    required this.catalogRepository,
    required this.themeMode,
    required super.child,
    super.key,
  });

  final CatalogRepository catalogRepository;
  final ValueNotifier<ThemeMode> themeMode;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    if (scope == null) {
      throw StateError('AppScope not found');
    }
    return scope;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) {
    return catalogRepository != oldWidget.catalogRepository ||
        themeMode != oldWidget.themeMode;
  }
}
