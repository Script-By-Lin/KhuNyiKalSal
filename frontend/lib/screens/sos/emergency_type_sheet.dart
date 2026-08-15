import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/settings_provider.dart';

class EmergencyTypeSheet extends ConsumerWidget {
  final void Function(String type) onTypeSelected;

  const EmergencyTypeSheet({super.key, required this.onTypeSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isMm ? 'အရေးပေါ် အမျိုးအစား ရွေးချယ်ပါ' : 'Select Emergency Type',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isMm
                  ? 'သင်ကြုံတွေ့နေရသော အရေးပေါ် အခြေအနေကို ရွေးချယ်ပေးပါ'
                  : 'Choose the type of emergency you are experiencing',
              style: const TextStyle(color: AppTheme.subtleGrey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),

            // 2x2 Grid of Emergency Types
            Row(
              children: [
                Expanded(
                  child: _TypeButton(
                    icon: Icons.local_fire_department,
                    label: isMm ? 'မီးဘေး' : 'Fire',
                    subtitle: isMm ? 'မီးလောင်မှု / ကယ်ဆယ်ရေး' : 'Fire & Rescue',
                    color: const Color(0xFFFF6B35),
                    onTap: () => onTypeSelected('fire'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TypeButton(
                    icon: Icons.medical_services,
                    label: isMm ? 'ဆေးဘက်' : 'Medical',
                    subtitle: isMm ? 'လူနာတင်ယာဉ် / ဆေးကုသမှု' : 'Ambulance & Hospital',
                    color: AppTheme.primaryRed,
                    onTap: () => onTypeSelected('medical'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TypeButton(
                    icon: Icons.car_crash_rounded,
                    label: isMm ? 'ယာဉ်မတော်တဆ' : 'Accident',
                    subtitle: isMm ? 'ယာဉ်တိုက်မှု / အရေးပေါ်' : 'Vehicle & Trauma',
                    color: const Color(0xFFE65100),
                    onTap: () => onTypeSelected('accident'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TypeButton(
                    icon: Icons.flood_rounded,
                    label: isMm ? 'သဘာဝဘေး' : 'Natural Disaster',
                    subtitle: isMm ? 'ရေဘေး / လေဘေး' : 'Flood, Storm & Relief',
                    color: const Color(0xFF00897B),
                    onTap: () => onTypeSelected('natural_disaster'),
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
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: color.withValues(alpha: 0.75),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
