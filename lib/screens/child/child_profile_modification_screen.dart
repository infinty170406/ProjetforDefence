import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';

import '../../core/services/api_service.dart';

class ChildProfileModificationScreen extends StatefulWidget {
  final dynamic child;
  const ChildProfileModificationScreen({super.key, this.child});

  @override
  State<ChildProfileModificationScreen> createState() =>
      _ChildProfileModificationScreenState();
}

class _ChildProfileModificationScreenState
    extends State<ChildProfileModificationScreen> {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.child?['displayName'] ?? '');
    _ageController =
        TextEditingController(text: widget.child?['age']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final childId = widget.child?['childId'] ?? widget.child?['id'];
    if (childId == null) return;

    setState(() => _isLoading = true);
    try {
      await ApiService().updateChild(
        childId,
        displayName: _nameController.text.trim(),
        age: int.tryParse(_ageController.text) ?? 0,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        context.pop(true); // Return true to signal refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDelete() async {
    final childId = widget.child?['childId'] ?? widget.child?['id'];
    if (childId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete profile'),
        content: const Text('Do you really want to delete this child profile?'),
        actions: [
          TextButton(
              onPressed: () => context.pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => context.pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ApiService().deleteChild(childId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile deleted')),
        );
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),
                  CustomTextField(
                    controller: _nameController,
                    hint: "Child's first name",
                    prefixIcon: Icons.child_care,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _ageController,
                    hint: 'Age',
                    prefixIcon: Icons.calendar_today,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 40),
                  CustomButton(
                    text: _isLoading
                        ? 'Saving...'
                        : 'Save changes',
                    onPressed: _isLoading ? null : _handleSave,
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: 'Delete profile',
                    onPressed: _isLoading ? null : _handleDelete,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
