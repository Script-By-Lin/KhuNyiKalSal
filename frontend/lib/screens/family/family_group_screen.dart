import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../providers/settings_provider.dart';
import '../../services/cache_service.dart';
import 'package:shimmer/shimmer.dart';

class FamilyGroupScreen extends ConsumerStatefulWidget {
  const FamilyGroupScreen({super.key});

  @override
  ConsumerState<FamilyGroupScreen> createState() => _FamilyGroupScreenState();
}

class _FamilyGroupScreenState extends ConsumerState<FamilyGroupScreen> {
  Map<String, dynamic>? _group;
  bool _loading = true;
  bool _hasGroup = false;

  final _groupNameCtrl = TextEditingController();
  final _addEmailCtrl = TextEditingController();
  String _selectedRelationship = 'Father';

  final List<String> _relationships = [
    'Father',
    'Mother',
    'Son',
    'Daughter',
    'Spouse',
    'Sibling',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadFamilyGroup();
  }

  @override
  void dispose() {
    _groupNameCtrl.dispose();
    _addEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFamilyGroup() async {
    // 1. Instantly load from cache first
    final cached = await CacheService.getFamilyGroup();
    if (cached != null && mounted) {
      setState(() {
        _group = cached;
        _hasGroup = true;
        _loading = false;
      });
    } else {
      setState(() => _loading = true);
    }

    // 2. Fetch fresh data from server in background
    try {
      final res = await ApiService().getMyFamilyGroup();
      if (mounted) {
        setState(() {
          _group = res.data;
          _hasGroup = true;
          _loading = false;
        });
      }
      // Save fresh data to cache
      await CacheService.saveFamilyGroup(res.data);
    } catch (_) {
      if (mounted && cached == null) {
        setState(() {
          _group = null;
          _hasGroup = false;
          _loading = false;
        });
      }
    }
  }

  Future<void> _createGroup() async {
    final name = _groupNameCtrl.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid family group name (min 2 chars)')),
      );
      return;
    }

