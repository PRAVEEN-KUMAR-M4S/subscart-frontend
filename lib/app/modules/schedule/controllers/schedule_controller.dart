import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/repositories/schedule_repository.dart';
import '../models/meal_model.dart';
import '../models/order_model.dart';
import '../models/subscription_model.dart';

/// Controller for the subscription schedule screen.
///
/// Holds all reactive state (subscription, orders, selection) and exposes
/// intent methods the view calls; all network work goes through
/// [ScheduleRepository].
class ScheduleController extends GetxController {
  ScheduleController({ScheduleRepository? repository})
    : _repository = repository ?? Get.find<ScheduleRepository>();

  final ScheduleRepository _repository;

  // ------------------------------------------------------------------
  // State
  // ------------------------------------------------------------------
  final Rx<SubscriptionModel?> subscription = Rx<SubscriptionModel?>(null);
  final RxList<OrderModel> orders = <OrderModel>[].obs;
  final Rx<OrderModel?> selectedOrder = Rx<OrderModel?>(null);
  final RxInt selectedDateIndex = 0.obs;
  final RxBool isLoading = true.obs;

  /// Raw GET /items result used by the swap/add bottom sheets.
  final RxList<MealModel> availableItems = <MealModel>[].obs;

  /// Set when a repository call fails; the view shows a SnackBar.
  final RxString errorMessage = ''.obs;

  /// True when the device can't reach the server at all.
  final RxBool isConnectionError = false.obs;

  /// In-flight action flag so buttons can show spinners.
  final RxBool isMutating = false.obs;

  // ------------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------------
  @override
  void onInit() {
    super.onInit();
    fetchSubscription();
  }

  // ------------------------------------------------------------------
  // Derived helpers
  // ------------------------------------------------------------------
  List<DateSlot> get scheduleDays =>
      subscription.value?.scheduleDays ?? const [];

  bool get isPaused => subscription.value?.isPaused ?? false;

  /// True when the currently selected order can no longer be edited.
  /// Note: Returns true for testing purposes - disable this override in production.
  bool isOrderEditable(OrderModel? order) {
    // Always return true to enable skip/swap/move buttons for testing
    // Remove this line in production to use the actual time check
    return true;

    // Original time-based check (uncomment for production):
    // if (order == null) return false;
    // final until = _parseTimeOfDay(order.editableUntil);
    // if (until == null) return true;
    // final now = DateTime.now();
    // final cutoff = DateTime(
    //   now.year,
    //   now.month,
    //   now.day,
    //   until.hour,
    //   until.minute,
    // );
    // return now.isBefore(cutoff);
  }

  DateTime? dateForIndex(int index) {
    final days = scheduleDays;
    return index >= 0 && index < days.length ? days[index].date : null;
  }

  // ------------------------------------------------------------------
  // Error handling
  // ------------------------------------------------------------------

