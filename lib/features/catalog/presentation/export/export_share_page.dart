import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whatsapp_catalog/app/app_scope.dart';
import 'package:whatsapp_catalog/app/router/app_routes.dart';
import 'package:whatsapp_catalog/core/analytics/app_analytics.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/export/export_share_view_model.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/export/pdf_export_page.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/export/story_export_page.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/qr/qr_preview_page.dart';

class ExportShareArgs {
  const ExportShareArgs({required this.catalogId});
  final String catalogId;
}

class ExportSharePage extends StatefulWidget {
  const ExportSharePage({required this.args, super.key});

  factory ExportSharePage.fromSettings(RouteSettings settings) {
    final args = settings.arguments as ExportShareArgs?;
    if (args == null) {
      throw StateError('ExportShareArgs required');
    }
    return ExportSharePage(args: args);
  }

  final ExportShareArgs args;

  @override
  State<ExportSharePage> createState() => _ExportSharePageState();
}

class _ExportSharePageState extends State<ExportSharePage> {
  late final ExportShareViewModel _vm;
  var _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    final repo = AppScope.of(context).catalogRepository;
    _vm = ExportShareViewModel(
      repository: repo,
      catalogId: widget.args.catalogId,
    );
    unawaited(_vm.load());
    unawaited(AppAnalytics.log('export_open'));
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    return AnimatedBuilder(
      animation: vm,
      builder: (context, _) {
        final catalog = vm.catalog;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Dışa aktar & paylaş'),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.paywall),
                child: const Text('Premium'),
              ),
            ],
          ),
          body: catalog == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Text(
                      catalog.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WhatsApp mesajı',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                vm.shareText,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: vm.isBusy
                                        ? null
                                        : () async {
                                            final uri = Uri.parse(
                                              vm.whatsappUrl,
                                            );
                                            await AppAnalytics.log(
                                              'export_whatsapp_open',
                                            );
                                            final ok = await launchUrl(
                                              uri,
                                              mode: LaunchMode
                                                  .externalApplication,
                                            );
                                            if (!context.mounted) return;
                                            if (!ok) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'WhatsApp açılamadı.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    icon: const Icon(Icons.chat_bubble_outline),
                                    label: const Text('WhatsApp’ı aç'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  tooltip: 'Kopyala',
                                  onPressed: vm.isBusy
                                      ? null
                                      : () async {
                                          await Clipboard.setData(
                                            ClipboardData(text: vm.shareText),
                                          );
                                          await AppAnalytics.log(
                                            'export_message_copy',
                                          );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Mesaj kopyalandı.',
                                              ),
                                            ),
                                          );
                                        },
                                  icon: const Icon(Icons.copy_all_outlined),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: vm.isBusy
                                        ? null
                                        : () async {
                                            await AppAnalytics.log(
                                              'export_html_open',
                                            );
                                            if (!context.mounted) return;
                                            await Navigator.of(
                                              context,
                                            ).pushNamed(
                                              AppRoutes.qrPreview,
                                              arguments: QrPreviewArgs(
                                                catalogId: catalog.id,
                                                autoOpenHtml: true,
                                              ),
                                            );
                                          },
                                    icon: const Icon(Icons.public),
                                    label: const Text('Menüyü aç (HTML)'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const SizedBox(width: 48),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.qr_code_2),
                        title: const Text('QR'),
                        subtitle: const Text(
                          'Müşteri okutunca WhatsApp mesajı açılsın',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: vm.isBusy
                            ? null
                            : () => Navigator.of(context).pushNamed(
                                AppRoutes.qrPreview,
                                arguments: QrPreviewArgs(catalogId: catalog.id),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.photo),
                        title: const Text('Instagram Story'),
                        subtitle: const Text('Story görseli oluştur ve paylaş'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: vm.isBusy
                            ? null
                            : () => Navigator.of(context).pushNamed(
                                AppRoutes.storyExport,
                                arguments: StoryExportArgs(
                                  catalogId: catalog.id,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.picture_as_pdf),
                        title: const Text('A4 PDF'),
                        subtitle: const Text('PDF menü oluştur ve paylaş'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: vm.isBusy
                            ? null
                            : () => Navigator.of(context).pushNamed(
                                AppRoutes.pdfExport,
                                arguments: PdfExportArgs(catalogId: catalog.id),
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