    try {
      await ApiService().createFamilyGroup(name);
      _groupNameCtrl.clear();
      _loadFamilyGroup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Family Group Created Successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        final err = (e as dynamic).response?.data?['detail'] ?? 'Failed to create group';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ $err'), backgroundColor: AppTheme.primaryRed),
        );
      }
    }
  }

  void _showAddMemberDialog() {
    _addEmailCtrl.clear();
    _selectedRelationship = 'Father';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.person_add, color: AppTheme.primaryRed),
              SizedBox(width: 10),
              Text('Add Family Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your family member\'s registered email address and select their relationship to you.',
                style: TextStyle(fontSize: 13, color: AppTheme.subtleGrey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _addEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'User Email Address',
                  hintText: 'e.g. member@gmail.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _selectedRelationship,
                decoration: const InputDecoration(
                  labelText: 'Relationship Title',
                  prefixIcon: Icon(Icons.family_restroom),
                ),
                items: _relationships
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => _selectedRelationship = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
              onPressed: () async {
                final email = _addEmailCtrl.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid email address')),
                  );
                  return;
                }

                Navigator.pop(ctx);
                try {
                  await ApiService().addFamilyMember(email, _selectedRelationship);
                  _loadFamilyGroup();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added $email as $_selectedRelationship!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    final err = (e as dynamic).response?.data?['detail'] ?? 'Failed to add member';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('⚠️ $err'), backgroundColor: AppTheme.primaryRed),
                    );
                  }
                }
              },
              child: const Text('Add Member', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditGroupNameDialog() {
    final editCtrl = TextEditingController(text: _group?['group_name'] ?? '');
    final isMm = ref.read(settingsProvider).locale.languageCode == 'my';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.edit, color: AppTheme.primaryRed),
            const SizedBox(width: 10),
            Text(
              isMm ? 'အဖွဲ့ အမည် ပြင်ဆင်ရန်' : 'Edit Group Name',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMm
                  ? 'မိသားစု အဖွဲ့ အမည် အသစ်ကို ထည့်သွင်းပါ'
                  : 'Enter a new name for your family group.',
              style: const TextStyle(fontSize: 13, color: AppTheme.subtleGrey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: editCtrl,
              decoration: InputDecoration(
                labelText: isMm ? 'အဖွဲ့ အမည်' : 'Family Group Name',
                prefixIcon: const Icon(Icons.group),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isMm ? 'မလုပ်တော့ပါ' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            onPressed: () async {
              final newName = editCtrl.text.trim();
              if (newName.length < 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isMm
                        ? 'အနည်းဆုံး ၂ လုံး ရှိရပါမည်'
                        : 'Group name must be at least 2 characters'),
                  ),
                );
                return;
              }

              Navigator.pop(ctx);
              try {
                final res = await ApiService().updateFamilyGroup(newName);
                if (mounted) {
                  setState(() {
                    _group = res.data;
                  });
                }
                await CacheService.saveFamilyGroup(res.data);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isMm
                          ? 'မိသားစု အဖွဲ့ အမည် ပြင်ဆင်ပြီးပါပြီ'
                          : 'Family group updated successfully!'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  final err = (e as dynamic).response?.data?['detail'] ??
                      'Failed to update group';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('⚠️ $err'),
                      backgroundColor: AppTheme.primaryRed,
                    ),
                  );
                }
              }
            },
            child: Text(isMm ? 'သိမ်းဆည်းမည်' : 'Save',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroup() async {
    final isMm = ref.read(settingsProvider).locale.languageCode == 'my';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Text(
              isMm ? 'မိသားစု အဖွဲ့ ဖျက်မည်' : 'Delete Family Group',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          isMm
              ? 'ဤမိသားစု အဖွဲ့ကို အပြီးတိုင် ဖျက်သိမ်းရန် သေချာပါသလား? အဖွဲ့ဝင်များအားလုံး ချိတ်ဆက်မှု ပြုတ်သွားပါမည်။'
              : 'Are you sure you want to delete and disband this family group? All members will be unlinked.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isMm ? 'မလုပ်တော့ပါ' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isMm ? 'ဖျက်မည်' : 'Delete Group',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService().deleteFamilyGroup();
        await CacheService.clearFamilyGroup();
        if (mounted) {
          setState(() {
            _group = null;
            _hasGroup = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isMm
                  ? 'မိသားစု အဖွဲ့ကို ဖျက်သိမ်းပြီးပါပြီ'
                  : 'Family group deleted successfully'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final err = (e as dynamic).response?.data?['detail'] ??
              'Failed to delete group';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ $err'), backgroundColor: AppTheme.primaryRed),
          );
        }
      }
    }
  }

  Future<void> _leaveGroup() async {
    final isMm = ref.read(settingsProvider).locale.languageCode == 'my';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.exit_to_app, color: Colors.red),
            const SizedBox(width: 10),
            Text(
              isMm ? 'အဖွဲ့မှ ထွက်မည်' : 'Leave Family Group',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          isMm
              ? 'ဤမိသားစု အဖွဲ့မှ ထွက်ရန် သေချာပါသလား? အဖွဲ့၏ အရေးပေါ် SOS အချက်ပြမှုများကို လက်ခံရရှိတော့မည် မဟုတ်ပါ။'
              : 'Are you sure you want to leave this family group? You will no longer receive emergency alerts from this group.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isMm ? 'မလုပ်တော့ပါ' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isMm ? 'ထွက်မည်' : 'Leave Group',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService().leaveFamilyGroup();
        await CacheService.clearFamilyGroup();
        if (mounted) {
          setState(() {
            _group = null;
            _hasGroup = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isMm
                  ? 'မိသားစု အဖွဲ့မှ ထွက်ခွာပြီးပါပြီ'
                  : 'You have left the family group successfully'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final err = (e as dynamic).response?.data?['detail'] ??
              'Failed to leave group';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ $err'), backgroundColor: AppTheme.primaryRed),
          );
        }
      }
    }
  }

  Future<void> _removeMember(String memberId, String memberName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Family Member'),
        content: Text('Are you sure you want to remove $memberName from your family group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService().removeFamilyMember(memberId);
        _loadFamilyGroup();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Removed $memberName from group')),
          );
        }
      } catch (e) {
        if (mounted) {
          final err = (e as dynamic).response?.data?['detail'] ?? 'Failed to remove member';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ $err'), backgroundColor: AppTheme.primaryRed),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';

    return Scaffold(
      appBar: AppBar(
        title: Text(isMm ? 'မိသားစု အဖွဲ့' : 'Family Group'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFamilyGroup,
          ),
        ],
      ),
      body: _loading && _group == null
          ? _buildSkeletonLoader()
          : !_hasGroup || _group == null
              ? _buildNoGroupView(isMm)
              : _buildGroupDetailsView(isMm),
    );
  }

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            itemBuilder: (_, index) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  width: double.infinity,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNoGroupView(bool isMm) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 150),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.family_restroom, size: 72, color: AppTheme.primaryRed),
          ),
          const SizedBox(height: 20),
          Text(
            isMm ? 'မိသားစု အဖွဲ့ မရှိသေးပါ' : 'No Family Group Created Yet',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isMm
                ? 'မိသားစုဝင်များကို ထည့်သွင်းပြီး အရေးပေါ် SOS အချက်ပြမှုများကို ချက်ချင်းလက်ခံရရှိရန် မိသားစု အဖွဲ့တစ်ခု ဖန်တီးပါ။'
                : 'Create a family group to link your loved ones (Father, Mother, Son, etc.) and receive instant emergency alerts when an SOS is triggered!',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.subtleGrey, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMm ? 'မိသားစု အဖွဲ့သစ် ဖန်တီးရန်' : 'Create New Family Group',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _groupNameCtrl,
                  decoration: InputDecoration(
                    labelText: isMm ? 'အဖွဲ့ အမည်' : 'Family Group Name',
                    hintText: isMm ? 'ဥပမာ - မြမြ မိသားစု' : 'e.g. My Family Group',
                    prefixIcon: const Icon(Icons.group),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                    label: Text(
                      isMm ? 'မိသားစု အဖွဲ့ ဖန်တီးမည်' : 'CREATE FAMILY GROUP',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _createGroup,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupDetailsView(bool isMm) {
    final isCreator = _group?['is_creator'] == true;
    final members = (_group?['members'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Group Header Card ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFC62828)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryRed.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isCreator ? 'ADMIN (Group Creator)' : 'MEMBER',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.people, color: Colors.white, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${members.length} Members',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _group?['group_name'] ?? 'Family Group',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isCreator)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                        tooltip: isMm ? 'အဖွဲ့ အမည် ပြင်မည်' : 'Edit Group Name',
                        onPressed: _showEditGroupNameDialog,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isCreator
                      ? 'You are the Group Admin. You can update, add/remove members, or delete the group.'
                      : 'You are a linked family member in this emergency alert circle.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Add Member Action Bar ─────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isMm ? 'မိသားစုဝင်များ' : 'Family Members',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (isCreator)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.person_add, size: 18, color: Colors.white),
                  label: Text(
                    isMm ? '+ အဖွဲ့ဝင်ထည့်မည်' : '+ Add Member',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: _showAddMemberDialog,
                ),
            ],
          ),
          if (!isCreator)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                '🔒 Only the group creator can add or remove members.',
                style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          const SizedBox(height: 14),

          // ── Members List ──────────────────────────────────────────────
          ...members.map<Widget>((m) {
            final String memberId = m['account_id'] ?? '';
            final String name = m['full_name'] ?? 'Family Member';
            final String email = m['email'] ?? '';
            final String phone = m['phone_number'] ?? '';
            final String relationship = m['relationship'] ?? 'Member';
            final bool isMemberCreator = m['is_creator'] == true;

            Color chipColor = AppTheme.primaryRed;
            if (relationship == 'Father' || relationship == 'Mother') {
              chipColor = Colors.purple;
            } else if (relationship == 'Son' || relationship == 'Daughter') {
              chipColor = Colors.blue;
            } else if (relationship == 'Spouse') {
              chipColor = Colors.pink;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: chipColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: chipColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: chipColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                relationship,
                                style: TextStyle(
                                  color: chipColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(fontSize: 12, color: AppTheme.subtleGrey),
                        ),
                        if (phone.isNotEmpty)
                          Text(
                            phone,
                            style: const TextStyle(fontSize: 12, color: AppTheme.subtleGrey),
                          ),
                      ],
                    ),
                  ),
                  if (isMemberCreator)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Admin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  else if (isCreator)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      tooltip: 'Remove Member',
                      onPressed: () => _removeMember(memberId, name),
                    ),
                ],
              ),
            );
          }),

          const SizedBox(height: 24),

          // ── Group Management Options (Leave / Delete) ─────────────────
          if (isCreator)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.admin_panel_settings, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isMm ? 'အဖွဲ့ စီမံခန့်ခွဲမှု' : 'Danger Zone',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isMm
                        ? 'မိသားစု အဖွဲ့ကို ဖျက်သိမ်းပါက အဖွဲ့ဝင်အားလုံး ချိတ်ဆက်မှု ပျက်ပြယ်သွားပါမည်။'
                        : 'Disbanding this family group will unlink all members and stop all emergency circle notifications.',
                    style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.delete_forever, size: 20),
                      label: Text(
                        isMm ? 'မိသားစု အဖွဲ့ ဖျက်သိမ်းမည်' : 'Delete & Disband Family Group',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _deleteGroup,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.exit_to_app, color: Colors.red),
                label: Text(
                  isMm ? 'မိသားစု အဖွဲ့မှ ထွက်မည်' : 'Leave Family Group',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: _leaveGroup,
              ),
            ),
        ],
      ),
    );
  }
}
