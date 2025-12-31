import 'package:flutter/material.dart';
import 'package:whatsapp_catalog/app/app_scope.dart';
import 'package:whatsapp_catalog/app/router/app_routes.dart';
import 'package:whatsapp_catalog/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:whatsapp_catalog/core/formatters/money_formatter.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/editor/catalog_editor_view_model.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/export/export_share_page.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/product/product_editor_page.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/template/template_picker_page.dart';

class CatalogEditorArgs {
  const CatalogEditorArgs({required this.catalogId});
  final String catalogId;
}

class CatalogEditorPage extends StatefulWidget {
  const CatalogEditorPage({super.key, required this.args});

  final CatalogEditorArgs args;

  static CatalogEditorPage fromSettings(RouteSettings settings) {
    final args = settings.arguments as CatalogEditorArgs?;
    if (args == null) {
      throw StateError('CatalogEditorArgs required');
    }
    return CatalogEditorPage(args: args);
  }

  @override
  State<CatalogEditorPage> createState() => _CatalogEditorPageState();
}

class _CatalogEditorPageState extends State<CatalogEditorPage> {
  CatalogRepository? _repo;
  CatalogEditorViewModel? _vm;
  var _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    _repo = AppScope.of(context).catalogRepository;
    _vm = CatalogEditorViewModel(
      repository: _repo!,
      catalogId: widget.args.catalogId,
    )..load();
  }

  @override
  void dispose() {
    _vm?.dispose();
    super.dispose();
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
            title: Text(catalog?.name ?? 'Katalog'),
            actions: [
              IconButton(
                onPressed: catalog == null
                    ? null
                    : () => Navigator.of(context).pushNamed(
                        AppRoutes.templatePicker,
                        arguments: TemplatePickerArgs(catalogId: catalog.id),
                      ),
                icon: const Icon(Icons.palette),
                tooltip: 'Şablon',
              ),
              PopupMenuButton<String>(
                tooltip: 'Menü',
                enabled: catalog != null,
                onSelected: (value) async {
                  final c = catalog;
                  if (c == null) return;
                  if (value == 'rename') {
                    final nextName = await _promptRename(context, c.name);
                    if (nextName == null) return;
                    await vm.rename(nextName);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'rename', child: Text('Adı değiştir')),
                ],
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _Chip(
                                  icon: Icons.palette,
                                  label: _templateLabel(
                                    catalog.selectedTemplateId,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _Chip(
                                  icon: Icons.payments_outlined,
                                  label: catalog.currencyCode,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: catalog.items.isEmpty
                                    ? null
                                    : () => Navigator.of(context).pushNamed(
                                        AppRoutes.exportShare,
                                        arguments: ExportShareArgs(
                                          catalogId: catalog.id,
                                        ),
                                      ),
                                icon: const Icon(Icons.ios_share),
                                label: const Text('Paylaş'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Ürünler',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '${catalog.items.length}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Ekle',
                          onPressed: () async {
                            await Navigator.of(context).pushNamed(
                              AppRoutes.productEditor,
                              arguments: ProductEditorArgs(
                                catalogId: catalog.id,
                              ),
                            );
                            await vm.load();
                          },
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (catalog.items.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                color: Theme.of(context).colorScheme.primary,
                                size: 40,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Henüz ürün/hizmet yok',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'İlk öğeyi ekle, ardından Paylaş ile QR/Story çıktısına geç.',
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () async {
                                    await Navigator.of(context).pushNamed(
                                      AppRoutes.productEditor,
                                      arguments: ProductEditorArgs(
                                        catalogId: catalog.id,
                                      ),
                                    );
                                    await vm.load();
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Ürün/hizmet ekle'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      for (final item in catalog.items) ...[
                        Card(
                          child: ListTile(
                            title: Text(item.title),
                            subtitle: item.description.trim().isEmpty
                                ? null
                                : Text(item.description),
                            trailing: Text(
                              formatMoney(
                                value: item.price,
                                currencyCode: catalog.currencyCode,
                              ),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            onTap: () async {
                              await Navigator.of(context).pushNamed(
                                AppRoutes.productEditor,
                                arguments: ProductEditorArgs(
                                  catalogId: catalog.id,
                                  itemId: item.id,
                                ),
                              );
                              await vm.load();
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ],
                ),
        );
      },
    );
  }
}

String _templateLabel(String id) {
  return switch (id) {
    'minimal_green' => 'Minimal',
    'soft_food' => 'Food',
    'beauty_clean' => 'Beauty',
    'boutique_bold' => 'Boutique',
    _ => 'Template',
  };
}

Future<String?> _promptRename(BuildContext context, String currentName) async {
  final controller = TextEditingController(text: currentName);
  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Katalog adı'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Ad'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Kaydet'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  final next = result?.trim();
  if (next == null || next.length < 2) return null;
  return next;
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
