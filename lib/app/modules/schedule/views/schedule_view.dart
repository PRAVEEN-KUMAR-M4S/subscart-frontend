import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/schedule_controller.dart';
import 'widgets/date_pill_row.dart';
import 'widgets/subscription_actions_row.dart';
import 'widgets/order_card.dart';
import 'widgets/schedule_header.dart';

/// Subscription schedule screen — "Healthy Lab" meal plan.
class ScheduleView extends GetView<ScheduleController> {
  const ScheduleView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          // ---- Loading state (initial load) ----
          if (controller.isLoading.value &&
              controller.subscription.value == null) {
            return const _LoadingView();
          }

          // ---- Connection error state ----
          if (controller.isConnectionError.value &&
              controller.subscription.value == null) {
            return _ConnectionErrorView(
              message: controller.errorMessage.value,
              onRetry: controller.fetchSubscription,
            );
          }

          // ---- Generic error state (no data yet) ----
          if (controller.subscription.value == null &&
              controller.errorMessage.value.isNotEmpty) {
            return _ErrorView(
              message: controller.errorMessage.value,
              onRetry: controller.fetchSubscription,
            );
          }

          // ---- Normal content ----
          return RefreshIndicator(
            color: Colors.black,
            onRefresh: controller.fetchSubscription,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: const [
                ScheduleHeader(),
                SizedBox(height: 24),
                Text(
                  'Schedule',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 16),
                DatePillRow(),
                SizedBox(height: 20),
                SubscriptionActionsRow(),
                SizedBox(height: 20),
                OrderCard(),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ------------------------------------------------------------------
// Loading widget
// ------------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
          SizedBox(height: 16),
          Text(
            'Loading your meal plan…',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// Connection error — shown when the server is unreachable
// ------------------------------------------------------------------

class _ConnectionErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ConnectionErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE8E8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 36,
                color: Color(0xFFD32F2F),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Cannot reach server',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),

            // Message
            Text(
              message.isEmpty
                  ? 'Make sure your backend is running and your device '
                      'is on the same Wi-Fi network.'
                  : message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),

            // Checklist
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Checklist:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 6),
                  _CheckItem('Backend is running (npm run dev)'),
                  _CheckItem('Device is on the same Wi-Fi as your PC'),
                  _CheckItem('IP address matches in schedule_api_provider.dart'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Retry button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String text;
  const _CheckItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 14, color: Colors.black45),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// Generic error (non-connection)
// ------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.black26,
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
