import 'package:flutter/material.dart';
import '../../config/theme.dart';

class RulesLawsScreen extends StatelessWidget {
  const RulesLawsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rules & Laws')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _RuleCard(
            icon: Icons.warning,
            title: 'False Alerts',
            body: 'Triggering false SOS alerts is a punishable offence. '
                'Users found abusing the system will be blocked and may '
                'face legal consequences.',
            color: Colors.orange,
          ),
          _RuleCard(
            icon: Icons.shield,
            title: 'Data Privacy',
            body: 'Your personal and medical information is encrypted and '
                'shared only with responding rescue teams during emergencies.',
            color: AppTheme.secondaryGreen,
          ),
          _RuleCard(
            icon: Icons.speed,
            title: 'Daily Limits',
            body: 'To prevent abuse, each user may trigger a maximum of '
                '5 SOS alerts per day. Contact support for exceptional cases.',
            color: AppTheme.primaryRed,
          ),
          _RuleCard(
            icon: Icons.people,
            title: 'Volunteer Conduct',
            body: 'Volunteers must respond promptly and professionally. '
                'Failure to follow protocols may result in removal from '
                'the organization.',
            color: Colors.blue,
          ),
          _RuleCard(
            icon: Icons.gavel,
            title: 'Legal Framework',
            body: 'This application operates under Myanmar disaster management '
                'and emergency response regulations. All parties are bound by '
                'applicable national laws.',
            color: Colors.purple,
          ),
        ],
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _RuleCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
