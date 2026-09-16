import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/schedule_controller.dart';

/// Horizontal row of selectable day pills (day name above date number).
class DatePillRow extends GetView<ScheduleController> {
  const DatePillRow({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: Obx(() {
        final days = controller.scheduleDays;
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: days.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final slot = days[index];
            final selected = index == controller.selectedDateIndex.value;
            return _DatePill(
              day: slot.day,
              dateNumber: slot.date.day.toString(),
              selected: selected,
              onTap: () => controller.selectDate(index),
            );
          },
        );
      }),
    );
  }
}

class _DatePill extends StatelessWidget {
  final String day;
  final String dateNumber;
  final bool selected;
  final VoidCallback onTap;

  const _DatePill({
    required this.day,
    required this.dateNumber,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              day,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? scheme.primary : scheme.surface,
                border: Border.all(
                  color: selected
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.25),
                  width: 1.2,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                dateNumber,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
