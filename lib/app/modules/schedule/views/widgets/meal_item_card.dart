import 'package:flutter/material.dart';

import '../../models/meal_model.dart';

/// Square meal thumbnail with name and nutrition summary.
class MealItemCard extends StatelessWidget {
  final MealModel meal;

  const MealItemCard({super.key, required this.meal});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 64,
            height: 64,
            child: Image.network(
              meal.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: Colors.grey.shade100,
                child: const Icon(Icons.restaurant, color: Colors.black54),
              ),
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : Container(color: Colors.grey.shade100),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meal.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${meal.calories} Calories, fat ${meal.fatGrams}g, '
                'protein ${meal.proteinGrams}g and carbohydrates ${meal.carbGrams}g',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
