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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.surface,
            onRefresh: controller.fetchSubscription,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const ScheduleHeader(),
                const SizedBox(height: 24),
                Text(
                  'Schedule',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color:
                        Theme.of(context).textTheme.bodyLarge?.color ??
                        Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                const DatePillRow(),
                const SizedBox(height: 20),
                const SubscriptionActionsRow(),
                const SizedBox(height: 20),
                // ---- Render ALL orders for the selected date ----
                Obx(() {
                  final list = controller.orders;
                  // Initial empty or loading state — show the empty card using
                  // the legacy single-card path (which renders the friendly
                  // "No order scheduled" message).
                  if (list.isEmpty) return const OrderCard();

                  // Render one card per order.
                  return Column(
                    children: [
                      if (list.length > 1) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Text(
                                '${list.length} deliveries on this date',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.35),
                              ),
                            ],
                          ),
                        ),
                      ],
                      ...list.asMap().entries.map(
                        (e) => Padding(
                          padding: EdgeInsets.only(
                            bottom: e.key == list.length - 1 ? 0 : 16,
                          ),
                          child: OrderCard(order: e.value),
                        ),
                      ),
                    ],
                  );
                }),
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

  const _ConnectionErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 30,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              "You're offline",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 6),

            // Friendly message
            Text(
              'Check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Retry button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
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

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
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
