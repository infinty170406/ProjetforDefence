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
  late String _selectedRelation;
  late String _selectedAvatar;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.child?['displayName'] ?? '');
    _ageController =
        TextEditingController(text: widget.child?['age']?.toString() ?? '');
    _selectedRelation = widget.child?['relation'] ?? 'Fils';
    _selectedAvatar = widget.child?['avatar'] ?? '👦';
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
        avatar: _selectedAvatar,
        relation: _selectedRelation,
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
        title: Text('Delete profile',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text('Do you really want to delete this child profile?',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(
              onPressed: () => context.pop(false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.primary))),
          TextButton(
            onPressed: () => context.pop(true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.redAccent)),
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
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back,
                        color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () => context.pop(),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  CustomTextField(
                    controller: _nameController,
                    hint: "Child's first name",
                    prefixIcon: Icons.child_care,
                  ),
                  SizedBox(height: 16),
                  CustomTextField(
                    controller: _ageController,
                    hint: 'Age',
                    prefixIcon: Icons.calendar_today,
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Lien de parenté',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ['Fils', 'Fille', 'Autre'].map((rel) {
                      final active = _selectedRelation == rel;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(rel),
                          selected: active,
                          onSelected: (val) {
                            if (val) setState(() => _selectedRelation = rel);
                          },
                          selectedColor: AppColors.primary.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: active ? AppColors.primary : Colors.grey,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Choisissez un avatar',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children:
                        ['👦', '👧', '🦖', '🦄', '🐱', '🐶'].map((avatar) {
                      final active = _selectedAvatar == avatar;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedAvatar = avatar),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primary.withOpacity(0.15)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: active
                                  ? AppColors.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Text(avatar,
                              style: const TextStyle(fontSize: 22)),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 40),
                  CustomButton(
                    text: _isLoading ? 'Saving...' : 'Save changes',
                    onPressed: _isLoading ? null : _handleSave,
                  ),
                  SizedBox(height: 16),
                  CustomButton(
                    text: 'Delete profile',
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                    textColor: Colors.redAccent,
                    isOutlined: true,
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
