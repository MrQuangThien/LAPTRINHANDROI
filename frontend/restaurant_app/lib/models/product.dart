class Product {
  const Product({
    required this.id,
    required this.categoryId,
    required this.category,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    required this.available,
  });
  final int id;
  final int categoryId;
  final String category;
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;
  final bool available;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: (json['id'] as num).toInt(),
    categoryId: (json['categoryId'] as num).toInt(),
    category: json['category'] as String? ?? '',
    name: json['name'] as String? ?? '',
    price: (json['price'] as num).toDouble(),
    description: json['description'] as String?,
    imageUrl: json['imageUrl'] as String?,
    available:
        (json['isAvailable'] as bool? ?? true) &&
        (json['categoryIsActive'] as bool? ?? true),
  );
}
