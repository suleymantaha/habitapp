import 'dart:async';

import 'package:flutter/material.dart';
import 'package:whatsapp_catalog/app/app_scope.dart';
import 'package:whatsapp_catalog/app/router/app_routes.dart';
import 'package:whatsapp_catalog/core/formatters/money_formatter.dart';
import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog.dart';
import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog_item.dart';
import 'package:whatsapp_catalog/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/editor/catalog_editor_view_model.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/product/product_editor_page.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/qr/qr_preview_page.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/template/template_picker_page.dart';

class CatalogEditorArgs {
  const CatalogEditorArgs({required this.catalogId});
  final String catalogId;
}

class CatalogEditorPage extends StatefulWidget {
  const CatalogEditorPage({required this.args, super.key});

  factory CatalogEditorPage.fromSettings(RouteSettings settings) {
    final args = settings.arguments as CatalogEditorArgs?;
    if (args == null) {
      throw StateError('CatalogEditorArgs required');
    }
    return CatalogEditorPage(args: args);
  }

  final CatalogEditorArgs args;

  @override
  State<CatalogEditorPage> createState() => _CatalogEditorPageState();
}

class _CatalogEditorPageState extends State<CatalogEditorPage> {
  late final CatalogRepository _repo;
  late final CatalogEditorViewModel _vm;
  var _didInit = false;
  _ItemSort _sort = _ItemSort.titleAsc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    _repo = AppScope.of(context).catalogRepository;
    _vm = CatalogEditorViewModel(
      repository: _repo,
      catalogId: widget.args.catalogId,
    );
    unawaited(_vm.load());
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
                                        AppRoutes.qrPreview,
                                        arguments: QrPreviewArgs(
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
                        PopupMenuButton<_ItemSort>(
                          tooltip: 'Sırala',
                          initialValue: _sort,
                          onSelected: (v) => setState(() => _sort = v),
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: _ItemSort.titleAsc,
                              child: Text('A-Z'),
                            ),
                            PopupMenuItem(
                              value: _ItemSort.titleDesc,
                              child: Text('Z-A'),
                            ),
                            PopupMenuItem(
                              value: _ItemSort.priceAsc,
                              child: Text('Fiyat (artan)'),
                            ),
                            PopupMenuItem(
                              value: _ItemSort.priceDesc,
                              child: Text('Fiyat (azalan)'),
                            ),
                          ],
                          child: Chip(
                            label: Text(_sortLabel(_sort)),
                            avatar: const Icon(Icons.sort, size: 18),
                          ),
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
                      ..._buildGroupedItems(
                        context,
                        catalog: catalog,
                        sort: _sort,
                        onEdit: (itemId) async {
                          await Navigator.of(context).pushNamed(
                            AppRoutes.productEditor,
                            arguments: ProductEditorArgs(
                              catalogId: catalog.id,
                              itemId: itemId,
                            ),
                          );
                          await vm.load();
                        },
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

enum _ItemSort { titleAsc, titleDesc, priceAsc, priceDesc }

String _sortLabel(_ItemSort sort) {
  return switch (sort) {
    _ItemSort.titleAsc => 'A-Z',
    _ItemSort.titleDesc => 'Z-A',
    _ItemSort.priceAsc => '₺↑',
    _ItemSort.priceDesc => '₺↓',
  };
}

List<Widget> _buildGroupedItems(
  BuildContext context, {
  required Catalog catalog,
  required _ItemSort sort,
  required Future<void> Function(String itemId) onEdit,
}) {
  final currencyCode = catalog.currencyCode;
  final items = catalog.items;

  const uncategorizedKey = '__uncategorized__';
  const uncategorizedTitle = 'Kategorisiz';

  String keyFor(CatalogItem item) {
    final raw = item.section?.trim();
    return (raw == null || raw.isEmpty) ? uncategorizedKey : raw;
  }

  final grouped = <String, List<CatalogItem>>{};
  for (final i in items) {
    final k = keyFor(i);
    (grouped[k] ??= <CatalogItem>[]).add(i);
  }

  int compareItems(CatalogItem a, CatalogItem b) {
    final at = a.title.toLowerCase();
    final bt = b.title.toLowerCase();
    final ap = a.price;
    final bp = b.price;

    return switch (sort) {
      _ItemSort.titleAsc => at.compareTo(bt),
      _ItemSort.titleDesc => bt.compareTo(at),
      _ItemSort.priceAsc => (ap != bp) ? ap.compareTo(bp) : at.compareTo(bt),
      _ItemSort.priceDesc => (ap != bp) ? bp.compareTo(ap) : at.compareTo(bt),
    };
  }

  // Section ordering: A-Z, uncategorized at end.
  final sectionKeys = grouped.keys.toList()
    ..sort((a, b) {
      if (a == uncategorizedKey && b == uncategorizedKey) return 0;
      if (a == uncategorizedKey) return 1;
      if (b == uncategorizedKey) return -1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });

  final widgets = <Widget>[];

  for (final sectionKey in sectionKeys) {
    final sectionItems = (grouped[sectionKey] ?? <CatalogItem>[])
      ..sort(compareItems);
    final title = sectionKey == uncategorizedKey
        ? uncategorizedTitle
        : sectionKey;

    widgets
      ..add(
        Card(
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: sectionKeys.length <= 2,
              title: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: Text('${sectionItems.length} ürün'),
              children: [
                for (final item in sectionItems)
                  ListTile(
                    title: Text(item.title),
                    subtitle: _itemSubtitle(context, item),
                    trailing: Text(
                      formatMoney(
                        value: item.price,
                        currencyCode: currencyCode,
                      ),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    onTap: () => onEdit(item.id),
                  ),
              ],
            ),
          ),
        ),
      )
      ..add(const SizedBox(height: 10));
  }

  return widgets;
}

Widget? _itemSubtitle(BuildContext context, CatalogItem item) {
  final desc = item.description.trim();
  final subsection = item.subsection?.trim() ?? '';
  if (desc.isEmpty && subsection.isEmpty) return null;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (subsection.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              subsection,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      if (desc.isNotEmpty) Text(desc),
    ],
  );
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
