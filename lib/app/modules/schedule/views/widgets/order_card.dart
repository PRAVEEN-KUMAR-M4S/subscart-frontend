import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/schedule_controller.dart';
import '../../models/meal_model.dart';
import '../../models/order_model.dart';
import 'bottom_action_bar.dart';
import 'meal_item_card.dart';

/// White rounded card describing the selected day's order.
/// Each item is displayed with its image, name, description,
/// and skip/swap/move buttons below it.
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
      builder: (_) => _SwapMealSheet(order: order),
    );
  }

  void _showAddItemSheet(OrderModel order) {
    showModalBottomSheet<void>(
      context: Get.context!,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddItemSheet(order: order),
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
      selectableDayPredicate: (d) => days.any(
        (slot) =>
            slot.date.year == d.year &&
            slot.date.month == d.month &&
            slot.date.day == d.day,
      ),
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
                          child: const Icon(
                            Icons.lunch_dining,
                            size: 16,
                            color: Colors.black87,
                          ),
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
                            horizontal: 10,
                            vertical: 3,
                          ),
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
                        if (editable && !controller.isMutating.value)
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () => controller
                                  .pickAndRescheduleDeliverySlot(order.id),
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
                          ),
                      ],
                    ),
                    const Divider(height: 20),
                    // --- Address + time
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            order.address,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${order.deliverySlotStart} - ${order.deliverySlotEnd}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
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
                                  controller.orders[controller.orders
                                      .indexWhere(
                                        (o) => o.id == order.id,
                                      )] = order.copyWith(
                                    deliverySlotEnabled: v,
                                  );
                                  if (controller.selectedOrder.value?.id ==
                                      order.id) {
                                    controller.selectedOrder.value = order
                                        .copyWith(deliverySlotEnabled: v);
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
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // --- Items section header
                    if (order.items.length > 1) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Items (${order.items.length})',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '${order.totalCalories} cal total',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    // --- Each item with MealItemCard (includes BottomActionBar at bottom)
                    ...order.items.map((item) => MealItemCard(meal: item)),
                    // Fallback to primary meal if items is empty
                    if (order.items.isEmpty) ...[
                      _PrimaryMealCardWithActions(order: order),
                    ],
                    // --- Add Item button (only if editable)
                    if (editable && !controller.isMutating.value) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _showAddItemSheet(order),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add,
                                size: 20,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Add Item',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Primary meal card widget with BottomActionBar when items list is empty.
class _PrimaryMealCardWithActions extends GetView<ScheduleController> {
  final OrderModel order;

  const _PrimaryMealCardWithActions({required this.order});

  bool get _canEdit {
    if (order == null) return false;
    return controller.isOrderEditable(order);
  }

  @override
  Widget build(BuildContext context) {
    final editable = _canEdit;
    final skipped = order.status == OrderStatus.skipped;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Meal card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: order.meal.isSkipped
                  ? Colors.grey.shade300
                  : order.meal.isSwapped
                  ? const Color(0xFF27A768).withValues(alpha: 0.5)
                  : order.meal.isMoved
                  ? Colors.blue.shade200
                  : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meal image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: Image.network(
                      order.meal.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: Colors.grey.shade100,
                        child: const Icon(
                          Icons.restaurant,
                          color: Colors.black54,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Meal details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.meal.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: order.meal.isSkipped
                              ? Colors.grey.shade400
                              : order.meal.isSwapped
                              ? const Color(0xFF27A768)
                              : order.meal.isMoved
                              ? Colors.blue.shade600
                              : Colors.black,
                          decoration: order.meal.isSkipped
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.meal.calories} Calories, fat '
                        '${order.meal.fatGrams}g, protein '
                        '${order.meal.proteinGrams}g and carbohydrates '
                        '${order.meal.carbGrams}g',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Bottom action bar
        const SizedBox(height: 8),
        BottomActionBar(
          skipped: skipped,
          editable: editable,
          onSkip: () {
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
          },
          onSwap: () {
            showModalBottomSheet<void>(
              context: Get.context!,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => _SwapMealSheet(order: order),
            );
          },
          onMove: () async {
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
              selectableDayPredicate: (d) => days.any(
                (slot) =>
                    slot.date.year == d.year &&
                    slot.date.month == d.month &&
                    slot.date.day == d.day,
              ),
              helpText: 'Move to a scheduled day',
            );
            if (picked != null) {
              await controller.moveOrder(
                order.id,
                DateTime(picked.year, picked.month, picked.day),
              );
            }
          },
        ),
      ],
    );
  }
}

/// Bottom sheet listing swappable meals fetched via GET /meals.
class _SwapMealSheet extends GetView<ScheduleController> {
  final OrderModel order;

  const _SwapMealSheet({required this.order});

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
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed: () => Get.back<void>(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Select a new meal for Order ${order.orderNumber}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            if (order.meal.name.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Current: ${order.meal.name}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Flexible(
              child: Obx(() {
                if (controller.meals.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: controller.meals.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final meal = controller.meals[index];
                    final isCurrentMeal = meal.name == order.meal.name;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: isCurrentMeal
                          ? null
                          : () {
                              Get.back<void>();
                              controller.swapMeal(order.id, meal);
                            },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isCurrentMeal
                              ? Colors.grey.shade50
                              : Colors.white,
                          border: Border.all(
                            color: isCurrentMeal
                                ? Colors.grey.shade300
                                : Colors.grey.shade200,
                          ),
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
                                    child: const Icon(
                                      Icons.restaurant,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          meal.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isCurrentMeal
                                                ? Colors.grey.shade500
                                                : Colors.black,
                                          ),
                                        ),
                                      ),
                                      if (isCurrentMeal)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'Current',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ),
                                    ],
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
                            if (!isCurrentMeal)
                              const Icon(
                                Icons.swap_horiz,
                                color: Colors.black54,
                              ),
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

/// Bottom sheet for adding a new item to the order.
class _AddItemSheet extends GetView<ScheduleController> {
  final OrderModel order;

  const _AddItemSheet({required this.order});

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
                  'Add Item to Order',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed: () => Get.back<void>(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Select a meal to add to Order ${order.orderNumber}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: Obx(() {
                if (controller.meals.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    ),
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
                        // Create a new item from the selected meal
                        final newItem = MealModel(
                          id: '', // Will be assigned by backend
                          name: meal.name,
                          imageUrl: meal.imageUrl,
                          calories: meal.calories,
                          fatGrams: meal.fatGrams,
                          proteinGrams: meal.proteinGrams,
                          carbGrams: meal.carbGrams,
                          quantity: 1,
                          itemStatus: ItemStatus.scheduled,
                        );
                        controller.addItemToOrder(order.id, newItem);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.grey.shade200,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 52,
                                height: 52,
                                child: Image.network(
                                  meal.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: Colors.grey.shade100,
                                    child: const Icon(
                                      Icons.restaurant,
                                      color: Colors.black54,
                                      size: 20,
                                    ),
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
                                      color: Colors.black,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${meal.calories} Cal, '
                                    'fat ${meal.fatGrams}g, '
                                    'protein ${meal.proteinGrams}g, '
                                    'carbs ${meal.carbGrams}g',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.add_circle,
                              color: Color(0xFF27A768),
                              size: 24,
                            ),
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
