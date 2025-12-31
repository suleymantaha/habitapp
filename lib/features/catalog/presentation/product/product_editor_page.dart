import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whatsapp_catalog/core/files/image_storage.dart';
import 'package:whatsapp_catalog/app/app_scope.dart';
import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog_item.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/product/product_editor_view_model.dart';

class ProductEditorArgs {
  const ProductEditorArgs({required this.catalogId, this.itemId});
  final String catalogId;
  final String? itemId;
}

class ProductEditorPage extends StatefulWidget {
  const ProductEditorPage({super.key, required this.args});

  final ProductEditorArgs args;

  static ProductEditorPage fromSettings(RouteSettings settings) {
    final args = settings.arguments as ProductEditorArgs?;
    if (args == null) {
      throw StateError('ProductEditorArgs required');
    }
    return ProductEditorPage(args: args);
  }

  @override
  State<ProductEditorPage> createState() => _ProductEditorPageState();
}

class _ProductEditorPageState extends State<ProductEditorPage> {
  ProductEditorViewModel? _vm;
  var _didInit = false;
  var _didInitForm = false;

  final _sectionController = TextEditingController();
  final _subsectionController = TextEditingController();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    final repo = AppScope.of(context).catalogRepository;
    _vm = ProductEditorViewModel(
      repository: repo,
      catalogId: widget.args.catalogId,
      itemId: widget.args.itemId,
    )..load();
  }

  @override
  void dispose() {
    _sectionController.dispose();
    _subsectionController.dispose();
    _titleController.dispose();
    _priceController.dispose();
    _descController.dispose();
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
        final item = vm.item;
        if (!_didInitForm && !vm.isBusy) {
          _didInitForm = true;
          _sectionController.text = item?.section ?? vm.lastSection ?? '';
          _subsectionController.text =
              item?.subsection ?? vm.lastSubsection ?? '';
          _titleController.text = item?.title ?? '';
          _priceController.text = item == null
              ? ''
              : item.price.toStringAsFixed(0);
          _descController.text = item?.description ?? '';
        }
        final items = vm.catalog?.items ?? const [];
        final sectionOptions = _sectionOptionList(items);
        final topSections = _topSections(items, limit: 6);
        final selectedSection = _sectionController.text.trim();
        final subsectionOptions = _subsectionOptionList(
          items,
          section: selectedSection.isEmpty ? null : selectedSection,
        );
        final topSubsections = _topSubsections(
          items,
          section: selectedSection.isEmpty ? null : selectedSection,
          limit: 6,
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.args.itemId == null ? 'Yeni öğe' : 'Öğeyi düzenle',
            ),
            actions: [
              if (item != null)
                IconButton(
                  tooltip: 'Sil',
                  onPressed: vm.isBusy
                      ? null
                      : () async {
                          final confirmed = await _confirmDelete(
                            context,
                            item.title,
                          );
                          if (!confirmed) return;
                          final ok = await vm.delete();
                          if (!context.mounted) return;
                          if (ok) Navigator.of(context).pop();
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: vm.isBusy
                ? null
                : () async {
                    final ok = await vm.save(
                      section: _sectionController.text,
                      subsection: _subsectionController.text,
                      title: _titleController.text.trim(),
                      priceText: _priceController.text.trim(),
                      description: _descController.text.trim(),
                    );
                    if (!context.mounted) return;
                    if (ok) Navigator.of(context).pop();
                  },
            icon: const Icon(Icons.check),
            label: const Text('Kaydet'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _buildPhotoCard(context, vm),
              const SizedBox(height: 12),
              _buildCategoryCard(
                context,
                vm: vm,
                sectionOptions: sectionOptions,
                topSections: topSections,
                subsectionOptions: subsectionOptions,
                topSubsections: topSubsections,
              ),
              const SizedBox(height: 12),
              _buildDetailsCard(context, vm),
              _buildValidationMessage(context, vm),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhotoCard(BuildContext context, ProductEditorViewModel vm) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Fotoğraf',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                if (vm.photoPath != null)
                  TextButton(
                    onPressed: vm.isBusy ? null : () => vm.setPhotoPath(null),
                    child: const Text('Kaldır'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (vm.photoPath == null)
              OutlinedButton.icon(
                onPressed: vm.isBusy
                    ? null
                    : () => _pickPhoto(context: context, vm: vm),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Fotoğraf ekle'),
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _PhotoPreview(data: vm.photoPath!),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: vm.isBusy
                    ? null
                    : () => _pickPhoto(context: context, vm: vm),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Değiştir'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required ProductEditorViewModel vm,
    required List<String> sectionOptions,
    required List<String> topSections,
    required List<String> subsectionOptions,
    required List<String> topSubsections,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Kategori (opsiyonel)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                if (_sectionController.text.trim().isNotEmpty ||
                    _subsectionController.text.trim().isNotEmpty)
                  TextButton(
                    onPressed: vm.isBusy
                        ? null
                        : () => setState(() {
                            _sectionController.clear();
                            _subsectionController.clear();
                          }),
                    child: const Text('Temizle'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Boş bırakırsan web menüde otomatik “Menü” altında görünür.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sectionController,
              decoration: InputDecoration(
                labelText: 'Ana menü',
                hintText: 'Örn: İçecekler',
                suffixIcon: IconButton(
                  tooltip: 'Öneriler',
                  onPressed: vm.isBusy || sectionOptions.isEmpty
                      ? null
                      : () async {
                          final picked = await _pickOption(
                            context,
                            title: 'Ana menü seç',
                            options: sectionOptions,
                          );
                          if (picked == null) return;
                          setState(() {
                            _sectionController.text = picked;
                            _subsectionController.clear();
                          });
                        },
                  icon: const Icon(Icons.list_alt_outlined),
                ),
              ),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
            if (vm.lastSection != null && vm.lastSection!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: Text('Son: ${vm.lastSection!}'),
                    onPressed: vm.isBusy
                        ? null
                        : () => setState(() {
                            _sectionController.text = vm.lastSection!;
                          }),
                  ),
                ],
              ),
            ],
            if (topSections.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in topSections)
                    ActionChip(
                      label: Text(s),
                      onPressed: vm.isBusy
                          ? null
                          : () => setState(() {
                              _sectionController.text = s;
                              _subsectionController.clear();
                            }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _subsectionController,
              decoration: InputDecoration(
                labelText: 'Alt menü',
                hintText: 'Örn: Soğuk',
                suffixIcon: IconButton(
                  tooltip: 'Öneriler',
                  onPressed: vm.isBusy || subsectionOptions.isEmpty
                      ? null
                      : () async {
                          final picked = await _pickOption(
                            context,
                            title: 'Alt menü seç',
                            options: subsectionOptions,
                          );
                          if (picked == null) return;
                          setState(() => _subsectionController.text = picked);
                        },
                  icon: const Icon(Icons.list_alt_outlined),
                ),
              ),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
            ),
            if (vm.lastSubsection != null && vm.lastSubsection!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: Text('Son: ${vm.lastSubsection!}'),
                    onPressed: vm.isBusy
                        ? null
                        : () => setState(
                            () =>
                                _subsectionController.text = vm.lastSubsection!,
                          ),
                  ),
                ],
              ),
            ],
            if (topSubsections.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in topSubsections)
                    ActionChip(
                      label: Text(s),
                      onPressed: vm.isBusy
                          ? null
                          : () =>
                                setState(() => _subsectionController.text = s),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context, ProductEditorViewModel vm) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Başlık'),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: 'Fiyat',
                suffixText: vm.catalog?.currencyCode,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]')),
              ],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Açıklama'),
              minLines: 3,
              maxLines: 6,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationMessage(
    BuildContext context,
    ProductEditorViewModel vm,
  ) {
    final message = vm.validationMessage;
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

List<String> _sectionOptionList(List<CatalogItem> items) {
  final set = <String>{};
  for (final i in items) {
    final s = i.section?.trim();
    if (s == null || s.isEmpty) continue;
    set.add(s);
  }
  final list = set.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
}

List<String> _subsectionOptionList(
  List<CatalogItem> items, {
  required String? section,
}) {
  final set = <String>{};
  for (final i in items) {
    final s = i.section?.trim();
    if (s == null || s.isEmpty) continue;
    if (section != null && section.isNotEmpty && s != section) continue;
    final sub = i.subsection?.trim();
    if (sub == null || sub.isEmpty) continue;
    set.add(sub);
  }
  final list = set.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
}

List<String> _topSections(List<CatalogItem> items, {required int limit}) {
  final counts = <String, int>{};
  for (final i in items) {
    final s = i.section?.trim();
    if (s == null || s.isEmpty) continue;
    counts[s] = (counts[s] ?? 0) + 1;
  }
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return a.key.toLowerCase().compareTo(b.key.toLowerCase());
    });
  return [for (final e in entries.take(limit)) e.key];
}

List<String> _topSubsections(
  List<CatalogItem> items, {
  required String? section,
  required int limit,
}) {
  final counts = <String, int>{};
  for (final i in items) {
    final s = i.section?.trim();
    if (section != null && section.isNotEmpty && s != section) continue;
    final sub = i.subsection?.trim();
    if (sub == null || sub.isEmpty) continue;
    counts[sub] = (counts[sub] ?? 0) + 1;
  }
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return a.key.toLowerCase().compareTo(b.key.toLowerCase());
    });
  return [for (final e in entries.take(limit)) e.key];
}

