import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:whatsapp_catalog/app/app_scope.dart';
import 'package:whatsapp_catalog/core/analytics/app_analytics.dart';
import 'package:whatsapp_catalog/core/settings/app_settings.dart';
import 'package:whatsapp_catalog/core/share/referral_share.dart';
import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/export/export_share_view_model.dart';

class PdfExportArgs {
  const PdfExportArgs({required this.catalogId});
  final String catalogId;
}

class PdfExportPage extends StatefulWidget {
  const PdfExportPage({super.key, required this.args});

  final PdfExportArgs args;

  static PdfExportPage fromSettings(RouteSettings settings) {
    final args = settings.arguments as PdfExportArgs?;
    if (args == null) {
      throw StateError('PdfExportArgs required');
    }
    return PdfExportPage(args: args);
  }

  @override
  State<PdfExportPage> createState() => _PdfExportPageState();
}

class _PdfExportPageState extends State<PdfExportPage> {
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
    AppAnalytics.log('pdf_open');
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

  Future<Uint8List> _buildPdfBytes({
    required Catalog catalog,
    required String whatsappUrl,
    required bool showWatermark,
    required String? watermarkUrl,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          final items = catalog.items;
          return [
            pw.Text(
              catalog.name,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'QR okut → WhatsApp’ta sipariş mesajı hazır gelsin',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
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
                                      style: const pw.TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  pw.SizedBox(width: 8),
                                  pw.Text(
                                    _formatMoney(i.price, catalog.currencyCode),
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
                        style: pw.TextStyle(
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
                        style: pw.TextStyle(
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
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ),
          ];
        },
      ),
    );
    return doc.save();
  }

  Future<void> _sharePdf() async {
    final vm = _vm;
    if (vm == null) return;
    final catalog = vm.catalog;
    if (catalog == null) return;

    setState(() => _sharing = true);
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
            title: const Text('A4 PDF'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton(
                  onPressed: (_sharing || vm.isBusy || catalog == null)
                      ? null
                      : _sharePdf,
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
                    Text(
                      'PDF dosyası oluşturulup paylaşılır. WhatsApp, e-posta veya yazdırma için kullanabilirsin.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(Icons.picture_as_pdf),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${catalog.name} (A4)',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                            const Icon(Icons.chevron_right),
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

String _formatMoney(double value, String currencyCode) {
  final isInt = value == value.roundToDouble();
  final text = isInt ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  return '$text $currencyCode';
}
