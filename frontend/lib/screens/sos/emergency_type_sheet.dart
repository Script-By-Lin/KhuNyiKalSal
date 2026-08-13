import 'package:flutter/material.dart';
import '../../config/theme.dart';

class EmergencyTypeSheet extends StatelessWidget {
  final void Function(String type) onTypeSelected;

  const EmergencyTypeSheet({super.key, required this.onTypeSelected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24), // Reduced bottom padding since SafeArea handles it
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Select Emergency Type',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose the type of emergency you are experiencing',
              style: TextStyle(color: AppTheme.subtleGrey, fontSize: 13),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _TypeButton(
                    icon: Icons.local_fire_department,
                    label: 'Fire',
                    color: const Color(0xFFFF6B35),
                    onTap: () => onTypeSelected('fire'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _TypeButton(
                    icon: Icons.medical_services,
                    label: 'Medical',
                    color: AppTheme.primaryRed,
                    onTap: () => onTypeSelected('medical'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _TypeButton(
                    icon: Icons.shield,
                    label: 'Crime',
                    color: const Color(0xFF5C6BC0),
                    onTap: () => onTypeSelected('crime'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