Future<String?> _pickOption(
  BuildContext context, {
  required String title,
  required List<String> options,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final controller = TextEditingController();
      var query = '';
      return StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = query.isEmpty
              ? options
              : [
                  for (final o in options)
                    if (o.toLowerCase().contains(query.toLowerCase())) o,
                ];
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Ara',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setModalState(() => query = v.trim()),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final value = filtered[index];
                      return Card(
                        child: ListTile(
                          title: Text(value),
                          trailing: const Icon(Icons.north_west),
                          onTap: () => Navigator.of(context).pop(value),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> _pickPhoto({
  required BuildContext context,
  required ProductEditorViewModel vm,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Fotoğraf ekle',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Galeriden seç'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Kamera ile çek'),
            ),
          ],
        ),
      );
    },
  );
  if (source == null) return;

  try {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (picked == null) return;

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final path = await ImageStorage.saveImageFile(
      sourcePath: picked.path,
      id: id,
    );
    vm.setPhotoPath(path);
  } on PlatformException catch (e) {
    if (!context.mounted) return;
    final message = e.code == 'channel-error'
        ? 'Fotoğraf seçici başlatılamadı. Uygulamayı tamamen kapatıp tekrar aç.'
        : 'Fotoğraf seçici açılamadı.';
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('Fotoğraf seçilirken hata oluştu.')),
      );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.data});
  final String data;

  @override
  Widget build(BuildContext context) {
    final commaIndex = data.indexOf(',');
    if (!data.startsWith('data:') || commaIndex == -1) {
      final file = File(data);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.image_not_supported_outlined)),
      );
    }
    final encoded = data.substring(commaIndex + 1);
    final bytes = base64Decode(encoded);
    return Image.memory(bytes, fit: BoxFit.cover);
  }
}

Future<bool> _confirmDelete(BuildContext context, String title) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Öğeyi sil?'),
        content: Text('"$title" silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
