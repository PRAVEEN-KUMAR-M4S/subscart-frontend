import 'meal_model.dart';

enum OrderStatus { scheduled, skipped, swapped, moved }

OrderStatus orderStatusFromName(String? name) => OrderStatus.values.firstWhere(
  (e) => e.name == name,
  orElse: () => OrderStatus.scheduled,
);

/// One scheduled delivery inside a subscription.
class OrderModel {
  final String id;
  final String orderNumber;
  final String deliveryTag;
  final String address;
  final String deliveryTime;
  final String deliverySlotStart;
  final String deliverySlotEnd;
  final String editableUntil;
  final bool deliverySlotEnabled;
  final MealModel meal;
  final List<MealModel> items;
  final OrderStatus status;
  final DateTime date;
  final List<String> itemBackendIds;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.deliveryTag,
    required this.address,
    required this.deliveryTime,
    required this.deliverySlotStart,
    required this.deliverySlotEnd,
    required this.editableUntil,
    required this.deliverySlotEnabled,
    required this.meal,
    this.items = const [],
    this.status = OrderStatus.scheduled,
    required this.date,
    this.itemBackendIds = const [],
  });

  MealModel? getItemByIndex(int index) {
    if (index < 0 || index >= items.length) return null;
    return items[index];
  }

  String? getItemBackendId(int index) {
    if (index < 0 || index >= itemBackendIds.length) return null;
    return itemBackendIds[index];
  }

  bool isEditLocked(DateTime now) => now.isAfter(date);

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  OrderModel copyWith({
    String? id,
    String? orderNumber,
    String? deliveryTag,
    String? address,
    String? deliveryTime,
    String? deliverySlotStart,
    String? deliverySlotEnd,
    String? editableUntil,
    bool? deliverySlotEnabled,
    MealModel? meal,
    List<MealModel>? items,
    OrderStatus? status,
    DateTime? date,
    List<String>? itemBackendIds,
  }) => OrderModel(
    id: id ?? this.id,
    orderNumber: orderNumber ?? this.orderNumber,
    deliveryTag: deliveryTag ?? this.deliveryTag,
    address: address ?? this.address,
    deliveryTime: deliveryTime ?? this.deliveryTime,
    deliverySlotStart: deliverySlotStart ?? this.deliverySlotStart,
    deliverySlotEnd: deliverySlotEnd ?? this.deliverySlotEnd,
    editableUntil: editableUntil ?? this.editableUntil,
    deliverySlotEnabled: deliverySlotEnabled ?? this.deliverySlotEnabled,
    meal: meal ?? this.meal,
    items: items ?? this.items,
    status: status ?? this.status,
    date: date ?? this.date,
    itemBackendIds: itemBackendIds ?? this.itemBackendIds,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderNumber': orderNumber,
    'deliveryTag': deliveryTag,
    'address': address,
    'deliveryTime': deliveryTime,
    'deliverySlotStart': deliverySlotStart,
    'deliverySlotEnd': deliverySlotEnd,
    'editableUntil': editableUntil,
    'deliverySlotEnabled': deliverySlotEnabled,
    'meal': meal.toJson(),
    'items': items.map((m) => m.toJson()).toList(),
    'status': status.name,
    'date': date.toIso8601String(),
  };

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['_id'])?.toString() ?? '';

    final slot = json['deliverySlot'] as Map<String, dynamic>?;
    final slotStart =
        (json['deliverySlotStart'] ?? slot?['startTime'])?.toString() ?? '';
    final slotEnd =
        (json['deliverySlotEnd'] ?? slot?['endTime'])?.toString() ?? '';
    final editable =
        (json['editableUntil'] ?? slot?['editableUntil'])?.toString() ?? '';
    final deliveryTime = slotStart.isNotEmpty && slotEnd.isNotEmpty
        ? '${_formatTime(slotStart)} - ${_formatTime(slotEnd)}'
        : json['deliveryTime']?.toString() ?? '';

    final orderNumber =
        json['orderNumber']?.toString() ??
        (id.isNotEmpty
            ? '#${id.substring(id.length > 6 ? id.length - 6 : 0)}'
            : '');
    final deliveryTag = json['deliveryTag']?.toString() ?? 'Delivery';

    final date =
        DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now();

    // Primary item
    MealModel meal;
    if (json['meal'] is Map<String, dynamic>) {
      meal = MealModel.fromJson(json['meal'] as Map<String, dynamic>);
    } else {
      meal = const MealModel(id: '', name: '', imageUrl: '');
    }

    // Multiple items
    List<MealModel> items = [];
    List<String> itemIds = [];
    if (json['items'] is List) {
      final itemsList = json['items'] as List;
      for (final itemJson in itemsList) {
        if (itemJson is Map<String, dynamic>) {
          items.add(MealModel.fromJson(itemJson));
          final itemId = (itemJson['_id'] ?? itemJson['id'])?.toString() ?? '';
          itemIds.add(itemId);
        }
      }
    }
    if (items.isEmpty && meal.name.isNotEmpty) {
      items = [meal];
      itemIds = [''];
    }

    return OrderModel(
      id: id,
      orderNumber: orderNumber,
      deliveryTag: deliveryTag,
      address: json['address']?.toString() ?? '',
      deliveryTime: deliveryTime,
      deliverySlotStart: slotStart,
      deliverySlotEnd: slotEnd,
      editableUntil: editable,
      deliverySlotEnabled: json['deliverySlotEnabled'] != false,
      meal: meal,
      items: items,
      status: orderStatusFromName(json['status']?.toString()),
      date: date,
      itemBackendIds: itemIds,
    );
  }

  static String _formatTime(String time) {
    final lower = time.toLowerCase().trim();
    if (lower.endsWith(' am') || lower.endsWith(' pm')) {
      return '${lower.substring(0, lower.length - 3).trim()} '
          '${lower.substring(lower.length - 2).toUpperCase()}';
    }
    return time;
  }

  static OrderStatus statusFromName(String? name) => orderStatusFromName(name);
}
