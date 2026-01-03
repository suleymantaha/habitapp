import 'package:flutter/material.dart';
import 'package:whatsapp_catalog/app/app_scope.dart';
import 'package:whatsapp_catalog/app/router/app_routes.dart';
import 'package:whatsapp_catalog/core/ui/app_dialogs.dart';
import 'package:whatsapp_catalog/core/ui/app_snackbar.dart';
import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog.dart';
import 'package:whatsapp_catalog/features/catalog/domain/usecases/create_catalog.dart';
import 'package:whatsapp_catalog/features/catalog/domain/usecases/delete_catalog.dart';
import 'package:whatsapp_catalog/features/catalog/domain/usecases/watch_catalogs.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/editor/catalog_editor_page.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/home/home_view_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeViewModel? _vm;
  var _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    final repo = AppScope.of(context).catalogRepository;
    _vm = HomeViewModel(
      watchCatalogs: WatchCatalogs(repo),
      createCatalog: CreateCatalog(repo),
      deleteCatalog: DeleteCatalog(repo),
    )..start();
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
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              _buildAppBar(context),
              if (vm.catalogs.isEmpty)
                _buildEmptyState(context, vm)
              else
                _buildCatalogList(context, vm),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: vm.isBusy ? null : () => _openCreateCatalog(context, vm),
            label: const Text('Yeni katalog'),
            icon: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar.large(
      title: const Text('Kataloglar'),
      actions: [
        IconButton(
          onPressed: () => _openHowItWorks(context),
          icon: const Icon(Icons.help_outline),
          tooltip: 'Nasıl çalışır?',
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.settings),
          icon: const Icon(Icons.settings),
          tooltip: 'Ayarlar',
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, HomeViewModel vm) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      sliver: SliverToBoxAdapter(
        child: _OnboardingEmptyState(
          isBusy: vm.isBusy,
          onCreate: vm.isBusy ? null : () => _openCreateCatalog(context, vm),
          onCreateDemo: vm.isBusy ? null : () => _handleCreateDemo(context, vm),
        ),
      ),
    );
  }

  Future<void> _handleCreateDemo(BuildContext context, HomeViewModel vm) async {
    final id = await vm.createDemoCatalog();
    if (!context.mounted) return;
    if (id == null) {
      showAppSnackBar(context, 'Örnek katalog oluşturulamadı.');
      return;
    }
    await Navigator.of(context).pushNamed(
      AppRoutes.catalogEditor,
      arguments: CatalogEditorArgs(catalogId: id),
    );
  }

  Widget _buildCatalogList(BuildContext context, HomeViewModel vm) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      sliver: SliverList.separated(
        itemCount: vm.catalogs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final catalog = vm.catalogs[index];
          return _CatalogCard(
            name: catalog.name,
            subtitle: '${catalog.items.length} ürün/hizmet',
            onOpen: () => _openCatalogEditor(context, catalog.id),
            onDelete: vm.isBusy
                ? null
                : () => _handleDeleteCatalog(context, vm, catalog),
          );
        },
      ),
    );
  }

  Future<void> _openCatalogEditor(
    BuildContext context,
    String catalogId,
  ) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.catalogEditor,
      arguments: CatalogEditorArgs(catalogId: catalogId),
    );
  }

  Future<void> _handleDeleteCatalog(
    BuildContext context,
    HomeViewModel vm,
    Catalog catalog,
  ) async {
    final confirmed = await confirmDeleteDialog(
      context,
      title: 'Kataloğu sil?',
      message: '"${catalog.name}" silinecek. Bu işlem geri alınamaz.',
    );
    if (!confirmed) return;
    final ok = await vm.deleteCatalog(catalog.id);
    if (!context.mounted) return;
    if (!ok) {
      showAppSnackBar(context, '"${catalog.name}" silinemedi.');
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('"${catalog.name}" silindi.'),
          action: SnackBarAction(
            label: 'Geri al',
            onPressed: () async {
              final restored = await vm.restoreCatalog(catalog);
              if (!context.mounted) return;
              if (!restored) {
                showAppSnackBar(context, '"${catalog.name}" geri alınamadı.');
              }
            },
          ),
        ),
      );
  }
}

Future<void> _openCreateCatalog(BuildContext context, HomeViewModel vm) async {
  final result = await showModalBottomSheet<_CreateCatalogResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => const _CreateCatalogSheet(),
  );
  if (result == null) return;
  final id = await vm.createCatalog(
    name: result.name,
    currencyCode: result.currencyCode,
    templateId: result.templateId,
  );
  if (!context.mounted) return;
  if (id == null) {
    showAppSnackBar(context, 'Katalog oluşturulamadı.');
    return;
  }
  await Navigator.of(context).pushNamed(
    AppRoutes.catalogEditor,
    arguments: CatalogEditorArgs(catalogId: id),
  );
}

class _OnboardingEmptyState extends StatelessWidget {
  const _OnboardingEmptyState({
    required this.isBusy,
    required this.onCreate,
    required this.onCreateDemo,
  });

