import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/schedule_controller.dart';
import '../../models/order_model.dart';
import 'bottom_action_bar.dart';
import 'meal_item_card.dart';

/// White rounded card describing the selected day's order.
class OrderCard extends GetView<ScheduleController> {
  const OrderCard({super.key});

  bool get _canEdit {
    final order = controller.selectedOrder.value;
    if (order == null) return false;
    return controller.isOrderEditable(order);
  }

  void _confirmSkip(OrderModel order) {
    Get.defaultDialog(
      title: 'Skip this delivery?',
      middleText:
          'Order ${order.orderNumber} will be skipped for this week. You can un-skip until the cut-off time.',
      textCancel: 'Cancel',
      textConfirm: 'Skip',
      confirmTextColor: Colors.white,
      buttonColor: Colors.black,
      onConfirm: () {
        Get.back<void>();
        controller.skipOrder(order.id);
      },
    );
  }

  void _openSwapSheet(OrderModel order) {
    showModalBottomSheet<void>(
      context: Get.context!,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SwapMealSheet(orderId: order.id),
    );
  }

  Future<void> _pickMoveDate(OrderModel order) async {
    final days = controller.scheduleDays;
    if (days.isEmpty) return;
    final first = days.first.date;
    final last = days.last.date;

    final picked = await showDatePicker(
      context: Get.context!,
      initialDate: order.date.isBefore(first)
          ? first
          : (order.date.isAfter(last) ? last : order.date),
      firstDate: first,
      lastDate: last,
      selectableDayPredicate: (d) =>
          days.any((slot) =>
              slot.date.year == d.year &&
              slot.date.month == d.month &&
              slot.date.day == d.day),
      helpText: 'Move to a scheduled day',
    );
    if (picked != null) {
      await controller.moveOrder(
        order.id,
        DateTime(picked.year, picked.month, picked.day),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final order = controller.selectedOrder.value;
      if (order == null) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 32),
          alignment: Alignment.center,
          child: Text(
            'No order scheduled for this day.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        );
      }

      final skipped = order.status == OrderStatus.skipped;
      final editable = _canEdit;

      return Opacity(
        opacity: skipped ? 0.55 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Top row: order title + tag | Re-schedule button
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lunch_dining,
                              size: 16, color: Colors.black87),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Order ${order.orderNumber}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F6EC),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            order.deliveryTag,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF27A768),
                            ),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed:
                              editable && !controller.isMutating.value
                                  ? () => controller
                                      .pickAndRescheduleDeliverySlot(order.id)
                                  : null,
                          icon: const Icon(Icons.access_time, size: 16),
                          label: const Text('Re-schedule'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black,
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    // --- Address + time
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 16, color: Colors.black54),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            order.address,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black87),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.access_time,
                            size: 16, color: Colors.black54),
                        const SizedBox(width: 4),
                        Text(
                          '${order.deliverySlotStart} - ${order.deliverySlotEnd}',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // --- Delivery Slot toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Delivery Slot',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        Switch(
                          value: order.deliverySlotEnabled,
                          onChanged: editable
                              ? (v) {
                                  // Local-only toggle; server sync could be added here.
                                  controller.orders[controller.orders
                                          .indexWhere((o) => o.id == order.id)] =
                                      order.copyWith(deliverySlotEnabled: v);
                                  if (controller.selectedOrder.value?.id ==
                                      order.id) {
                                    controller.selectedOrder.value =
                                        order.copyWith(deliverySlotEnabled: v);
                                  }
                                }
                              : null,
                          activeThumbColor: Colors.black,
                          activeTrackColor: Colors.black26,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // --- Edit cut-off helper
                    Text(
                      'Edits allowed until ${order.editableUntil} the day of your Order',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 12),
                    // --- Meal item
                    MealItemCard(meal: order.meal),
                  ],
                ),
              ),
              // --- Bottom action bar
              BottomActionBar(
                skipped: skipped,
                editable: editable,
                onSkip: () => _confirmSkip(order),
                onSwap: () => _openSwapSheet(order),
                onMove: () => _pickMoveDate(order),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Bottom sheet listing swappable meals fetched via GET /meals.
class _SwapMealSheet extends GetView<ScheduleController> {
  final String orderId;

  const _SwapMealSheet({required this.orderId});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Swap your meal',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed: () => Get.back<void>(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Obx(() {
                if (controller.meals.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(color: Colors.black)),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: controller.meals.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final meal = controller.meals[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Get.back<void>();
                        controller.swapMeal(orderId, meal);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 52,
                                height: 52,
                                child: Image.network(
                                  meal.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: Colors.grey.shade100,
                                    child: const Icon(Icons.restaurant,
                                        color: Colors.black54),
                                  ),
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
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${meal.calories} Calories, fat ${meal.fatGrams}g, '
                                    'protein ${meal.proteinGrams}g and carbohydrates '
                                    '${meal.carbGrams}g',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.swap_horiz,
                                color: Colors.black54),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
