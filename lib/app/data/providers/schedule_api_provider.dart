import 'package:dio/dio.dart';

/// REST provider for the schedule module.
///
/// Wraps every call in try/catch at the repository level; here we just
/// perform the raw network calls with Dio.
class ScheduleApiProvider {
  // ---------------------------------------------------------------
  // Configure this to your machine's local network IP.
  // Physical device: use your PC's Wi-Fi/LAN IP (e.g. 192.168.1.41).
  // Android emulator: use 10.0.2.2.
  // iOS simulator / web: use localhost.
  //
  // Your PC's Wi-Fi IP: 192.168.1.41
  // ---------------------------------------------------------------
  static const String baseUrl = 'http://192.168.1.41:3000/api';

  final Dio _dio;

  ScheduleApiProvider({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
            ),
          );

  /// GET /subscriptions — list all subscriptions
  Future<Response<dynamic>> fetchSubscriptions() async {
    return _dio.get('/subscriptions');
  }

  /// GET /subscriptions/:id
  Future<Response<dynamic>> fetchSubscription(String subscriptionId) async {
    return _dio.get('/subscriptions/$subscriptionId');
  }

  /// GET /subscriptions/:id/orders?date=
  Future<Response<dynamic>> fetchOrders(
    String subscriptionId, {
    DateTime? date,
  }) async {
    return _dio.get(
      '/subscriptions/$subscriptionId/orders',
      queryParameters: {if (date != null) 'date': date.toIso8601String()},
    );
  }

  /// POST /subscriptions/:id/pause
  Future<Response<dynamic>> pauseSubscription(String subscriptionId) async {
    return _dio.post('/subscriptions/$subscriptionId/pause');
  }

  /// POST /subscriptions/:id/slots
  Future<Response<dynamic>> addSlot(
    String subscriptionId, {
    required String day,
    String startTime = '8:00 am',
    String endTime = '9:00 am',
    String editableUntil = '7:00 am',
  }) async {
    return _dio.post(
      '/subscriptions/$subscriptionId/slots',
      data: {
        'day': day,
        'startTime': startTime,
        'endTime': endTime,
        'editableUntil': editableUntil,
      },
    );
  }

  /// PATCH /orders/:id/skip
  Future<Response<dynamic>> skipOrder(String orderId) async {
    return _dio.patch('/orders/$orderId/skip');
  }

  /// PATCH /orders/:id/swap
  /// Backend expects [newMeal] as a full meal object.
  Future<Response<dynamic>> swapOrder(
    String orderId, {
    required String name,
    String? image,
    int? calories,
    int? fat,
    int? protein,
    int? carbs,
  }) async {
    return _dio.patch(
      '/orders/$orderId/swap',
      data: {
        'newMeal': {
          'name': name,
          if (image != null) 'image': image,
          if (calories != null) 'calories': calories,
          if (fat != null) 'fat': fat,
          if (protein != null) 'protein': protein,
          if (carbs != null) 'carbs': carbs,
        },
      },
    );
  }

  /// PATCH /orders/:id/move
  Future<Response<dynamic>> moveOrder(String orderId, DateTime newDate) async {
    return _dio.patch(
      '/orders/$orderId/move',
      data: {'newDate': newDate.toIso8601String()},
    );
  }

  /// PATCH /orders/:id/reschedule
  Future<Response<dynamic>> rescheduleOrder(
    String orderId,
    String start,
    String end,
  ) async {
    return _dio.patch(
      '/orders/$orderId/reschedule',
      data: {'startTime': start, 'endTime': end},
    );
  }

  // ------------------------------------------------------------------
  // Per-item actions
  // ------------------------------------------------------------------

  /// PATCH /orders/:orderId/items/:itemId/skip
  Future<Response<dynamic>> skipItem(String orderId, String itemId) async {
    return _dio.patch('/orders/$orderId/items/$itemId/skip');
  }

  /// PATCH /orders/:orderId/items/:itemId/swap
  Future<Response<dynamic>> swapItem(
    String orderId,
    String itemId, {
    required String name,
    String? image,
    int? calories,
    int? fat,
    int? protein,
    int? carbs,
  }) async {
    return _dio.patch(
      '/orders/$orderId/items/$itemId/swap',
      data: {
        'newMeal': {
          'name': name,
          if (image != null) 'image': image,
          if (calories != null) 'calories': calories,
          if (fat != null) 'fat': fat,
          if (protein != null) 'protein': protein,
          if (carbs != null) 'carbs': carbs,
        },
      },
    );
  }

  /// PATCH /orders/:orderId/items/:itemId/move
  Future<Response<dynamic>> moveItem(
    String orderId,
    String itemId,
    DateTime newDate,
  ) async {
    return _dio.patch(
      '/orders/$orderId/items/$itemId/move',
      data: {'newDate': newDate.toIso8601String()},
    );
  }

  /// POST /orders/:orderId/items - Add a new item to an order
  Future<Response<dynamic>> addItemToOrder(
    String orderId,
    Map<String, dynamic> itemData,
  ) async {
    return _dio.post(
      '/orders/$orderId/items',
      data: itemData,
    );
  }

  /// GET /meals
  Future<Response<dynamic>> fetchMeals() async {
    return _dio.get('/meals');
  }

  /// Simple connectivity check — GET / (health check endpoint).
  Future<bool> checkHealth() async {
    try {
      final response = await _dio.get('/');
      return response.statusCode == 200;
    } on DioException {
      return false;
    }
  }
}
