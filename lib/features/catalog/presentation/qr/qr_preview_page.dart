import 'dart:async';
import 'dart:convert';
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
import 'package:whatsapp_catalog/core/analytics/app_analytics.dart';
import 'package:whatsapp_catalog/core/formatters/money_formatter.dart';
import 'package:whatsapp_catalog/core/public_menu/public_menu_client.dart';
import 'package:whatsapp_catalog/core/public_menu/public_menu_link_store.dart';
import 'package:whatsapp_catalog/core/settings/app_settings.dart';
import 'package:whatsapp_catalog/core/share/referral_share.dart';
import 'package:whatsapp_catalog/core/share/whatsapp_share.dart';
import 'package:whatsapp_catalog/core/ui/app_snackbar.dart';
import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog.dart';
import 'package:whatsapp_catalog/features/catalog/domain/repositories/catalog_repository.dart';

part 'qr_preview_actions.dart';
part 'qr_preview_widgets.dart';

class QrPreviewArgs {
  const QrPreviewArgs({required this.catalogId, this.autoOpenHtml = false});
  final String catalogId;
  final bool autoOpenHtml;
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
  var _didAutoOpen = false;

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
    final primaryIsMenu = wantsWebMenu && _publishError == null;
    final primaryUrl = primaryIsMenu ? _qrData : _whatsappUrl;
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Menü',
            onSelected: (value) async {
              if (value == 'html') {
                await _openHtmlView();
              } else if (value == 'referral') {
                final text = await buildReferralShareText();
                await AppAnalytics.log('qr_referral_share');
                await SharePlus.instance.share(ShareParams(text: text));
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'html', child: Text('HTML görünümde aç')),
              PopupMenuItem(
                value: 'referral',
                child: Text('Uygulamayı paylaş'),
              ),
            ],
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
        onOpenHtml: _openHtmlView,
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
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
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
