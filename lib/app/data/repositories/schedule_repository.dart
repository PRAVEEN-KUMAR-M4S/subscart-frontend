import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:intl/intl.dart';

import '../../modules/schedule/models/meal_model.dart';
import '../../modules/schedule/models/order_model.dart';
import '../../modules/schedule/models/subscription_model.dart';
import '../providers/schedule_api_provider.dart';

/// Data layer for the schedule module.
///
/// Talks to [ScheduleApiProvider] and wraps all failures into
/// [RepositoryException] with clear, user-friendly messages.
class ScheduleRepository extends GetxService {
  ScheduleRepository({ScheduleApiProvider? provider})
    : _provider = provider ?? ScheduleApiProvider();

  final ScheduleApiProvider _provider;

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  /// Extract the `data` field from the backend's {success, data, message}
  /// response wrapper.
  dynamic _extractData(Response<dynamic> res) {
    final body = res.data;
    if (body is Map) {
      return body['data'];
    }
    return body;
  }

  /// Normalize every [DioException] into a human-readable
  /// [RepositoryException].
  RepositoryException _wrapError(DioException e, String context) {
    print('[Repo] $context error: ${e.type} — ${e.message}');

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return RepositoryException(
          'Server is not responding. Please check that the backend '
          'is running and your device is on the same network.',
          type: RepositoryErrorType.connection,
        );

      case DioExceptionType.connectionError:
        final msg = e.message ?? '';
        if (msg.contains('Connection refused')) {
          return RepositoryException(
            'Cannot reach the server. Make sure:\n'
            '1. The backend is running (npm run dev)\n'
            '2. Your device is on the same Wi-Fi as your PC\n'
            '3. The IP address in schedule_api_provider.dart is correct',
            type: RepositoryErrorType.connection,
          );
        }
        if (msg.contains('SocketException')) {
          return RepositoryException(
            'No internet connection or server is unreachable.',
            type: RepositoryErrorType.connection,
          );
        }
        return RepositoryException(
          'Connection failed: $msg',
          type: RepositoryErrorType.connection,
        );

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode ?? 0;
        final body = e.response?.data;
        String serverMsg = '';
        if (body is Map && body['message'] != null) {
          serverMsg = body['message'].toString();
        }
        if (statusCode == 404) {
          return RepositoryException(
            serverMsg.isNotEmpty
                ? serverMsg
                : 'Resource not found. It may have been deleted.',
            type: RepositoryErrorType.notFound,
          );
        }
        if (statusCode == 400) {
          return RepositoryException(
            serverMsg.isNotEmpty
                ? serverMsg
                : 'Invalid request. Please try again.',
            type: RepositoryErrorType.validation,
          );
        }
        if (statusCode >= 500) {
          return RepositoryException(
            'Server error ($statusCode). Please try again later.',
            type: RepositoryErrorType.server,
          );
        }
        return RepositoryException(
          serverMsg.isNotEmpty ? serverMsg : 'Request failed ($statusCode).',
          type: RepositoryErrorType.server,
        );

      case DioExceptionType.cancel:
        return RepositoryException(
          'Request was cancelled.',
          type: RepositoryErrorType.connection,
        );

      default:
        return RepositoryException(
          'Something went wrong. Please check your connection and try again.',
          type: RepositoryErrorType.unknown,
        );
    }
  }

  // ------------------------------------------------------------------
  // Subscription
  // ------------------------------------------------------------------

  /// GET /subscriptions — list all subscriptions, return the first one.
  Future<SubscriptionModel> fetchFirstSubscription() async {
    print('[Repo] fetchFirstSubscription()');
    try {
      final res = await _provider.fetchSubscriptions();
      final data = _extractData(res);
      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data.containsKey('subscriptions')) {
        list = data['subscriptions'] as List<dynamic>? ?? [];
      } else {
        list = [];
      }
      print('[Repo] found ${list.length} subscriptions');
      if (list.isEmpty) {
        throw RepositoryException(
          'No subscriptions found. Please create one first.',
          type: RepositoryErrorType.notFound,
        );
      }
      return SubscriptionModel.fromJson(list.first as Map<String, dynamic>);
    } on RepositoryException {
      rethrow;
    } on DioException catch (e) {
      throw _wrapError(e, 'fetchFirstSubscription');
    }
  }

  /// GET /subscriptions/:id
  Future<SubscriptionModel> fetchSubscription(String subscriptionId) async {
    print('[Repo] fetchSubscription($subscriptionId)');
    try {
      final res = await _provider.fetchSubscription(subscriptionId);
      final data = _extractData(res);
      print('[Repo] subscription raw data: $data');
      if (data is Map && data.containsKey('subscription')) {
        return SubscriptionModel.fromJson(
          data['subscription'] as Map<String, dynamic>,
        );
      }
      return SubscriptionModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _wrapError(e, 'fetchSubscription');
    }
  }

  /// GET /subscriptions/:id/orders?date=
  Future<List<OrderModel>> fetchOrders(
    String subscriptionId, {
    DateTime? date,
  }) async {
    print('[Repo] fetchOrders($subscriptionId, date: $date)');
    try {
      final res = await _provider.fetchOrders(subscriptionId, date: date);
      final data = _extractData(res);
      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data.containsKey('orders')) {
        list = data['orders'] as List<dynamic>? ?? [];
      } else {
        list = [];
      }
      print('[Repo] parsed ${list.length} orders');
      return list
          .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _wrapError(e, 'fetchOrders');
    }
  }

  // ------------------------------------------------------------------
  // Subscription mutations
  // ------------------------------------------------------------------

  /// POST /subscriptions/:id/pause
  Future<bool> pauseSubscription(String subscriptionId) async {
    print('[Repo] pauseSubscription($subscriptionId)');
    try {
      final res = await _provider.pauseSubscription(subscriptionId);
      final data = _extractData(res);
      if (data is Map) {
        return data['status'] == 'paused' || data['isPaused'] == true;
      }
      return true;
    } on DioException catch (e) {
      throw _wrapError(e, 'pauseSubscription');
    }
  }

  /// POST /subscriptions/:id/slots
  Future<DateSlot> addSlot(String subscriptionId, DateTime date) async {
    final day = DateFormat.E().format(date);
    print('[Repo] addSlot($subscriptionId, $day)');
    try {
      await _provider.addSlot(subscriptionId, day: day);
      return DateSlot(day: day, date: date, isSelected: true);
    } on DioException catch (e) {
      throw _wrapError(e, 'addSlot');
    }
  }

  // ------------------------------------------------------------------
  // Order mutations
  // ------------------------------------------------------------------

  /// PATCH /orders/:id/skip
  Future<OrderModel> skipOrder(String orderId) async {
    print('[Repo] skipOrder($orderId)');
    try {
      final res = await _provider.skipOrder(orderId);
      final data = _extractData(res);
      if (data is Map) {
        return OrderModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw RepositoryException(
        'Unexpected server response.',
        type: RepositoryErrorType.server,
      );
    } on DioException catch (e) {
      throw _wrapError(e, 'skipOrder');
    }
  }

  /// PATCH /orders/:id/swap
  Future<OrderModel> swapMeal(String orderId, MealModel newMeal) async {
    print('[Repo] swapMeal($orderId, meal: ${newMeal.name})');
    try {
      final res = await _provider.swapOrder(
        orderId,
        name: newMeal.name,
        image: newMeal.imageUrl,
        description: newMeal.description,
      );
      final data = _extractData(res);
      if (data is Map) {
        return OrderModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw RepositoryException(
        'Unexpected server response.',
        type: RepositoryErrorType.server,
      );
    } on DioException catch (e) {
      throw _wrapError(e, 'swapMeal');
    }
  }

  /// PATCH /orders/:id/move
  /// Reschedule order to a new date, and optionally a new time slot.
  Future<OrderModel> moveOrder(
    String orderId,
    DateTime newDate, {
    String? startTime,
    String? endTime,
  }) async {
    print(
      '[Repo] moveOrder($orderId, to: $newDate, time: $startTime-$endTime)',
    );
    try {
      final res = await _provider.moveOrder(
        orderId,
        newDate,
        startTime: startTime,
        endTime: endTime,
      );
      final data = _extractData(res);
      if (data is Map) {
        return OrderModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw RepositoryException(
        'Unexpected server response.',
        type: RepositoryErrorType.server,
      );
    } on DioException catch (e) {
      throw _wrapError(e, 'moveOrder');
    }
  }

  /// PATCH /orders/:id/reschedule
  Future<OrderModel> rescheduleDeliverySlot(
    String orderId,
    String start,
    String end,
  ) async {
    print('[Repo] rescheduleDeliverySlot($orderId, $start - $end)');
    try {
      final res = await _provider.rescheduleOrder(orderId, start, end);
      final data = _extractData(res);
      if (data is Map) {
        return OrderModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw RepositoryException(
        'Unexpected server response.',
        type: RepositoryErrorType.server,
      );
    } on DioException catch (e) {
      throw _wrapError(e, 'rescheduleDeliverySlot');
    }
  }

  // ------------------------------------------------------------------
  // Per-item mutations
  // ------------------------------------------------------------------

  /// PATCH /orders/:orderId/items/:itemId/skip
  Future<OrderModel> skipItem(String orderId, String itemId) async {
    print('[Repo] skipItem($orderId, item: $itemId)');
    try {
      final res = await _provider.skipItem(orderId, itemId);
      final data = _extractData(res);
      if (data is Map) {
        return OrderModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw RepositoryException(
        'Unexpected server response.',
        type: RepositoryErrorType.server,
      );
    } on DioException catch (e) {
      throw _wrapError(e, 'skipItem');
    }
  }

  /// PATCH /orders/:orderId/items/:itemId/swap
  Future<OrderModel> swapItem(
    String orderId,
    String itemId,
    MealModel newMeal,
  ) async {
    print('[Repo] swapItem($orderId, item: $itemId, meal: ${newMeal.name})');
    try {
      final res = await _provider.swapItem(
        orderId,
        itemId,
        name: newMeal.name,
        image: newMeal.imageUrl,
        description: newMeal.description,
      );
      final data = _extractData(res);
      if (data is Map) {
        return OrderModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw RepositoryException(
        'Unexpected server response.',
        type: RepositoryErrorType.server,
      );
    } on DioException catch (e) {
      throw _wrapError(e, 'swapItem');
    }
  }

  /// PATCH /orders/:orderId/items/:itemId/move
  /// Returns `(sourceOrder, targetOrder)` after the move.
  Future<(OrderModel source, OrderModel target)> moveItem(
    String orderId,
    String itemId, {
    required String targetOrderId,
  }) async {
    print(
      '[Repo] moveItem($orderId, item: $itemId, -> target: $targetOrderId)',
    );
    try {
      final res = await _provider.moveItem(
        orderId,
        itemId,
        targetOrderId: targetOrderId,
      );
      final data = _extractData(res);
      if (data is Map) {
        final sourceRaw = data['sourceOrder'];
        final targetRaw = data['targetOrder'];
        if (sourceRaw is Map && targetRaw is Map) {
          return (
            OrderModel.fromJson(Map<String, dynamic>.from(sourceRaw)),
            OrderModel.fromJson(Map<String, dynamic>.from(targetRaw)),
          );
        }
      }
      throw RepositoryException(
        'Unexpected server response.',
        type: RepositoryErrorType.server,
      );
    } on DioException catch (e) {
      throw _wrapError(e, 'moveItem');
    }
  }

  /// POST /orders/:orderId/items - Add a new item to an order
  Future<OrderModel> addItemToOrder(String orderId, MealModel newItem) async {
    print('[Repo] addItemToOrder($orderId, item: ${newItem.name})');
    try {
      // Send 'image' (backend key) not 'imageUrl' (Flutter key)
      final payload = {
        'name': newItem.name,
        'image': newItem.imageUrl,
        'description': newItem.description,
        'quantity': newItem.quantity,
      };
      final res = await _provider.addItemToOrder(orderId, payload);
      final data = _extractData(res);
      if (data is Map) {
        return OrderModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw RepositoryException(
        'Unexpected server response.',
        type: RepositoryErrorType.server,
      );
    } on DioException catch (e) {
      throw _wrapError(e, 'addItemToOrder');
    }
  }

  // ------------------------------------------------------------------
  // Items
  // ------------------------------------------------------------------

  /// GET /items
  Future<List<MealModel>> fetchItems() async {
    print('[Repo] fetchItems()');
    try {
      final res = await _provider.fetchItems();
      final data = _extractData(res);
      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data.containsKey('items')) {
        list = data['items'] as List<dynamic>? ?? [];
      } else {
        list = [];
      }
      print('[Repo] parsed ${list.length} items');
      return list
          .map((e) => MealModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _wrapError(e, 'fetchItems');
    }
  }

  // ------------------------------------------------------------------
  // Health check
  // ------------------------------------------------------------------

  /// Check if the backend is reachable.
  Future<bool> checkHealth() => _provider.checkHealth();
}

// ------------------------------------------------------------------
// Error types for differentiated UI handling
// ------------------------------------------------------------------

enum RepositoryErrorType { connection, validation, notFound, server, unknown }

class RepositoryException implements Exception {
  final String message;
  final RepositoryErrorType type;

  RepositoryException(this.message, {this.type = RepositoryErrorType.unknown});

  @override
  String toString() => message;
}
