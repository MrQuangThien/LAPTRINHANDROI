class RestaurantTable {
  const RestaurantTable({
    required this.id,
    required this.areaId,
    required this.area,
    required this.name,
    required this.capacity,
    required this.status,
    this.activeOrderId,
    this.activeOrderCount = 0,
    this.activeOrders = const [],
  });
  final int id;
  final int areaId;
  final String area;
  final String name;
  final int capacity;
  final String status;
  final int? activeOrderId;
  final int activeOrderCount;
  final List<Map<String, dynamic>> activeOrders;
  factory RestaurantTable.fromJson(Map<String, dynamic> json) =>
      RestaurantTable(
        id: (json['id'] as num).toInt(),
        areaId: (json['areaId'] as num).toInt(),
        area: json['area'] as String? ?? '',
        name: json['tableName'] as String? ?? '',
        capacity: (json['capacity'] as num).toInt(),
        status: json['status'] as String? ?? 'Available',
        activeOrderId: (json['activeOrderId'] as num?)?.toInt(),
        activeOrderCount: (json['activeOrderCount'] as num?)?.toInt() ?? 0,
        activeOrders: (json['activeOrders'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
}
