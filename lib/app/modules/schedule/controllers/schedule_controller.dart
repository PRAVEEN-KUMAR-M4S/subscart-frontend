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

  /// Raw GET /meals result used by the swap bottom sheet.
  final RxList<MealModel> meals = <MealModel>[].obs;

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
  bool isOrderEditable(OrderModel? order) {
    if (order == null) return false;
    final until = _parseTimeOfDay(order.editableUntil);
    if (until == null) return true;
    final now = DateTime.now();
    final cutoff =
        DateTime(now.year, now.month, now.day, until.hour, until.minute);
    return now.isBefore(cutoff);
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
      isConnectionError.value =
          error.type == RepositoryErrorType.connection;
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

  /// GET /subscriptions/:id (+ orders for the selected day, + GET /meals).
  Future<void> fetchSubscription() async {
    isLoading.value = true;
    errorMessage.value = '';
    isConnectionError.value = false;
    try {
      final sub = await _repository.fetchSubscription('sub_001');
      subscription.value = sub;

      // Keep the initially-selected day from the payload if present.
      final initialIndex =
          sub.scheduleDays.indexWhere((d) => d.isSelected);
      selectedDateIndex.value = initialIndex >= 0 ? initialIndex : 0;

      await Future.wait([
        _loadOrdersForSelection(),
        _loadMeals(),
      ]);
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
      subscription.value?.id ?? 'sub_001',
      date: date,
    );
    orders.assignAll(list);
    selectedOrder.value = list.isNotEmpty ? list.first : null;
  }

  Future<void> _loadMeals() async {
    if (meals.isNotEmpty) return;
    try {
      meals.assignAll(await _repository.fetchMeals());
    } on RepositoryException catch (e) {
      // Meals are non-critical; log but don't block the UI
      print('[Controller] meals load failed (non-critical): ${e.message}');
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
      final alreadyExists =
          sub.scheduleDays.any((d) => _sameDay(d.date, slot.date));
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

  /// Date picker result (restricted to schedule days) lands here.
  Future<void> moveOrder(String orderId, DateTime newDate) async {
    await _mutateOrder('move', () async {
      final updated = await _repository.moveOrder(orderId, newDate);
      final replaced = _replaceOrder(updated);

      // Keep day pills in sync: highlight the day the order moved to.
      final days = subscription.value?.scheduleDays ?? const <DateSlot>[];
      final targetIndex =
          days.indexWhere((d) => _sameDay(d.date, newDate));
      if (targetIndex >= 0) {
        selectedDateIndex.value = targetIndex;
        subscription.value = subscription.value?.copyWith(
          scheduleDays: days
              .asMap()
              .entries
              .map((e) => e.value.copyWith(isSelected: e.key == targetIndex))
              .toList(),
        );
      }
      return replaced;
    });
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
    await _mutateOrder('reschedule', () async {
      final updated =
          await _repository.rescheduleDeliverySlot(orderId, start, end);
      return _replaceOrder(updated);
    });
  }

  /// Builds the start/end strings for the delivery slot picker.
  Future<void> pickAndRescheduleDeliverySlot(String orderId) async {
    final order = orders.firstWhereOrNull((o) => o.id == orderId);
    if (order == null) return;

    final initial = _parseTimeOfDay(order.deliverySlotStart) ??
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
    final formats = [
      'h:mm a',
      'hh:mm a',
      'H:mm',
      'HH:mm',
    ];
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
}
