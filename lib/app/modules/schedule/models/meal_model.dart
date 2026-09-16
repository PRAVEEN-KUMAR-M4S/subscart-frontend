/// Nutrition/meal info shown inside an order card.
enum ItemStatus { scheduled, skipped, swapped, moved }

ItemStatus itemStatusFromString(String? name) => ItemStatus.values.firstWhere(
  (e) => e.name == name,
  orElse: () => ItemStatus.scheduled,
);

/// Nutrition/meal info shown inside an order card.
class MealModel {
  final String id;
  final String name;
  final String imageUrl;
  final int calories;
  final int fatGrams;
  final int proteinGrams;
  final int carbGrams;
  final int quantity; // Number of servings (backend: quantity)
  final ItemStatus
  itemStatus; // Per-item status (scheduled/skipped/swapped/moved)
  final MealModel? swappedMeal; // If swapped, the replacement meal
  final DateTime? movedDate; // If moved, the target date

  const MealModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.calories,
    required this.fatGrams,
    required this.proteinGrams,
    required this.carbGrams,
    this.quantity = 1,
    this.itemStatus = ItemStatus.scheduled,
    this.swappedMeal,
    this.movedDate,
  });

  bool get isSkipped => itemStatus == ItemStatus.skipped;
  bool get isSwapped => itemStatus == ItemStatus.swapped;
  bool get isMoved => itemStatus == ItemStatus.moved;
  bool get isScheduled => itemStatus == ItemStatus.scheduled;

  /// Handles both Flutter-expected keys and actual backend keys:
  ///   Backend: _id, image, fat, protein, carbs
  ///   Flutter: id, imageUrl, fatGrams, proteinGrams, carbGrams
  factory MealModel.fromJson(Map<String, dynamic> json) {
    // Parse swapped meal if present
    MealModel? swapped;
    if (json['swappedMeal'] is Map<String, dynamic>) {
      swapped = MealModel.fromJson(json['swappedMeal'] as Map<String, dynamic>);
    }

    // Parse moved date if present
    DateTime? moved;
    if (json['movedDate'] != null) {
      moved = DateTime.tryParse(json['movedDate'].toString());
    }

    return MealModel(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imageUrl: (json['imageUrl'] ?? json['image'])?.toString() ?? '',
      calories: _toInt(json['calories']),
      fatGrams: _toInt(json['fatGrams'] ?? json['fat']),
      proteinGrams: _toInt(json['proteinGrams'] ?? json['protein']),
      carbGrams: _toInt(json['carbGrams'] ?? json['carbs']),
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
    'calories': calories,
    'fatGrams': fatGrams,
    'proteinGrams': proteinGrams,
    'carbGrams': carbGrams,
    'quantity': quantity,
    'itemStatus': itemStatus.name,
    if (swappedMeal != null) 'swappedMeal': swappedMeal!.toJson(),
    if (movedDate != null) 'movedDate': movedDate!.toIso8601String(),
  };

  static int _toInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}
