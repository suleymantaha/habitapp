import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whatsapp_catalog/app/app_scope.dart';
import 'package:whatsapp_catalog/app/router/app_routes.dart';

import 'package:whatsapp_catalog/core/analytics/app_analytics.dart';
import 'package:whatsapp_catalog/core/public_menu/public_menu_client.dart';
import 'package:whatsapp_catalog/core/public_menu/public_menu_link_store.dart';
import 'package:whatsapp_catalog/core/settings/app_settings.dart';
import 'package:whatsapp_catalog/core/share/referral_share.dart';
import 'package:whatsapp_catalog/core/share/whatsapp_share.dart';
import 'package:whatsapp_catalog/core/ui/app_snackbar.dart';
import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog.dart';
import 'package:whatsapp_catalog/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/export/pdf_export_page.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/export/story_export_page.dart';

part 'qr_preview_actions.dart';
part 'qr_preview_widgets.dart';

class QrPreviewArgs {
  const QrPreviewArgs({required this.catalogId});
  final String catalogId;
}

class QrPreviewPage extends StatefulWidget {
  const QrPreviewPage({required this.args, super.key});

  factory QrPreviewPage.fromSettings(RouteSettings settings) {
    final args = settings.arguments as QrPreviewArgs?;
    if (args == null) {
      throw StateError('QrPreviewArgs required');
    }
    return QrPreviewPage(args: args);
  }

  final QrPreviewArgs args;

  @override
  State<QrPreviewPage> createState() => _QrPreviewPageState();
}

class _QrPreviewPageState extends State<QrPreviewPage> {
  final GlobalKey<State<StatefulWidget>> _qrRepaintKey = GlobalKey();

  late final CatalogRepository _repo;
  var _didInit = false;

  Catalog? _catalog;
  String? _qrData;
  String? _shareText;
  String? _whatsappUrl;
  var _loading = true;
  var _sharing = false;
  var _premiumEnabled = false;
  String? _appUrl;
  String? _publicMenuBaseUrl;
  var _publishing = false;
  String? _publishError;

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    _repo = AppScope.of(context).catalogRepository;
    unawaited(AppAnalytics.log('qr_open'));
    unawaited(
      AppSettings.getPremiumEnabled().then((value) {
        if (!mounted) return;
        _safeSetState(() => _premiumEnabled = value);
      }),
    );
    unawaited(
      AppSettings.getShareAppUrl().then((value) {
        if (!mounted) return;
        _safeSetState(() => _appUrl = value);
      }),
    );
    unawaited(
      AppSettings.getPublicMenuBaseUrl().then((value) {
        if (!mounted) return;
        _safeSetState(() => _publicMenuBaseUrl = value);
        unawaited(_load());
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wantsWebMenu = (_publicMenuBaseUrl ?? '').isNotEmpty;
    final hasQr = _qrData != null;
    final isWebMenu = _isWebMenu;
    final primaryUrl = _computePrimaryUrl();
    final primaryIsMenu = primaryUrl != null && primaryUrl != _whatsappUrl;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dışa aktar & paylaş'),
        actions: [
          IconButton(
            tooltip: 'Premium',
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.paywall),
            icon: const Icon(Icons.workspace_premium_outlined),
          ),
        ],
      ),
      body: _QrPreviewBody(
        loading: _loading,
        catalog: _catalog,
        qrData: _qrData,
        shareText: _shareText,
        whatsappUrl: _whatsappUrl,
        publishError: _publishError,
        publishing: _publishing,
        sharing: _sharing,
        premiumEnabled: _premiumEnabled,
        appUrl: _appUrl,
        wantsWebMenu: wantsWebMenu,
        isWebMenu: isWebMenu,
        primaryIsMenu: primaryIsMenu,
        primaryUrl: primaryUrl,
        onOpenPrimary: () async {
          final url = primaryUrl;
          if (url == null) return;
          await AppAnalytics.log(
            primaryIsMenu ? 'qr_menu_open' : 'qr_whatsapp_open',
          );
          final ok = await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
          if (!context.mounted) return;
          if (!ok) {
            showAppSnackBar(
              context,
              primaryIsMenu ? 'Menü açılamadı.' : 'WhatsApp açılamadı.',
            );
          }
        },
        onOpenWhatsApp: () async {
          await AppAnalytics.log('qr_whatsapp_open');
          final url = _whatsappUrl;
          if (url == null) return;
          final ok = await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
          if (!context.mounted) return;
          if (!ok) {
            showAppSnackBar(context, 'WhatsApp açılamadı.');
          }
        },
        onCopyLink: () async {
          final data = _qrData;
          if (data == null) return;
          await Clipboard.setData(ClipboardData(text: data));
          await AppAnalytics.log('qr_link_copy');
          if (!context.mounted) return;
          showAppSnackBar(context, 'Link kopyalandı.');
        },
        onShareQrImage: _shareQrImage,
        onRefreshWebMenu: () async {
          await _ensurePublished();
          if (!context.mounted) return;
          showAppSnackBar(context, 'Web menü güncellendi.');
        },
        onCopyMessage: () async {
          final text = _shareText;
          if (text == null || text.isEmpty) return;
          await Clipboard.setData(ClipboardData(text: text));
          await AppAnalytics.log('export_message_copy');
          if (!context.mounted) return;
          showAppSnackBar(context, 'Mesaj kopyalandı.');
        },
        onOpenStory: () async {
          final catalog = _catalog;
          if (catalog == null) return;
          await Navigator.of(context).pushNamed(
            AppRoutes.storyExport,
            arguments: StoryExportArgs(catalogId: catalog.id),
          );
        },
        onOpenPdf: () async {
          final catalog = _catalog;
          if (catalog == null) return;
          await Navigator.of(context).pushNamed(
            AppRoutes.pdfExport,
            arguments: PdfExportArgs(catalogId: catalog.id),
          );
        },
        qrChild: RepaintBoundary(
          key: _qrRepaintKey,
          child: _QrCard(
            hasQr: hasQr,
            qrData: _qrData,
            wantsWebMenu: wantsWebMenu,
            isWebMenu: isWebMenu,
            publishError: _publishError,
            publishing: _publishing,
            premiumEnabled: _premiumEnabled,
            appUrl: _appUrl,
            primaryIsMenu: primaryIsMenu,
            repaintBoundaryChild: Column(
              children: [
                if (hasQr)
                  QrImageView(
                    data: _qrData!,
                    size: 240,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: _qrData!.startsWith('data:')
                        ? QrErrorCorrectLevel.L
                        : QrErrorCorrectLevel.M,
                  )
                else
                  Container(
                    width: 240,
                    height: 240,
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
