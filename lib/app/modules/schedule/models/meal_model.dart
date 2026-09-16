/// Item/meal info shown inside an order card.
enum ItemStatus { scheduled, skipped, swapped, moved }

ItemStatus itemStatusFromString(String? name) => ItemStatus.values.firstWhere(
  (e) => e.name == name,
  orElse: () => ItemStatus.scheduled,
);

/// Item/meal info shown inside an order card.
class MealModel {
  final String id;
  final String name;
  final String imageUrl;
  final String description;
  final int quantity;
  final ItemStatus itemStatus;
  final MealModel? swappedMeal;
  final DateTime? movedDate;

  const MealModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.description = '',
    this.quantity = 1,
    this.itemStatus = ItemStatus.scheduled,
    this.swappedMeal,
    this.movedDate,
  });

  bool get isSkipped => itemStatus == ItemStatus.skipped;
  bool get isSwapped => itemStatus == ItemStatus.swapped;
  bool get isMoved => itemStatus == ItemStatus.moved;
  bool get isScheduled => itemStatus == ItemStatus.scheduled;

  factory MealModel.fromJson(Map<String, dynamic> json) {
    MealModel? swapped;
    if (json['swappedMeal'] is Map<String, dynamic>) {
      swapped = MealModel.fromJson(json['swappedMeal'] as Map<String, dynamic>);
    }

    DateTime? moved;
    if (json['movedDate'] != null) {
      moved = DateTime.tryParse(json['movedDate'].toString());
    }

    return MealModel(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imageUrl: (json['imageUrl'] ?? json['image'])?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      quantity: _toInt(json['quantity']),
      itemStatus: itemStatusFromString(json['itemStatus']?.toString()),
      swappedMeal: swapped,
      movedDate: moved,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'imageUrl': imageUrl,
    'description': description,
    'quantity': quantity,
    'itemStatus': itemStatus.name,
    if (swappedMeal != null) 'swappedMeal': swappedMeal!.toJson(),
    if (movedDate != null) 'movedDate': movedDate!.toIso8601String(),
  };

  static int _toInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}
