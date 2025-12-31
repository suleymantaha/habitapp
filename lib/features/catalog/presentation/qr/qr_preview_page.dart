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
import 'package:whatsapp_catalog/core/public_menu/public_menu_client.dart';
import 'package:whatsapp_catalog/core/public_menu/public_menu_link_store.dart';
import 'package:whatsapp_catalog/core/settings/app_settings.dart';
import 'package:whatsapp_catalog/core/share/referral_share.dart';
import 'package:whatsapp_catalog/core/share/whatsapp_share.dart';
import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog.dart';
import 'package:whatsapp_catalog/features/catalog/domain/repositories/catalog_repository.dart';

class QrPreviewArgs {
  const QrPreviewArgs({required this.catalogId});
  final String catalogId;
}

class QrPreviewPage extends StatefulWidget {
  const QrPreviewPage({super.key, required this.args});

  final QrPreviewArgs args;

  static QrPreviewPage fromSettings(RouteSettings settings) {
    final args = settings.arguments as QrPreviewArgs?;
    if (args == null) {
      throw StateError('QrPreviewArgs required');
    }
    return QrPreviewPage(args: args);
  }

  @override
  State<QrPreviewPage> createState() => _QrPreviewPageState();
}

class _QrPreviewPageState extends State<QrPreviewPage> {
  final _qrRepaintKey = GlobalKey();

