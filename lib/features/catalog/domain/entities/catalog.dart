import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog_item.dart';

class Catalog {
  const Catalog({
    required this.id,
    required this.name,
    required this.items,
    required this.selectedTemplateId,
    required this.currencyCode,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<CatalogItem> items;
  final String selectedTemplateId;
  final String currencyCode;
  final DateTime updatedAt;

  Catalog copyWith({
    String? id,
    String? name,
    List<CatalogItem>? items,
    String? selectedTemplateId,
    String? currencyCode,
    DateTime? updatedAt,
  }) {
    return Catalog(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      selectedTemplateId: selectedTemplateId ?? this.selectedTemplateId,
      currencyCode: currencyCode ?? this.currencyCode,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
