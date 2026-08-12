import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';

class ManageVolunteersScreen extends ConsumerStatefulWidget {
  const ManageVolunteersScreen({super.key});

  @override
  ConsumerState<ManageVolunteersScreen> createState() =>
      _ManageVolunteersScreenState();
}

class _ManageVolunteersScreenState
    extends ConsumerState<ManageVolunteersScreen> {
  List<Map<String, dynamic>> _volunteers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVolunteers();
  }

  Future<void> _loadVolunteers() async {
    try {
      final res = await ApiService().listVolunteers();
      setState(() {
        _volunteers = List<Map<String, dynamic>>.from(res.data);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleStatus(String id) async {
    await ApiService().toggleVolunteerStatus(id);
    _loadVolunteers();
  }

  void _showAddDialog() {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Volunteer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(hintText: 'Full Name')),
              const SizedBox(height: 10),
              TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(hintText: 'Email')),
              const SizedBox(height: 10),
              TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(hintText: 'Password'),
                  obscureText: true),
              const SizedBox(height: 10),
              TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(hintText: 'Phone')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService().createVolunteer({
                  'email': emailCtrl.text.trim(),
                  'password': passCtrl.text,
                  'full_name': nameCtrl.text.trim(),
                  'phone_number': phoneCtrl.text.trim(),
                });
                if (!mounted) return;
                Navigator.pop(context);
                _loadVolunteers();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Volunteer added!')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to add volunteer')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Volunteers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: AppTheme.primaryRed,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Volunteer'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _volunteers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline,
                          size: 64, color: AppTheme.subtleGrey),
                      const SizedBox(height: 16),
                      Text('No volunteers yet',
                          style: TextStyle(
                              color: AppTheme.subtleGrey, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _volunteers.length,
                  itemBuilder: (_, i) {
                    final v = _volunteers[i];
                    final isActive = v['is_active'] == true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isActive
                              ? AppTheme.secondaryGreen.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: (isActive
                                      ? AppTheme.secondaryGreen
                                      : Colors.grey)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.person,
                              color: isActive
                                  ? AppTheme.secondaryGreen
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(v['full_name'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                Text(v['phone_number'] ?? '',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.subtleGrey)),
                              ],
                            ),
                          ),
                          Switch(
                            value: isActive,
                            activeThumbColor: AppTheme.secondaryGreen,
                            onChanged: (_) =>
                                _toggleStatus(v['account_id']),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
