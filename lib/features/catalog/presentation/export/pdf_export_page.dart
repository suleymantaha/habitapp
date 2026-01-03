import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:whatsapp_catalog/app/app_scope.dart';
import 'package:whatsapp_catalog/core/analytics/app_analytics.dart';
import 'package:whatsapp_catalog/core/formatters/money_formatter.dart';
import 'package:whatsapp_catalog/core/settings/app_settings.dart';
import 'package:whatsapp_catalog/core/share/referral_share.dart';
import 'package:whatsapp_catalog/core/share/whatsapp_share.dart';
import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog.dart';
import 'package:whatsapp_catalog/features/catalog/domain/repositories/catalog_repository.dart';

class PdfExportArgs {
  const PdfExportArgs({required this.catalogId});
  final String catalogId;
}

class PdfExportPage extends StatefulWidget {
  const PdfExportPage({required this.args, super.key});

  factory PdfExportPage.fromSettings(RouteSettings settings) {
    final args = settings.arguments as PdfExportArgs?;
    if (args == null) {
      throw StateError('PdfExportArgs required');
    }
    return PdfExportPage(args: args);
  }

  final PdfExportArgs args;

  @override
  State<PdfExportPage> createState() => _PdfExportPageState();
}

class _PdfExportPageState extends State<PdfExportPage> {
  _CatalogExportVm? _vm;
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
    _vm = _CatalogExportVm(repository: repo, catalogId: widget.args.catalogId);
    unawaited(_vm!.load());
    unawaited(AppAnalytics.log('pdf_open'));
    unawaited(
      AppSettings.getPremiumEnabled().then((value) {
        if (!mounted) return;
        setState(() {
          _premiumEnabled = value;
        });
      }),
    );
    unawaited(
      AppSettings.getShareAppUrl().then((value) {
        if (!mounted) return;
        setState(() {
          _appUrl = value;
        });
      }),
    );
  }

  @override
  void dispose() {
    _vm?.dispose();
    super.dispose();
  }

  Future<Uint8List> _buildPdfBytes({
    required Catalog catalog,
    required String whatsappUrl,
    required bool showWatermark,
    required String? watermarkUrl,
  }) async {
    return (pw.Document()..addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (context) {
              final items = catalog.items;
              return [
                pw.Text(
                  catalog.name,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'QR okut → WhatsApp’ta sipariş mesajı hazır gelsin',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(12),
                            decoration: pw.BoxDecoration(
                              borderRadius: pw.BorderRadius.circular(12),
                              border: pw.Border.all(color: PdfColors.grey300),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                              children: [
                                pw.Text(
                                  'Menü',
                                  style: pw.TextStyle(
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.SizedBox(height: 10),
                                for (final i in items) ...[
                                  pw.Row(
                                    children: [
                                      pw.Expanded(
                                        child: pw.Text(
                                          i.title,
                                          style: const pw.TextStyle(
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      pw.SizedBox(width: 8),
                                      pw.Text(
                                        formatMoney(
                                          value: i.price,
                                          currencyCode: catalog.currencyCode,
                                        ),
                                        style: pw.TextStyle(
                                          fontSize: 12,
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  pw.SizedBox(height: 6),
                                ],
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Text(
                            'Sipariş için bu mesajı WhatsApp’ta yanıtlayabilirsin.',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        borderRadius: pw.BorderRadius.circular(12),
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        children: [
                          pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: whatsappUrl,
                            width: 150,
                            height: 150,
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            'WhatsApp',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 18),
                if (showWatermark)
                  pw.Center(
                    child: pw.Text(
                      watermarkUrl == null
                          ? 'whatsapp_catalog ile oluşturuldu'
                          : 'Kendi kataloğunu oluştur: $watermarkUrl',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ),
              ];
            },
          ),
        ))
        .save();
  }

  Future<void> _sharePdf() async {
    final vm = _vm;
    if (vm == null) return;
    final catalog = vm.catalog;
    if (catalog == null) return;

    setState(() {
      _sharing = true;
    });
    try {
      final bytes = await _buildPdfBytes(
        catalog: catalog,
        whatsappUrl: vm.whatsappUrl,
        showWatermark: !_premiumEnabled,
        watermarkUrl: _appUrl,
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/menu_${catalog.id}.pdf');
      await file.writeAsBytes(bytes, flush: true);

      final referral = await buildReferralShareText();
      await AppAnalytics.log('pdf_share');
      await SharePlus.instance.share(
        ShareParams(text: referral, files: [XFile(file.path)]),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sharing = false;
        });
      }
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
            title: const Text('A4 PDF'),
            actions: [
              IconButton(
                tooltip: 'Paylaş',
                onPressed: (_sharing || vm.isBusy || catalog == null)
                    ? null
                    : _sharePdf,
                icon: const Icon(Icons.ios_share),
              ),
            ],
          ),
          body: catalog == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.picture_as_pdf,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${catalog.name} (A4)',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'WhatsApp, e-posta veya yazdırma için paylaş.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: (_sharing || vm.isBusy)
                                  ? null
                                  : _sharePdf,
                              icon: _sharing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Icon(Icons.ios_share),
                              label: Text(
                                _sharing ? 'Hazırlanıyor…' : 'Paylaş',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _CatalogExportVm extends ChangeNotifier {
  _CatalogExportVm({required this.repository, required this.catalogId});

  final CatalogRepository repository;
  final String catalogId;

  Catalog? catalog;
  String shareText = '';
  String whatsappUrl = '';
  bool isBusy = false;

  Future<void> load() async {
    isBusy = true;
    notifyListeners();
    try {
      catalog = await repository.getCatalog(catalogId);
      final c = catalog;
      if (c != null) {
        shareText = buildCatalogShareText(
          catalogName: c.name,
          currencyCode: c.currencyCode,
          items: [
            for (final i in c.items)
              CatalogShareItem(title: i.title, price: i.price),
          ],
        );
        whatsappUrl = buildWhatsAppSendUrl(text: shareText);
      }
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
