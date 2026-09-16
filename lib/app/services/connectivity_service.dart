import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Monitors live network connectivity status.
///
/// Exposes [isOnline] as an observable [RxBool] so any widget/controller
/// can reactively show offline banners or disable actions.
class ConnectivityService extends GetxService {
  final RxBool isOnline = true.obs;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void onInit() {
    super.onInit();
    _checkInitialStatus();
    _startListening();
  }

  /// Check the current connectivity status on startup.
  Future<void> _checkInitialStatus() async {
    final results = await Connectivity().checkConnectivity();
    isOnline.value = _hasConnection(results);
  }

  /// Listen for real-time connectivity changes.
  void _startListening() {
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final wasOnline = isOnline.value;
      final nowOnline = _hasConnection(results);

      if (wasOnline != nowOnline) {
        isOnline.value = nowOnline;

        if (nowOnline) {
          // Back online — show snackbar
          Get.snackbar(
            'Back online',
            'Your connection has been restored.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: const Color(0xFF27A768),
            colorText: Colors.white,
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 2),
            isDismissible: true,
          );
        } else {
          // Went offline — show snackbar
          Get.snackbar(
            'You\'re offline',
            'Check your internet connection.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: const Color(0xFFD32F2F),
            colorText: Colors.white,
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 3),
            isDismissible: true,
          );
        }
      }
    });
  }

  /// Returns true if any of the connectivity results indicates a connection.
  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
