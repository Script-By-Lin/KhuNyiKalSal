import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/offline_first_aid_data.dart';
import '../../providers/settings_provider.dart';
import '../../services/sms_dispatch_service.dart';
import '../../config/theme.dart';

class OfflineFirstAidScreen extends ConsumerStatefulWidget {
  const OfflineFirstAidScreen({super.key});

  @override
  ConsumerState<OfflineFirstAidScreen> createState() =>
      _OfflineFirstAidScreenState();
}

class _OfflineFirstAidScreenState extends ConsumerState<OfflineFirstAidScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';
    final guides = OfflineFirstAidData.guides.where((g) {
      final matchesCat =
          _selectedCategory == 'All' || g.category == _selectedCategory;
      final matchesQuery = _searchQuery.isEmpty ||
          g.titleMm.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          g.titleEn.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesQuery;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isMm ? 'အော့ဖ်လိုင်း ရှေးဦးပြုစုနည်းများ' : 'Offline First-Aid Guides',
        ),
      ),
      body: Column(
        children: [
          // ── Search & Filter Bar ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: isMm
                        ? 'ရှေးဦးပြုစုနည်းများ ရှာဖွေရန်...'
                        : 'Search emergency protocols...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', isMm ? 'အားလုံး' : 'All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Medical', isMm ? 'ဆေးဘက်ဆိုင်ရာ' : 'Medical'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Fire', isMm ? 'မီးဘေး' : 'Fire'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Disaster', isMm ? 'သဘာဝဘေး' : 'Disaster'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Emergency Hotlines Bar ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.red.shade50,
            child: Row(
              children: [
                const Icon(Icons.phone_in_talk, color: AppTheme.primaryRed, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isMm ? 'အရေးပေါ် ဖုန်းနံပါတ်များ:' : 'Emergency Hotlines:',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.primaryRed,
                    ),
                  ),
                ),
                _buildQuickCallChip('191', '191'),
                const SizedBox(width: 6),
                _buildQuickCallChip('192', '192'),
                const SizedBox(width: 6),
                _buildQuickCallChip('199', '199'),
              ],
            ),
          ),

          // ── Guides List ────────────────────────────────────────────────
          Expanded(
            child: guides.isEmpty
                ? Center(
                    child: Text(
                      isMm
                          ? 'ရှာဖွေမှုရလဒ် မရှိပါ'
                          : 'No matching first-aid guides found',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: guides.length,
                    itemBuilder: (context, index) {
                      final item = guides[index];
                      return _buildGuideCard(item, isMm);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String cat, String label) {
    final isSelected = _selectedCategory == cat;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
      selected: isSelected,
      selectedColor: AppTheme.primaryRed,
      backgroundColor: Colors.white,
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedCategory = cat;
          });
        }
      },
    );
  }

  Widget _buildQuickCallChip(String number, String label) {
    return InkWell(
      onTap: () => SMSDispatchService.makePhoneCall(number),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primaryRed,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.call, color: Colors.white, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideCard(FirstAidGuideItem item, bool isMm) {
    final title = isMm ? item.titleMm : item.titleEn;
    final steps = isMm ? item.stepsMm : item.stepsEn;
    final cautions = isMm ? item.cautionsMm : item.cautionsEn;

    IconData iconData = Icons.medical_services_outlined;
    if (item.category == 'Fire') {
      iconData = Icons.local_fire_department_outlined;
    } else if (item.category == 'Disaster') {
      iconData = Icons.shield_outlined;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(iconData, color: AppTheme.primaryRed, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            item.category,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  isMm ? 'လုပ်ဆောင်ရန် အဆင့်များ:' : 'Step-by-Step Instructions:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...steps.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      s,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ),
                if (cautions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: cautions
                          .map(
                            (c) => Text(
                              c,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
