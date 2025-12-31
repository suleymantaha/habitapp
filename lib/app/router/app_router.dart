import 'package:flutter/material.dart';
import 'package:whatsapp_catalog/app/router/app_routes.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/editor/catalog_editor_page.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/export/export_share_page.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/export/pdf_export_page.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/export/story_export_page.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/home/home_page.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/product/product_editor_page.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/qr/qr_preview_page.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/template/template_picker_page.dart';
import 'package:whatsapp_catalog/features/premium/presentation/paywall_page.dart';
import 'package:whatsapp_catalog/features/settings/presentation/settings_page.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (context) {
        return switch (settings.name) {
          AppRoutes.home => const HomePage(),
          AppRoutes.catalogEditor => CatalogEditorPage.fromSettings(settings),
          AppRoutes.productEditor => ProductEditorPage.fromSettings(settings),
          AppRoutes.templatePicker => TemplatePickerPage.fromSettings(settings),
          AppRoutes.exportShare => ExportSharePage.fromSettings(settings),
          AppRoutes.qrPreview => QrPreviewPage.fromSettings(settings),
          AppRoutes.storyExport => StoryExportPage.fromSettings(settings),
          AppRoutes.pdfExport => PdfExportPage.fromSettings(settings),
          AppRoutes.paywall => const PaywallPage(),
          AppRoutes.settings => const SettingsPage(),
          _ => const HomePage(),
        };
      },
    );
  }
}
