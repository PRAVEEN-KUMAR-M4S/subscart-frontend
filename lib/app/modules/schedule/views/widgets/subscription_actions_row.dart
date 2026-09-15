import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/schedule_controller.dart';

/// "Pause Subscription" + "+ Add Slots" buttons with helper caption below.
class SubscriptionActionsRow extends GetView<ScheduleController> {
  const SubscriptionActionsRow({super.key});

  Future<void> _confirmPause(BuildContext context) async {
    final pause = !(controller.subscription.value?.isPaused ?? false);
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text(pause ? 'Pause subscription?' : 'Resume subscription?'),
        content: Text(
          pause
              ? 'Your weekly meals will be put on hold until you resume.'
              : 'Deliveries will continue as planned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back<bool>(result: true),
            child: Text(
              pause ? 'Pause' : 'Resume',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.togglePauseSubscription();
    }
  }

  Future<void> _pickAddSlotDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: Get.context!,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked != null) {
      await controller.addSlot(DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // Pause Subscription — outlined
            Expanded(
              child: Obx(() {
                final paused = controller.isPaused;
                return OutlinedButton.icon(
                  onPressed:
                      controller.isMutating.value ? null : () => _confirmPause(context),
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                  label: Text(
                    paused ? 'Paused' : 'Pause Subscription',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                );
              }),
            ),
            const SizedBox(width: 12),
            // + Add Slots — filled black
            Expanded(
              child: Obx(() {
                return ElevatedButton.icon(
                  onPressed:
                      controller.isMutating.value ? null : _pickAddSlotDate,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Add Slots',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Helper caption
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline,
                size: 14, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text(
              'Drag items between slots to reorganize',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ),
      ],
    );
  }
}
