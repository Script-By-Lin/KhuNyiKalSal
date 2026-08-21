import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../providers/settings_provider.dart';
import '../../utils/date_formatter.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  List<Map<String, dynamic>> _announcements = [];
  bool _loading = true;
  String _selectedCategory = 'ALL';

  final List<String> _categories = [
    'ALL',
    'Urgent',
    'Weather/Disaster',
    'Blood Drive',
    'Donation & Mission',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().getAnnouncements(
        category: _selectedCategory == 'ALL' ? null : _selectedCategory,
      );
      if (mounted) {
        setState(() {
          _announcements = List<Map<String, dynamic>>.from(res.data);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showDetailModal(Map<String, dynamic> item, bool isMm) {
    final title = item['title'] ?? '';
    final content = item['content'] ?? '';
    final category = item['category'] ?? 'General';
    final author = item['author_name'] ?? 'Command Center';
    final date = AppDateFormatter.formatDateTime(item['created_at']);
    final isPinned = item['is_pinned'] == true;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : Colors.grey.shade700;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isPinned) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.push_pin, color: isDark ? Colors.amber : Colors.amber.shade900, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'PINNED',
                            style: TextStyle(
                              color: isDark ? Colors.amber : Colors.amber.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(category).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getCategoryDisplayName(category, isMm).toUpperCase(),
                      style: TextStyle(
                        color: _getCategoryColor(category),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.3, color: textPrimary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.admin_panel_settings_outlined, size: 16, color: textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    author,
                    style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.calendar_today_outlined, size: 14, color: textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    date,
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
              const SizedBox(height: 16),
              Text(
                content,
                style: TextStyle(fontSize: 14, height: 1.6, color: textSecondary),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'urgent':
        return AppTheme.primaryRed;
      case 'weather/disaster':
        return Colors.blue.shade600;
      case 'blood drive':
        return Colors.redAccent;
      case 'donation & mission':
      case 'donation':
      case 'our mission':
        return Colors.purple.shade600;
      default:
        return Colors.teal;
    }
  }

  String _getCategoryDisplayName(String cat, bool isMm) {
    if (!isMm) return cat;
    switch (cat.toLowerCase()) {
      case 'all':
        return 'အားလုံး';
      case 'urgent':
        return 'အရေးပေါ် သတိပေးချက်';
      case 'weather/disaster':
        return 'ရာသီဥတု / သဘာဝဘေး';
      case 'blood drive':
        return 'သွေးလှူဒါန်းပွဲ';
      case 'donation & mission':
      case 'donation':
      case 'our mission':
        return 'လှူဒါန်းမှုနှင့် ကယ်ဆယ်ရေး';
      case 'general':
        return 'အထွေထွေ သတင်း';
      default:
        return cat;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final chipBg = isDark ? const Color(0xFF1E293B) : Colors.grey.shade100;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : Colors.grey.shade600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isMm ? 'သတင်းနှင့် ထုတ်ပြန်ချက်များ' : 'Announcements & News',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAnnouncements,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Category Filter Bar ─────────────────────────────────
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final cat = _categories[i];
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(
                    _getCategoryDisplayName(cat, isMm),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      fontSize: 12,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryRed,
                  backgroundColor: chipBg,
                  side: BorderSide(color: isSelected ? AppTheme.primaryRed : cardBorder),
                  showCheckmark: false,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = cat);
                      _fetchAnnouncements();
                    }
                  },
                );
              },
            ),
          ),

          // ── Announcements List ──────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
                : _announcements.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.campaign_outlined, size: 56, color: isDark ? Colors.white24 : Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              isMm ? 'ထုတ်ပြန်ချက်အသစ် မရှိသေးပါ' : 'No announcements available',
                              style: TextStyle(color: textSecondary, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchAnnouncements,
                        color: AppTheme.primaryRed,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                          itemCount: _announcements.length,
                          itemBuilder: (ctx, i) {
                            final item = _announcements[i];
                            final title = item['title'] ?? '';
                            final content = item['content'] ?? '';
                            final category = item['category'] ?? 'General';
                            final date = AppDateFormatter.formatDateTime(item['created_at']);
                            final isPinned = item['is_pinned'] == true;
                            final catColor = _getCategoryColor(category);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isPinned ? (isDark ? Colors.amber.shade700 : Colors.amber.shade300) : cardBorder,
                                  width: isPinned ? 1.5 : 1,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showDetailModal(item, isMm),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          if (isPinned) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.push_pin, color: isDark ? Colors.amber : Colors.amber.shade900, size: 12),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    'PINNED',
                                                    style: TextStyle(
                                                      color: isDark ? Colors.amber : Colors.amber.shade900,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 9,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: catColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              category.toUpperCase(),
                                              style: TextStyle(
                                                color: catColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 9,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            date,
                                            style: TextStyle(fontSize: 11, color: textSecondary),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          height: 1.3,
                                          color: textPrimary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        content,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: textSecondary,
                                          height: 1.4,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            isMm ? 'အပြည့်အစုံဖတ်ရန်' : 'Read Full',
                                            style: const TextStyle(
                                              color: AppTheme.primaryRed,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Icon(Icons.chevron_right, color: AppTheme.primaryRed, size: 16),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
