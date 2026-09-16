import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/schedule_controller.dart';
import '../../models/meal_model.dart';
import '../../models/order_model.dart';
import 'bottom_action_bar.dart';

/// Square meal thumbnail with name, nutrition summary, and
/// Skip / Swap / Move actions.
/// When skipped, the item animates out and is removed from the UI.
class MealItemCard extends GetView<ScheduleController> {
  final MealModel meal;
  final VoidCallback? onRemoved; // Callback when item is removed

  const MealItemCard({super.key, required this.meal, this.onRemoved});

  /// The backend sub-document `_id` for this item.
  ///
  /// Derived directly from `meal.id` (already parsed from backend JSON)
  /// so we NEVER depend on positional list indices — which can drift
  /// when earlier items are skipped/moved/added.
  String get backendItemId => meal.id;

  bool get _isEditable {
    final order = controller.selectedOrder.value;
    if (order == null) return false;
    return controller.isOrderEditable(order);
  }

  void _confirmSkip(OrderModel order) {
    final itemId = backendItemId;
    if (itemId.isEmpty) return;
    Get.defaultDialog(
      title: 'Skip this item?',
      middleText: 'This meal item will be removed from your order.',
      textCancel: 'Cancel',
      textConfirm: 'Skip',
      confirmTextColor: Colors.white,
      buttonColor: Colors.black,
      onConfirm: () {
        Get.back<void>();
        controller.skipItem(order.id, itemId);
      },
    );
  }

  void _openSwapSheet(OrderModel order) {
    final itemId = backendItemId;
    if (itemId.isEmpty) return;
    showModalBottomSheet<void>(
      context: Get.context!,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _SwapItemSheet(order: order, currentMeal: meal, itemId: itemId),
    );
  }

