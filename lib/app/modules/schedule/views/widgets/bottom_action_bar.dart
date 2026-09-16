import 'package:flutter/material.dart';

/// Bottom row of the order card: Skip / Swap / Move buttons.
class BottomActionBar extends StatelessWidget {
  final bool skipped;
  final bool editable;
  final VoidCallback? onSkip;
  final VoidCallback? onSwap;
  final VoidCallback? onMove;

  const BottomActionBar({
    super.key,
    required this.skipped,
    required this.editable,
    required this.onSkip,
    required this.onSwap,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: skipped ? Icons.undo : Icons.skip_next,
              label: skipped ? 'Un-skip' : 'Skip',
              onTap: onSkip,
            ),
          ),
          Expanded(
            child: _ActionButton(
              icon: Icons.swap_horiz,
              label: 'Swap',
              onTap: onSwap,
            ),
          ),
          Expanded(
            child: _ActionButton(
              icon: Icons.open_in_new,
              label: 'Move',
              onTap: onMove,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