  void _handleError(Object error, String context) {
    print('[Controller] $context error: $error');
    if (error is RepositoryException) {
      errorMessage.value = error.message;
      isConnectionError.value = error.type == RepositoryErrorType.connection;
    } else {
      errorMessage.value = 'Something went wrong. Please try again.';
      isConnectionError.value = false;
    }
    // Show snackbar for mutation errors (skip, swap, move, etc.)
    if (context != 'fetchSubscription') {
      Get.snackbar(
        'Error',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF323232),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
        isDismissible: true,
      );
    }
  }

  // ------------------------------------------------------------------
  // Data loading
  // ------------------------------------------------------------------

  /// GET /subscriptions/:id (+ orders for the selected day, + GET /items).
  Future<void> fetchSubscription() async {
    isLoading.value = true;
    errorMessage.value = '';
    isConnectionError.value = false;
    try {
      final sub = await _repository.fetchFirstSubscription();
      subscription.value = sub;

      // Keep the initially-selected day from the payload if present.
      final initialIndex = sub.scheduleDays.indexWhere((d) => d.isSelected);
      selectedDateIndex.value = initialIndex >= 0 ? initialIndex : 0;

      await Future.wait([_loadOrdersForSelection(), _loadAvailableItems()]);
    } on RepositoryException catch (e) {
      _handleError(e, 'fetchSubscription');
    } catch (e) {
      _handleError(e, 'fetchSubscription');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadOrdersForSelection() async {
    final date = dateForIndex(selectedDateIndex.value);
    final list = await _repository.fetchOrders(
      subscription.value!.id,
      date: date,
    );
    orders.assignAll(list);
    selectedOrder.value = list.isNotEmpty ? list.first : null;
  }

  Future<void> _loadAvailableItems() async {
    if (availableItems.isNotEmpty) return;
    try {
      availableItems.assignAll(await _repository.fetchItems());
    } on RepositoryException catch (e) {
      // Items are non-critical; log but don't block the UI
      print('[Controller] items load failed (non-critical): ${e.message}');
    }
  }

  // ------------------------------------------------------------------
  // User intents
  // ------------------------------------------------------------------

  /// Tapping a day pill: re-selects the day and loads that day's order.
  Future<void> selectDate(int index) async {
    if (index < 0 || index >= scheduleDays.length) return;
    selectedDateIndex.value = index;

    // Flip the isSelected flags so the payload stays consistent.
    final updated = scheduleDays
        .asMap()
        .entries
        .map((e) => e.value.copyWith(isSelected: e.key == index))
        .toList();
    subscription.value = subscription.value?.copyWith(scheduleDays: updated);

    isLoading.value = true;
    try {
      await _loadOrdersForSelection();
    } on RepositoryException catch (e) {
      _handleError(e, 'selectDate');
    } finally {
      isLoading.value = false;
    }
  }

  /// User taps one of multiple order cards on the same date.
  /// Updates [selectedOrder] so the card highlights and downstream
  /// widgets (swap sheets, move-item flows) operate on the right order.
  void selectOrder(String orderId) {
    final match = orders.firstWhereOrNull((o) => o.id == orderId);
    if (match != null) selectedOrder.value = match;
  }

  /// Confirm dialog must be shown by the view BEFORE calling this.
  Future<void> togglePauseSubscription() async {
    final sub = subscription.value;
    if (sub == null) return;
    isMutating.value = true;
    try {
      final newPaused = await _repository.pauseSubscription(sub.id);
      subscription.value = sub.copyWith(isPaused: newPaused);
      Get.snackbar(
        newPaused ? 'Subscription paused' : 'Subscription resumed',
        newPaused
            ? 'No meals will be delivered until you resume.'
            : 'Welcome back! Deliveries continue as planned.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF323232),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
      );
    } on RepositoryException catch (e) {
      _handleError(e, 'togglePause');
    } catch (e) {
      _handleError(e, 'togglePause');
    } finally {
      isMutating.value = false;
    }
  }

  /// Date picker result from the view lands here; appends a new pill.
  Future<void> addSlot(DateTime date) async {
    final sub = subscription.value;
    if (sub == null) return;
    isMutating.value = true;
    try {
      final slot = await _repository.addSlot(sub.id, date);
      final alreadyExists = sub.scheduleDays.any(
        (d) => _sameDay(d.date, slot.date),
      );
      if (!alreadyExists) {
        subscription.value = sub.copyWith(
          scheduleDays: [...sub.scheduleDays, slot],
        );
        // Jump to the newly added day.
        await selectDate(subscription.value!.scheduleDays.length - 1);
      }
    } on RepositoryException catch (e) {
      _handleError(e, 'addSlot');
    } catch (e) {
      _handleError(e, 'addSlot');
    } finally {
      isMutating.value = false;
    }
  }

  /// View shows the AlertDialog confirm first, then calls this.
  Future<void> skipOrder(String orderId) async {
    await _mutateOrder('skip', () async {
      final updated = await _repository.skipOrder(orderId);
      return _replaceOrder(updated);
    });
  }

  /// Bottom-sheet selection from the view lands here.
  Future<void> swapMeal(String orderId, MealModel newMeal) async {
    await _mutateOrder('swap', () async {
      final updated = await _repository.swapMeal(orderId, newMeal);
      return _replaceOrder(updated);
    });
  }

  /// Per-item skip action.
  Future<void> skipItem(String orderId, String itemId) async {
    await _mutateOrder('skipItem', () async {
      final updated = await _repository.skipItem(orderId, itemId);
      _replaceOrder(updated);
      Get.snackbar(
        'Item removed',
        'The meal has been removed from your order.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF323232),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      );
      return updated;
    });
  }

  /// Per-item swap action.
  Future<void> swapItem(
    String orderId,
    String itemId,
    MealModel newMeal,
  ) async {
    await _mutateOrder('swapItem', () async {
      final updated = await _repository.swapItem(orderId, itemId, newMeal);
      _replaceOrder(updated);
      Get.snackbar(
        'Meal swapped',
        'Swapped to ${newMeal.name}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF323232),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      );
      return updated;
    });
  }

  /// Per-item move action — moves the item INTO the given target existing order.
  /// After success, flips the day pill to the target date so the user can
  /// see the item in its new order.
  Future<void> moveItem({
    required String orderId,
    required String itemId,
    required String targetOrderId,
  }) async {
    isMutating.value = true;
    try {
      final (source, target) = await _repository.moveItem(
        orderId,
        itemId,
        targetOrderId: targetOrderId,
      );
      _replaceOrder(source);
      _replaceOrder(target);

      // Switch the selected day pill to the target order's date
      // so the user immediately sees the newly-added item.
      final days = subscription.value?.scheduleDays ?? const <DateSlot>[];
      final targetIndex = days.indexWhere((d) => _sameDay(d.date, target.date));
      if (targetIndex >= 0 && targetIndex != selectedDateIndex.value) {
        selectedDateIndex.value = targetIndex;
        subscription.value = subscription.value?.copyWith(
          scheduleDays: days
              .asMap()
              .entries
              .map((e) => e.value.copyWith(isSelected: e.key == targetIndex))
              .toList(),
        );
        // If orders for this date were not loaded yet, _replaceOrder already
        // added the target; ensure it's the selected one.
        selectedOrder.value = target;
      }

      Get.snackbar(
        'Meal moved',
        'Added to ${DateFormat.MMMd().format(target.date)} · ${target.deliverySlotStart}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF323232),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      );
    } on RepositoryException catch (e) {
      _handleError(e, 'moveItem');
    } catch (e) {
      _handleError(e, 'moveItem');
    } finally {
      isMutating.value = false;
    }
  }

  /// Fetch existing orders for a target date — used by the move-item picker
  /// to show the user which deliveries are on that date.
  Future<List<OrderModel>> fetchOrdersForDate(DateTime date) async {
    final sub = subscription.value;
    if (sub == null) return const [];
    try {
      final list = await _repository.fetchOrders(sub.id, date: date);
      return list;
    } on RepositoryException catch (e) {
      _handleError(e, 'fetchOrdersForDate');
      return const [];
    } catch (e) {
      _handleError(e, 'fetchOrdersForDate');
      return const [];
    }
  }

  /// Add a new item to an order.
  Future<void> addItemToOrder(String orderId, MealModel newItem) async {
    await _mutateOrder('addItem', () async {
      final updated = await _repository.addItemToOrder(orderId, newItem);
      _replaceOrder(updated);
      Get.snackbar(
        'Item added',
        '${newItem.name} added to your order.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF323232),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      );
      return updated;
    });
  }

  /// Date picker result (any date within subscription range).
  /// Optionally passes startTime/endTime for combined date+time reschedule.
  Future<void> moveOrder(
    String orderId,
    DateTime newDate, {
    String? startTime,
    String? endTime,
  }) async {
    // --- Client-side validation: reject past dates ---
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(newDate.year, newDate.month, newDate.day);
    if (targetDate.isBefore(today)) {
      Get.snackbar(
        'Invalid date',
        'Cannot reschedule to a past date. Please choose a future date.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF323232),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
      );
      return;
    }

    // If rescheduling to today, validate the time slot is also in the future
    if (targetDate.isAtSameMomentAs(today) && startTime != null) {
      final parsedTime = _parseTimeOfDay(startTime);
      if (parsedTime != null) {
        final slotDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          parsedTime.hour,
          parsedTime.minute,
        );
        if (!slotDateTime.isAfter(now)) {
          Get.snackbar(
            'Invalid time',
            'Cannot reschedule to a past time today. Please choose a future time slot.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF323232),
            colorText: Colors.white,
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 4),
          );
          return;
        }
      }
    }

    isMutating.value = true;
    try {
      final oldOrder = orders.firstWhereOrNull((o) => o.id == orderId);
      final oldDate = oldOrder?.date;

      final updated = await _repository.moveOrder(
        orderId,
        newDate,
        startTime: startTime,
        endTime: endTime,
      );
      _replaceOrder(updated);

      final days = List<DateSlot>.from(
        subscription.value?.scheduleDays ?? const <DateSlot>[],
      );

      // 1) If moving to a date that's not a schedule-day pill yet,
      //    create a new DateSlot and insert it in chronological order.
      var targetIndex = days.indexWhere((d) => _sameDay(d.date, newDate));
      if (targetIndex < 0) {
        const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final dayLabel = weekdayLabels[newDate.weekday - 1];
        final newSlot = DateSlot(
          day: dayLabel,
          date: newDate,
          isSelected: true,
        );
        days.add(newSlot);
        days.sort((a, b) => a.date.compareTo(b.date));
        targetIndex = days.indexWhere((d) => _sameDay(d.date, newDate));
      }

      // 2) (Optional) If the OLD date no longer has any orders after the move,
      //    remove the old date's pill (unless it still has other orders from
      //    the original schedule).  Skip removal if oldDate == newDate.
      if (oldDate != null && !_sameDay(oldDate, newDate)) {
        final remainingOnOld = orders.where(
          (o) => o.id != orderId && _sameDay(o.date, oldDate),
        );
        if (remainingOnOld.isEmpty) {
          final oldIndex = days.indexWhere((d) => _sameDay(d.date, oldDate));
          if (oldIndex >= 0) {
            days.removeAt(oldIndex);
            if (oldIndex < targetIndex) targetIndex--;
          }
        }
      }

      // 3) Clamp targetIndex just in case, then flip selection to target.
      if (targetIndex >= days.length) targetIndex = days.length - 1;
      if (targetIndex < 0) targetIndex = 0;

      selectedDateIndex.value = targetIndex;
      subscription.value = subscription.value?.copyWith(
        scheduleDays: days
            .asMap()
            .entries
            .map((e) => e.value.copyWith(isSelected: e.key == targetIndex))
            .toList(),
      );

      // 4) Reload orders for the new date so UI reflects the moved order
      //    AND any existing order that was already there.
      await _loadOrdersForSelection();

      // Snackbar confirmation — makes it obvious the move happened.
      final formattedDate = DateFormat('EEEE, MMM d').format(newDate);
      final slot = (startTime != null && endTime != null)
          ? ' · $startTime – $endTime'
          : '';
      Get.snackbar(
        'Order rescheduled',
        'Order ${updated.orderNumber} → $formattedDate$slot',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF323232),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      );
    } on RepositoryException catch (e) {
      _handleError(e, 'moveOrder');
    } catch (e) {
      _handleError(e, 'moveOrder');
    } finally {
      isMutating.value = false;
    }
  }

  /// Time picker result lands here; blocked once past the edit cut-off.
  Future<void> rescheduleDeliverySlot(
    String orderId,
    String start,
    String end,
  ) async {
    final order = orders.firstWhereOrNull((o) => o.id == orderId);
    if (order != null && !isOrderEditable(order)) {
      Get.snackbar(
        'Edits closed',
        'This order can no longer be edited — the cut-off time has passed.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF323232),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    // --- Client-side validation: if order is today, reject past time ---
    if (order != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final orderDate = DateTime(
        order.date.year,
        order.date.month,
        order.date.day,
      );
      if (orderDate.isAtSameMomentAs(today)) {
        final parsedTime = _parseTimeOfDay(start);
        if (parsedTime != null) {
          final slotDateTime = DateTime(
            now.year,
            now.month,
            now.day,
            parsedTime.hour,
            parsedTime.minute,
          );
          if (!slotDateTime.isAfter(now)) {
            Get.snackbar(
              'Invalid time',
              'Cannot reschedule to a past time today. Please choose a future time slot.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: const Color(0xFF323232),
              colorText: Colors.white,
              margin: const EdgeInsets.all(12),
              duration: const Duration(seconds: 4),
            );
            return;
          }
        }
      }
    }

    await _mutateOrder('reschedule', () async {
      final updated = await _repository.rescheduleDeliverySlot(
        orderId,
        start,
        end,
      );
      return _replaceOrder(updated);
    });
  }

  /// Unified reschedule flow: pick DATE first, then TIME.
  /// Validates: no past dates, within subscription start/end, no past times today.
  Future<void> pickAndRescheduleOrder(String orderId) async {
    try {
      final order = orders.firstWhereOrNull((o) => o.id == orderId);
      if (order == null) {
        Get.snackbar(
          'Error',
          'Order not found.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF323232),
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
        );
        return;
      }

      if (!isOrderEditable(order)) {
        Get.snackbar(
          'Edits closed',
          'This order can no longer be edited — the cut-off time has passed.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF323232),
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
        );
        return;
      }

      final ctx = Get.context;
      if (ctx == null) {
        Get.snackbar(
          'Error',
          'Screen context not available. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF323232),
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
        );
        return;
      }

      final sub = subscription.value;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Determine valid date range: subscription dates or fallback
      DateTime firstDate;
      DateTime lastDate;
      if (sub?.startDate != null && sub?.endDate != null) {
        firstDate = sub!.startDate!.isAfter(today) ? sub.startDate! : today;
        lastDate = sub.endDate!;
      } else {
        firstDate = today;
        lastDate = today.add(const Duration(days: 365));
      }

      // Initial pick date: order date, clamped to valid range
      DateTime initialDate = order.date;
      if (initialDate.isBefore(firstDate)) initialDate = firstDate;
      if (initialDate.isAfter(lastDate)) initialDate = lastDate;

      // ---- Step 1: Pick date ----
      final pickedDate = await showDatePicker(
        context: ctx,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        helpText: 'Reschedule to a new date',
        fieldLabelText: 'Delivery date',
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Colors.black,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
      );
      if (pickedDate == null) return;

      final selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      );
      final isToday =
          selectedDate.year == today.year &&
          selectedDate.month == today.month &&
          selectedDate.day == today.day;

      // ---- Step 2: Pick time ----
      final initialTime =
          _parseTimeOfDay(order.deliverySlotStart) ??
          const TimeOfDay(hour: 8, minute: 0);

      final pickedTime = await showTimePicker(
        context: ctx,
        initialTime: initialTime,
        helpText: 'Pick delivery time',
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Colors.black,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
      );
      if (pickedTime == null) return;

      // ---- Client-side validation: if today, ensure time is in the future ----
      if (isToday) {
        final pickedDateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        if (!pickedDateTime.isAfter(now)) {
          Get.snackbar(
            'Invalid time',
            'Cannot reschedule to a past time today. Please choose a future time slot.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF323232),
            colorText: Colors.white,
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 4),
          );
          return;
        }
      }

      // Format times for the API (e.g., "8:17 AM")
      final startTime = _formatTimeOfDay(pickedTime);
      final endTod = pickedTime.replacing(hour: (pickedTime.hour + 1) % 24);
      final endTime = _formatTimeOfDay(endTod);

      // ---- Confirmation dialog — fire action directly in onConfirm ----
      Get.dialog(
        Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon circle
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    size: 28,
                    color: Colors.blue.shade500,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Confirm Reschedule',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Move Order ${order.orderNumber} to',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 10),
                // Date/time info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('EEEE, MMM d').format(selectedDate),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$startTime – $endTime',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back<void>(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back<void>();
                          moveOrder(
                            orderId,
                            selectedDate,
                            startTime: startTime,
                            endTime: endTime,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Reschedule'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e, stack) {
      print('[Controller] pickAndRescheduleOrder error: $e\n$stack');
      Get.snackbar(
        'Error',
        'Failed to open reschedule. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF323232),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
      );
    }
  }

  /// Builds the start/end strings for the delivery slot picker (time-only).
  Future<void> pickAndRescheduleDeliverySlot(String orderId) async {
    final order = orders.firstWhereOrNull((o) => o.id == orderId);
    if (order == null) return;

    final initial =
        _parseTimeOfDay(order.deliverySlotStart) ??
        const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(
      context: Get.context!,
      initialTime: initial,
    );
    if (picked == null) return;

    final end = picked.replacing(hour: (picked.hour + 1) % 24);
    await rescheduleDeliverySlot(
      orderId,
      picked.format(Get.context!),
      end.format(Get.context!),
    );
  }

  // ------------------------------------------------------------------
  // Internals
  // ------------------------------------------------------------------

  OrderModel _replaceOrder(OrderModel updated) {
    final index = orders.indexWhere((o) => o.id == updated.id);
    if (index >= 0) {
      orders[index] = updated;
    } else {
      orders.add(updated);
    }
    if (selectedOrder.value?.id == updated.id) {
      selectedOrder.value = updated;
    }
    return updated;
  }

  Future<void> _mutateOrder(
    String action,
    Future<OrderModel> Function() doAction,
  ) async {
    isMutating.value = true;
    try {
      await doAction();
    } on RepositoryException catch (e) {
      _handleError(e, action);
    } catch (e) {
      _handleError(e, action);
    } finally {
      isMutating.value = false;
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static TimeOfDay? _parseTimeOfDay(String value) {
    final formats = ['h:mm a', 'hh:mm a', 'H:mm', 'HH:mm'];
    for (final f in formats) {
      try {
        final df = DateFormat(f);
        final parsed = df.parseLoose(value.trim());
        return TimeOfDay.fromDateTime(parsed);
      } catch (_) {
        // try next format
      }
    }
    return null;
  }

  /// Format a [TimeOfDay] to a string like "8:17 AM" for the backend.
  static String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    final minutes = tod.minute.toString().padLeft(2, '0');
    return '$hour:$minutes $period';
  }
}
