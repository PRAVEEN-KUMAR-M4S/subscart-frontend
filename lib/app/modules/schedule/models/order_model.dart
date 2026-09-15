import 'meal_model.dart';

enum OrderStatus { scheduled, skipped, swapped, moved }

OrderStatus orderStatusFromName(String? name) =>
    OrderStatus.values.firstWhere(
      (e) => e.name == name,
      orElse: () => OrderStatus.scheduled,
    );

/// One scheduled delivery inside a subscription.
class OrderModel {
  final String id;
  final String orderNumber;
  final String deliveryTag; // e.g. "Delivery"
  final String address;
  final String deliveryTime; // e.g. "8:17 am - 9:17..."
  final String deliverySlotStart; // e.g. "8:17 AM"
  final String deliverySlotEnd; // e.g. "9:17 AM"
  final String editableUntil; // e.g. "7:17 AM"
  final bool deliverySlotEnabled;
  final MealModel meal;
  final OrderStatus status;
  final DateTime date;

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
    this.status = OrderStatus.scheduled,
    required this.date,
  });

  /// True once the current time has passed the edit cut-off.
  bool isEditLocked(DateTime now) => now.isAfter(date);

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
    OrderStatus? status,
    DateTime? date,
  }) =>
      OrderModel(
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
        status: status ?? this.status,
        date: date ?? this.date,
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
        'status': status.name,
        'date': date.toIso8601String(),
      };

  /// Handles both Flutter-expected keys and actual backend format:
  ///   Backend: _id, address, deliverySlot: {startTime, endTime, editableUntil},
  ///            meal: {name, image, calories, fat, protein, carbs}, status
  ///   Flutter: id, orderNumber, deliveryTag, address, deliveryTime,
  ///            deliverySlotStart, deliverySlotEnd, editableUntil,
  ///            deliverySlotEnabled, meal, status, date
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // --- id ---
    final id = (json['id'] ?? json['_id'])?.toString() ?? '';

    // --- delivery slot (nested on backend, flat on Flutter) ---
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

    // --- orderNumber / deliveryTag (not on backend) ---
    final orderNumber = json['orderNumber']?.toString() ??
        (id.isNotEmpty ? '#${id.substring(id.length > 6 ? id.length - 6 : 0)}' : '');
    final deliveryTag = json['deliveryTag']?.toString() ?? 'Delivery';

    // --- date ---
    final date = DateTime.tryParse(json['date']?.toString() ?? '') ??
        DateTime.now();

    // --- meal (nested on backend) ---
    MealModel meal;
    if (json['meal'] is Map<String, dynamic>) {
      meal = MealModel.fromJson(json['meal'] as Map<String, dynamic>);
    } else {
      meal = const MealModel(
        id: '',
        name: '',
        imageUrl: '',
        calories: 0,
        fatGrams: 0,
        proteinGrams: 0,
        carbGrams: 0,
      );
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
      status: orderStatusFromName(json['status']?.toString()),
      date: date,
    );
  }

  /// Format time strings like "8:17 am" to "8:17 AM" for consistent display.
  static String _formatTime(String time) {
    final lower = time.toLowerCase().trim();
    if (lower.endsWith(' am') || lower.endsWith(' pm')) {
      return lower.replaceAll(RegExp(r'\s(am|pm)$/i'), '').trim() +
          ' ' +
          lower.substring(lower.length - 2).toUpperCase();
    }
    return time;
  }

  static OrderStatus statusFromName(String? name) => orderStatusFromName(name);
}
