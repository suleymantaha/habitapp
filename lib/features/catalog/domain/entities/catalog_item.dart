class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.title,
    required this.price,
    required this.description,
    required this.photoPath,
    this.section,
    this.subsection,
  });

  final String id;
  final String title;
  final double price;
  final String description;
  final String? photoPath;
  final String? section;
  final String? subsection;

  CatalogItem copyWith({
    String? id,
    String? title,
    double? price,
    String? description,
    String? photoPath,
    String? section,
    String? subsection,
  }) {
    return CatalogItem(
      id: id ?? this.id,
      title: title ?? this.title,
      price: price ?? this.price,
      description: description ?? this.description,
      photoPath: photoPath ?? this.photoPath,
      section: section ?? this.section,
      subsection: subsection ?? this.subsection,
    );
  }
}
