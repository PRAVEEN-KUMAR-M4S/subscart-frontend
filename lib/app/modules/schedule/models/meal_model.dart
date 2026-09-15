/// Nutrition/meal info shown inside an order card.
class MealModel {
  final String id;
  final String name;
  final String imageUrl;
  final int calories;
  final int fatGrams;
  final int proteinGrams;
  final int carbGrams;

  const MealModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.calories,
    required this.fatGrams,
    required this.proteinGrams,
    required this.carbGrams,
  });

  /// Handles both Flutter-expected keys and actual backend keys:
  ///   Backend: _id, image, fat, protein, carbs
  ///   Flutter: id, imageUrl, fatGrams, proteinGrams, carbGrams
  factory MealModel.fromJson(Map<String, dynamic> json) => MealModel(
        id: (json['id'] ?? json['_id'])?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        imageUrl: (json['imageUrl'] ?? json['image'])?.toString() ?? '',
        calories: _toInt(json['calories']),
        fatGrams: _toInt(json['fatGrams'] ?? json['fat']),
        proteinGrams: _toInt(json['proteinGrams'] ?? json['protein']),
        carbGrams: _toInt(json['carbGrams'] ?? json['carbs']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imageUrl': imageUrl,
        'calories': calories,
        'fatGrams': fatGrams,
        'proteinGrams': proteinGrams,
        'carbGrams': carbGrams,
      };

  static int _toInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}
