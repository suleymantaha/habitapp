import 'package:flutter/material.dart';

import 'package:whatsapp_catalog/app/app.dart';
import 'package:whatsapp_catalog/app/app_scope.dart';
import 'package:whatsapp_catalog/core/analytics/app_analytics.dart';
import 'package:whatsapp_catalog/features/catalog/data/repositories/shared_prefs_catalog_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppAnalytics.init();
  await AppAnalytics.log('app_open');
  final catalogRepository = await SharedPrefsCatalogRepository.create();
  runApp(
    AppScope(
      catalogRepository: catalogRepository,
      child: const App(),
    ),
  );
}