  final bool isBusy;
  final VoidCallback? onCreate;
  final VoidCallback? onCreateDemo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '3 adımda WhatsApp’tan sipariş al',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Katalog oluştur, ürünlerini ekle, WhatsApp’ta paylaş.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const _StepCard(
              step: '1',
              title: 'Katalog oluştur',
              subtitle: 'Ad ve para birimini seç.',
              icon: Icons.create_outlined,
            ),
            const SizedBox(height: 10),
            const _StepCard(
              step: '2',
              title: 'Ürün/hizmet ekle',
              subtitle: 'Başlık, fiyat ve açıklama gir.',
              icon: Icons.inventory_2_outlined,
            ),
            const SizedBox(height: 10),
            const _StepCard(
              step: '3',
              title: 'Paylaş',
              subtitle: 'WhatsApp mesajı ve QR ile müşteriye gönder.',
              icon: Icons.ios_share,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: isBusy ? null : onCreateDemo,
              child: const Text('Örnek menüyle dene'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: isBusy ? null : onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Kendi kataloğunu oluştur'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String step;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                step,
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

Future<void> _openHowItWorks(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nasıl çalışır?',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            const _HowRow(
              icon: Icons.create_outlined,
              title: 'Katalog oluştur',
              body: 'Menü/katalog başlığını belirle.',
            ),
            const SizedBox(height: 10),
            const _HowRow(
              icon: Icons.inventory_2_outlined,
              title: 'Ürünleri ekle',
              body: 'Başlık + fiyat + açıklama gir.',
            ),
            const SizedBox(height: 10),
            const _HowRow(
              icon: Icons.ios_share,
              title: 'WhatsApp’ta paylaş',
              body: 'Hazır mesajı kopyala veya WhatsApp’ı aç.',
            ),
          ],
        ),
      );
    },
  );
}

class _HowRow extends StatelessWidget {
  const _HowRow({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    required this.name,
    required this.subtitle,
    required this.onOpen,
    required this.onDelete,
  });

  final String name;
  final String subtitle;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cleaned = name.trim();
    final initial = cleaned.isEmpty
        ? '?'
        : cleaned.substring(0, 1).toUpperCase();
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Menü',
                onSelected: (value) {
                  if (value == 'delete') onDelete?.call();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'delete',
                    enabled: onDelete != null,
                    child: const Text('Sil'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateCatalogResult {
  const _CreateCatalogResult({
    required this.name,
    required this.currencyCode,
    required this.templateId,
  });
  final String name;
  final String currencyCode;
  final String templateId;
}

class _CreateCatalogSheet extends StatefulWidget {
  const _CreateCatalogSheet();

  @override
  State<_CreateCatalogSheet> createState() => _CreateCatalogSheetState();
}

class _CreateCatalogSheetState extends State<_CreateCatalogSheet> {
  final _nameController = TextEditingController();
  var _currencyCode = 'TRY';
  var _templateId = 'minimal_green';
  var _canCreate = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _nameController.text = 'Katalog ${now.day}.${now.month}';
    _nameController.addListener(_recompute);
    _recompute();
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_recompute)
      ..dispose();
    super.dispose();
  }

  void _recompute() {
    final next = _nameController.text.trim().length >= 2;
    if (next == _canCreate) return;
    setState(() {
      _canCreate = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yeni katalog',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Adını yaz, şablonu seç, oluştur.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Katalog adı',
                hintText: 'Örn: Günün menüsü',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            Text(
              'Şablon',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final w = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _TemplateTile(
                      width: w,
                      title: 'Minimal',
                      subtitle: 'Temiz ve hızlı',
                      icon: Icons.check_circle_outline,
                      selected: _templateId == 'minimal_green',
                      onTap: () =>
                          setState(() => _templateId = 'minimal_green'),
                    ),
                    _TemplateTile(
                      width: w,
                      title: 'Food',
                      subtitle: 'Yemek menüsü',
                      icon: Icons.restaurant_menu,
                      selected: _templateId == 'soft_food',
                      onTap: () => setState(() => _templateId = 'soft_food'),
                    ),
                    _TemplateTile(
                      width: w,
                      title: 'Beauty',
                      subtitle: 'Salon hizmetleri',
                      icon: Icons.spa_outlined,
                      selected: _templateId == 'beauty_clean',
                      onTap: () => setState(() => _templateId = 'beauty_clean'),
                    ),
                    _TemplateTile(
                      width: w,
                      title: 'Boutique',
                      subtitle: 'Ürün kataloğu',
                      icon: Icons.local_mall_outlined,
                      selected: _templateId == 'boutique_bold',
                      onTap: () =>
                          setState(() => _templateId = 'boutique_bold'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Text(
              'Para birimi',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('TRY'),
                  selected: _currencyCode == 'TRY',
                  onSelected: (_) => setState(() => _currencyCode = 'TRY'),
                ),
                ChoiceChip(
                  label: const Text('USD'),
                  selected: _currencyCode == 'USD',
                  onSelected: (_) => setState(() => _currencyCode = 'USD'),
                ),
                ChoiceChip(
                  label: const Text('EUR'),
                  selected: _currencyCode == 'EUR',
                  onSelected: (_) => setState(() => _currencyCode = 'EUR'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: !_canCreate
                    ? null
                    : () {
                        final name = _nameController.text.trim();
                        if (name.length < 2) return;
                        Navigator.of(context).pop(
                          _CreateCatalogResult(
                            name: name,
                            currencyCode: _currencyCode,
                            templateId: _templateId,
                          ),
                        );
                      },
                child: const Text('Oluştur'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.width,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = selected
        ? BorderSide(color: scheme.primary, width: 2)
        : BorderSide(color: scheme.outlineVariant);
    final bg = selected
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;

    return SizedBox(
      width: width,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: border,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? scheme.onPrimaryContainer : scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: selected ? scheme.onPrimaryContainer : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: selected
                              ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (selected)
                  Icon(Icons.check, color: scheme.onPrimaryContainer)
                else
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
