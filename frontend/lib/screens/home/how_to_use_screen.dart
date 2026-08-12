import 'package:flutter/material.dart';
import '../../config/theme.dart';

class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How to Use')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          _Step(
            number: '1',
            title: 'Register Your Account',
            description:
                'Create an account with your personal and medical information. '
                'This helps rescue teams assist you faster.',
            icon: Icons.person_add,
          ),
          _Step(
            number: '2',
            title: 'Open the Map',
            description:
                'Navigate to the Map tab to see your location and nearby rescue organizations.',
            icon: Icons.map,
          ),
          _Step(
            number: '3',
            title: 'Press & Hold SOS',
            description:
                'In an emergency, press and hold the red SOS button for 3 seconds. '
                'This prevents accidental triggers.',
            icon: Icons.touch_app,
          ),
          _Step(
            number: '4',
            title: 'Select Emergency Type',
            description:
                'Choose Fire, Medical, or Crime. '
                'The system will alert the nearest relevant organization.',
            icon: Icons.warning_amber,
          ),
          _Step(
            number: '5',
            title: 'Wait for Response',
            description:
                'A volunteer will accept your alert. You\'ll see '
                '"Help is on the way!" when someone responds. '
                'If nobody responds, the system automatically tries the next organization.',
            icon: Icons.notifications_active,
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final IconData icon;

  const _Step({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: AppTheme.primaryRed,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: AppTheme.primaryRed),
                    const SizedBox(width: 6),
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppTheme.subtleGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
