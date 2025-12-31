import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog.dart';
import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog_item.dart';

Map<String, Object?> catalogToJson(Catalog catalog) {
  return <String, Object?>{
    'id': catalog.id,
    'name': catalog.name,
    'selectedTemplateId': catalog.selectedTemplateId,
    'currencyCode': catalog.currencyCode,
    'updatedAtMs': catalog.updatedAt.millisecondsSinceEpoch,
    'items': [for (final i in catalog.items) catalogItemToJson(i)],
  };
}

Catalog catalogFromJson(Map<String, Object?> json) {
  final itemsRaw = json['items'];
  final items = <CatalogItem>[];
  if (itemsRaw is List) {
    for (final entry in itemsRaw) {
      if (entry is Map) {
        items.add(catalogItemFromJson(Map<String, Object?>.from(entry)));
      }
    }
  }
  return Catalog(
    id: (json['id'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    items: items,
    selectedTemplateId: (json['selectedTemplateId'] as String?) ?? 'minimal_green',
    currencyCode: (json['currencyCode'] as String?) ?? 'TRY',
    updatedAt: DateTime.fromMillisecondsSinceEpoch((json['updatedAtMs'] as num?)?.toInt() ?? 0),
  );
}

Map<String, Object?> catalogItemToJson(CatalogItem item) {
  return <String, Object?>{
    'id': item.id,
    'title': item.title,
    'price': item.price,
    'description': item.description,
    'photoPath': item.photoPath,
    'section': item.section,
    'subsection': item.subsection,
  };
}

CatalogItem catalogItemFromJson(Map<String, Object?> json) {
  return CatalogItem(
    id: (json['id'] as String?) ?? '',
    title: (json['title'] as String?) ?? '',
    price: (json['price'] as num?)?.toDouble() ?? 0,
    description: (json['description'] as String?) ?? '',
    photoPath: json['photoPath'] as String?,
    section: (json['section'] as String?)?.trim(),
    subsection: (json['subsection'] as String?)?.trim(),
  );
}
