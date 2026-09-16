import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../services/theme_service.dart';
import '../../controllers/schedule_controller.dart';

/// Top section: back arrow, plan thumbnail and plan title/subtitle.
class ScheduleHeader extends GetView<ScheduleController> {
  const ScheduleHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Back arrow
        IconButton(
          onPressed: () => Get.back<void>(),
          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
        ),
        const SizedBox(width: 4),
        // Plan thumbnail — constant, does NOT change with the selected date
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.restaurant_menu,
            size: 22,
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 12),
        // Plan title + subtitle
        Expanded(
          child: Obx(() {
            final sub = controller.subscription.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sub?.planName ?? 'Healthy Lab...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub?.subtitle ?? '5 Meals Weekly Plan · 6-week',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            );
          }),
        ),
        const SizedBox(width: 8),
        // Overflow menu with theme toggle
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.6),
          ),
          onSelected: (value) {
            if (value == 'theme') {
              Get.find<ThemeService>().toggleTheme();
            }
          },
          itemBuilder: (context) {
            final themeService = Get.find<ThemeService>();
            return [
              PopupMenuItem<String>(
                value: 'theme',
                child: Obx(() {
                  return Row(
                    children: [
                      Icon(
                        themeService.isDarkMode.value
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        size: 20,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        themeService.isDarkMode.value
                            ? 'Light Mode'
                            : 'Dark Mode',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ];
          },
        ),
      ],
    );
  }
}