  CatalogRepository? _repo;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    _repo = AppScope.of(context).catalogRepository;
    AppAnalytics.log('qr_open');
    AppSettings.getPremiumEnabled().then((value) {
      if (!mounted) return;
      setState(() => _premiumEnabled = value);
    });
    AppSettings.getShareAppUrl().then((value) {
      if (!mounted) return;
      setState(() => _appUrl = value);
    });
    AppSettings.getPublicMenuBaseUrl().then((value) {
      if (!mounted) return;
      setState(() => _publicMenuBaseUrl = value);
      _load();
    });
  }

  Future<Uint8List?> _captureQrPngBytes() async {
    await WidgetsBinding.instance.endOfFrame;
    final renderObject = _qrRepaintKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;
    final image = await renderObject.toImage(
      pixelRatio: _premiumEnabled ? 4 : 3,
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _shareQrImage() async {
    if (_sharing) return;
    final data = _qrData;
    if (data == null) return;

    setState(() => _sharing = true);
    try {
      final bytes = await _captureQrPngBytes();
      if (bytes == null) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/qr_${widget.args.catalogId}.png');
      await file.writeAsBytes(bytes, flush: true);

      final referral = await buildReferralShareText();
      await AppAnalytics.log('qr_share_image');
      await SharePlus.instance.share(
        ShareParams(text: referral, files: [XFile(file.path)]),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final catalog = await _repo!.getCatalog(widget.args.catalogId);
    if (!mounted) return;
    if (catalog == null) {
      setState(() {
        _loading = false;
        _catalog = null;
        _qrData = null;
        _shareText = null;
        _whatsappUrl = null;
      });
      return;
    }
    final text = buildCatalogShareText(
      catalogName: catalog.name,
      currencyCode: catalog.currencyCode,
      items: [
        for (final i in catalog.items)
          CatalogShareItem(title: i.title, price: i.price),
      ],
    );
    final url = buildWhatsAppSendUrl(text: text);
    final baseUrl = _publicMenuBaseUrl;
    final wantsWebMenu = baseUrl != null && baseUrl.isNotEmpty;
    setState(() {
      _loading = false;
      _catalog = catalog;
      _shareText = text;
      _whatsappUrl = url;
      _qrData = wantsWebMenu ? null : url;
    });
    _ensurePublished();
  }

  Future<void> _ensurePublished() async {
    final baseUrl = _publicMenuBaseUrl;
    final catalog = _catalog;
    if (baseUrl == null || baseUrl.isEmpty) return;
    if (_publishing) return;
    if (catalog == null) return;

    setState(() {
      _publishing = true;
      _publishError = null;
    });
    try {
      final client = PublicMenuClient(baseUrl: baseUrl);
      final existing = await PublicMenuLinkStore.get(catalog.id);
      if (existing == null) {
        final created = await client.createMenu(catalog);
        final link = PublicMenuLink(
          id: created.id,
          editToken: created.editToken,
        );
        await PublicMenuLinkStore.set(catalog.id, link);
        final url = client.publicUrlForId(created.id);
        if (!mounted) return;
        setState(() => _qrData = url);
      } else {
        await client.updateMenu(
          id: existing.id,
          editToken: existing.editToken,
          catalog: catalog,
        );
        final url = client.publicUrlForId(existing.id);
        if (!mounted) return;
        setState(() => _qrData = url);
      }
    } catch (_) {
      if (!mounted) return;
      final fallback = _whatsappUrl;
      setState(() {
        _publishError = 'Web menü yayınlanamadı. Ayarlar → “Web menü servisi” alanını kontrol et.';
        if (fallback != null) _qrData = fallback;
      });
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wantsWebMenu = (_publicMenuBaseUrl ?? '').isNotEmpty;
    final hasQr = _qrData != null;
    final isWebMenu =
        _whatsappUrl != null && _qrData != null && _qrData != _whatsappUrl;
    final primaryIsMenu = wantsWebMenu && _publishError == null;
    final primaryUrl = primaryIsMenu ? _qrData : _whatsappUrl;
    return Scaffold(
      appBar: AppBar(title: const Text('QR')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _catalog == null
          ? const Center(child: Text('Katalog bulunamadı.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: RepaintBoundary(
                      key: _qrRepaintKey,
                      child: Column(
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
                          const SizedBox(height: 12),
                          Text(
                            !hasQr && wantsWebMenu && _publishError == null
                                ? 'Web menü hazırlanıyor…'
                                : isWebMenu
                                    ? 'Müşteri okutunca menü tarayıcıda açılır.'
                                    : 'Müşteri okutunca WhatsApp mesajı açılır.',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        if (_publishError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _publishError!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Theme.of(context).colorScheme.error),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (_publishing) ...[
                          const SizedBox(height: 8),
                          const LinearProgressIndicator(),
                        ],
                          if (!_premiumEnabled) ...[
                            const SizedBox(height: 12),
                            Text(
                              _appUrl == null
                                  ? 'whatsapp_catalog ile oluşturuldu'
                                  : 'Kendi kataloğunu oluştur: $_appUrl',
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: primaryUrl == null
                            ? null
                            : () async {
                                await AppAnalytics.log(
                                  primaryIsMenu ? 'qr_menu_open' : 'qr_whatsapp_open',
                                );
                                final ok = await launchUrl(
                                  Uri.parse(primaryUrl),
                                  mode: LaunchMode.externalApplication,
                                );
                                if (!context.mounted) return;
                                if (!ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        primaryIsMenu ? 'Menü açılamadı.' : 'WhatsApp açılamadı.',
                                      ),
                                    ),
                                  );
                                }
                              },
                        icon: Icon(primaryIsMenu ? Icons.public : Icons.chat_bubble_outline),
                        label: Text(primaryIsMenu ? 'Menüyü aç' : 'WhatsApp’ı aç'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (isWebMenu)
                      IconButton(
                        tooltip: 'WhatsApp’ı aç',
                        onPressed: () async {
                          await AppAnalytics.log('qr_whatsapp_open');
                          final url = _whatsappUrl;
                          if (url == null) return;
                          final ok = await launchUrl(
                            Uri.parse(url),
                            mode: LaunchMode.externalApplication,
                          );
                          if (!context.mounted) return;
                          if (!ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('WhatsApp açılamadı.')),
                            );
                          }
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                      ),
                    IconButton(
                      tooltip: 'Linki kopyala',
                      onPressed: _qrData == null
                          ? null
                          : () async {
                              await Clipboard.setData(ClipboardData(text: _qrData!));
                              await AppAnalytics.log('qr_link_copy');
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Link kopyalandı.')),
                              );
                            },
                      icon: const Icon(Icons.link),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _sharing || _qrData == null ? null : _shareQrImage,
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('QR görselini paylaş'),
                ),
                const SizedBox(height: 12),
                if (wantsWebMenu)
                  OutlinedButton.icon(
                    onPressed: _publishing
                        ? null
                        : () async {
                            await _ensurePublished();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Web menü güncellendi.')),
                            );
                          },
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('Web menüyü güncelle'),
                  ),
                if (isWebMenu) const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final text = await buildReferralShareText();
                    await AppAnalytics.log('qr_referral_share');
                    await SharePlus.instance.share(ShareParams(text: text));
                  },
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Arkadaşına gönder'),
                ),
                const SizedBox(height: 12),
                if ((_shareText ?? '').isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mesaj önizleme',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _shareText!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