  Future<void> _pickMoveDate(OrderModel sourceOrder) async {
    final itemId = backendItemId;
    if (itemId.isEmpty) return;

    final days = controller.scheduleDays;
    if (days.isEmpty) return;
    final first = days.first.date;
    final last = days.last.date;

    final picked = await showDatePicker(
      context: Get.context!,
      initialDate: sourceOrder.date.isBefore(first)
          ? first
          : (sourceOrder.date.isAfter(last) ? last : sourceOrder.date),
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
    if (picked == null) return;

    final normalized = DateTime(picked.year, picked.month, picked.day);
    final context = Get.context!;

    // Show a loading dialog while fetching candidate orders for the target date
    Get.dialog<void>(
      const Center(
        child: SizedBox(
          width: 44,
          height: 44,
          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
        ),
      ),
      barrierDismissible: false,
    );
    final candidates = await controller.fetchOrdersForDate(normalized);
    if (Get.isDialogOpen ?? false) Get.back<void>();

    if (candidates.isEmpty) {
      Get.snackbar(
        'No delivery on this day',
        'Choose a scheduled day that already has a delivery — the meal will be added to it.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF323232),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
      );
      return;
    }

    // Filter out the source order itself in case user picks the same date
    final filtered = candidates.where((o) => o.id != sourceOrder.id).toList();
    if (filtered.isEmpty) {
      Get.snackbar(
        'Choose a different day',
        'This is the only delivery on this date — pick another scheduled day.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF323232),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
      );
      return;
    }

    if (filtered.length == 1) {
      // Only one existing order on the target date — move directly
      await controller.moveItem(
        orderId: sourceOrder.id,
        itemId: itemId,
        targetOrderId: filtered.first.id,
      );
    } else {
      // 2+ orders on the target date — let user pick which delivery
      if (!context.mounted) return;
      final chosen = await showModalBottomSheet<_TargetOrderPick>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _TargetOrderPickerSheet(
          targetDate: normalized,
          candidates: filtered,
        ),
      );
      if (chosen != null) {
        await controller.moveItem(
          orderId: sourceOrder.id,
          itemId: itemId,
          targetOrderId: chosen.orderId,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = controller.selectedOrder.value;
    final skipped = meal.isSkipped;
    // Allow actions on swapped items too (except skip which removes the item)
    // Only skip is disabled for skipped items, move is disabled for moved items
    final canSkip = _isEditable && !skipped;
    final canSwap = _isEditable && !skipped;
    final canMove = _isEditable && !skipped && !meal.isMoved;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: skipped ? 0.0 : 1.0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: skipped ? const Offset(0, -0.1) : Offset.zero,
        child: IgnorePointer(
          ignoring: skipped,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                          child: const Icon(
                            Icons.restaurant,
                            color: Colors.black54,
                          ),
                        ),
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                            ? child
                            : Container(color: Colors.grey.shade100),
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
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: skipped
                                ? Colors.grey.shade400
                                : meal.isSwapped
                                ? const Color(0xFF27A768)
                                : meal.isMoved
                                ? Colors.blue.shade600
                                : Colors.black,
                            decoration: skipped
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${meal.calories} Calories, fat ${meal.fatGrams}g, '
                          'protein ${meal.proteinGrams}g and carbohydrates ${meal.carbGrams}g',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: skipped
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                        if (meal.isSwapped) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF27A768,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Swapped',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF27A768),
                              ),
                            ),
                          ),
                        ],
                        if (meal.isMoved) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Moved',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (skipped)
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF27A768),
                      size: 20,
                    ),
                ],
              ),
              if (!skipped) ...[
                const SizedBox(height: 12),
                // --- Bottom action bar
                BottomActionBar(
                  skipped: skipped,
                  editable: _isEditable && !skipped,
                  onSkip: canSkip
                      ? () {
                          if (order != null) {
                            _confirmSkip(order);
                          }
                        }
                      : null,
                  onSwap: canSwap
                      ? () {
                          if (order != null) {
                            _openSwapSheet(order);
                          }
                        }
                      : null,
                  onMove: canMove
                      ? () {
                          if (order != null) {
                            _pickMoveDate(order);
                          }
                        }
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Return value from the target-order picker bottom sheet.
class _TargetOrderPick {
  final String orderId;
  _TargetOrderPick(this.orderId);
}

/// Picker shown when the target date has 2+ deliveries.
/// Lets the user choose which existing order the moved item should go into.
class _TargetOrderPickerSheet extends StatelessWidget {
  final DateTime targetDate;
  final List<OrderModel> candidates;

  const _TargetOrderPickerSheet({
    required this.targetDate,
    required this.candidates,
  });

  @override
  Widget build(BuildContext context) {
    final dateHeader = DateFormat.MMMMEEEEd().format(targetDate);
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
                const Flexible(
                  child: Text(
                    'Choose a delivery',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => Get.back<_TargetOrderPick>(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$dateHeader has ${candidates.length} deliveries — '
              'add this meal to which one?',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            ...candidates.asMap().entries.map((entry) {
              final i = entry.key;
              final order = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i == candidates.length - 1 ? 0 : 10,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Get.back<_TargetOrderPick>(
                    result: _TargetOrderPick(order.id),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.schedule_outlined,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delivery ${i + 1} · ${order.deliverySlotStart}'
                                ' – ${order.deliverySlotEnd}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${order.items.length} meal${order.items.length == 1 ? '' : 's'} · ${order.totalCalories} cal',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for swapping a specific item's meal.
class _SwapItemSheet extends GetView<ScheduleController> {
  final OrderModel order;
  final MealModel currentMeal;
  final String itemId;

  const _SwapItemSheet({
    required this.order,
    required this.currentMeal,
    required this.itemId,
  });

  @override
  Widget build(BuildContext context) {
    if (itemId.isEmpty) {
      return const Center(child: Text('Item not found'));
    }

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
                  'Swap this item',
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
              'Select a new meal for this item',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            if (currentMeal.name.isNotEmpty) ...[
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
                        'Current: ${currentMeal.name}',
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
                    final newMeal = controller.meals[index];
                    final isCurrentMeal = newMeal.name == currentMeal.name;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: isCurrentMeal
                          ? null
                          : () {
                              Get.back<void>();
                              controller.swapItem(order.id, itemId, newMeal);
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
                                  newMeal.imageUrl,
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
                                          newMeal.name,
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
                                    '${newMeal.calories} Calories, fat ${newMeal.fatGrams}g, '
                                    'protein ${newMeal.proteinGrams}g and carbohydrates ${newMeal.carbGrams}g',
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
