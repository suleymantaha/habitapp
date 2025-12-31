import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:whatsapp_catalog/app/app_scope.dart';
import 'package:whatsapp_catalog/core/analytics/app_analytics.dart';
import 'package:whatsapp_catalog/core/settings/app_settings.dart';
import 'package:whatsapp_catalog/core/share/referral_share.dart';
import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog_item.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/export/export_share_view_model.dart';

class StoryExportArgs {
  const StoryExportArgs({required this.catalogId});
  final String catalogId;
}

class StoryExportPage extends StatefulWidget {
  const StoryExportPage({super.key, required this.args});

  final StoryExportArgs args;

  static StoryExportPage fromSettings(RouteSettings settings) {
    final args = settings.arguments as StoryExportArgs?;
    if (args == null) {
      throw StateError('StoryExportArgs required');
    }
    return StoryExportPage(args: args);
  }

  @override
  State<StoryExportPage> createState() => _StoryExportPageState();
}

class _StoryExportPageState extends State<StoryExportPage> {
  final _repaintKey = GlobalKey();

  ExportShareViewModel? _vm;
  var _didInit = false;
  var _sharing = false;
  var _premiumEnabled = false;
  String? _appUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    final repo = AppScope.of(context).catalogRepository;
    _vm = ExportShareViewModel(
      repository: repo,
      catalogId: widget.args.catalogId,
    )..load();
    AppAnalytics.log('story_open');
    AppSettings.getPremiumEnabled().then((value) {
      if (!mounted) return;
      setState(() => _premiumEnabled = value);
    });
    AppSettings.getShareAppUrl().then((value) {
      if (!mounted) return;
      setState(() => _appUrl = value);
    });
  }

  @override
  void dispose() {
    _vm?.dispose();
    super.dispose();
  }

  Future<Uint8List?> _capturePngBytes() async {
    await WidgetsBinding.instance.endOfFrame;
    final renderObject = _repaintKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;
    final image = await renderObject.toImage(
      pixelRatio: _premiumEnabled ? 4 : 3,
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _shareStory() async {
    final vm = _vm;
    if (vm == null) return;
    final catalog = vm.catalog;
    if (catalog == null) return;

    setState(() => _sharing = true);
    try {
      final bytes = await _capturePngBytes();
      if (bytes == null) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/story_${catalog.id}.png');
      await file.writeAsBytes(bytes, flush: true);

      final referral = await buildReferralShareText();
      await AppAnalytics.log('story_share');
      await SharePlus.instance.share(
        ShareParams(text: referral, files: [XFile(file.path)]),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    if (vm == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: vm,
      builder: (context, _) {
        final catalog = vm.catalog;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Instagram Story'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton(
                  onPressed: (_sharing || vm.isBusy || catalog == null)
                      ? null
                      : _shareStory,
                  child: const Text('Paylaş'),
                ),
              ),
            ],
          ),
          body: catalog == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: ClipRect(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: RepaintBoundary(
                              key: _repaintKey,
                              child: SizedBox(
                                width: 1080,
                                height: 1920,
                                child: _StoryCanvas(
                                  title: catalog.name,
                                  currencyCode: catalog.currencyCode,
                                  items: catalog.items,
                                  whatsappUrl: vm.whatsappUrl,
                                  showWatermark: !_premiumEnabled,
                                  watermarkUrl: _appUrl,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Paylaşmadan önce Story’yi ekran görüntüsü almana gerek yok. “Paylaş” ile direkt gönder.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _StoryCanvas extends StatelessWidget {
  const _StoryCanvas({
    required this.title,
    required this.currencyCode,
    required this.items,
    required this.whatsappUrl,
    required this.showWatermark,
    required this.watermarkUrl,
  });

  final String title;
  final String currencyCode;
  final List<CatalogItem> items;
  final String whatsappUrl;
  final bool showWatermark;
  final String? watermarkUrl;

  @override
  Widget build(BuildContext context) {
    final topItems = items.take(6).toList(growable: false);
    return ColoredBox(
      color: const Color(0xFF0B1220),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(64, 64, 64, 56),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: const Color(0xFF111B2E),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: const Color(0xFF223256), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Menü',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (final item in topItems) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatMoney(item.price, currencyCode),
                            style: const TextStyle(
                              color: Color(0xFFAEC6FF),
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'QR okut → WhatsApp’ta sipariş mesajı hazır gelsin',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: QrImageView(
                      data: whatsappUrl,
                      size: 210,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ),
                ],
              ),
              if (showWatermark) ...[
                const SizedBox(height: 18),
                Text(
                  watermarkUrl == null
                      ? 'whatsapp_catalog ile oluşturuldu'
                      : 'Kendi kataloğunu oluştur: $watermarkUrl',
                  style: const TextStyle(
                    color: Color(0xFF98A7C7),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _formatMoney(double value, String currencyCode) {
  final isInt = value == value.roundToDouble();
  final text = isInt ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  return '$text $currencyCode';
}
