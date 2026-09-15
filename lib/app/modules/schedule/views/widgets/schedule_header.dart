import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/schedule_controller.dart';

/// Top section: back arrow, plan thumbnail and plan title/subtitle.
class ScheduleHeader extends GetView<ScheduleController> {
  const ScheduleHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Back arrow
        IconButton(
          onPressed: () => Get.back<void>(),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        const SizedBox(width: 4),
        // Plan thumbnail
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Obx(() {
            final order = controller.selectedOrder.value;
            final url = order?.meal.imageUrl ?? '';
            return url.isEmpty
                ? const Icon(Icons.restaurant_menu, color: Colors.black54)
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.restaurant_menu, color: Colors.black54),
                  );
          }),
        ),
        const SizedBox(width: 12),
        // Plan title + subtitle
        Expanded(
          child: Obx(() {
            final sub = controller.subscription.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sub?.planName ?? 'Healthy Lab...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub?.subtitle ?? '5 Meals Weekly Plan · 6-week',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            );
          }),
        ),
        const SizedBox(width: 8),
        // Optional overflow menu
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.more_vert, color: Colors.black54),
        ),
      ],
    );
  }
}
