import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/services/firestore_service.dart';

class ChildProfileCreationScreen extends StatefulWidget {
  const ChildProfileCreationScreen({super.key});

  @override
  State<ChildProfileCreationScreen> createState() =>
      _ChildProfileCreationScreenState();
}

class _ChildProfileCreationScreenState
    extends State<ChildProfileCreationScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  bool _isLoading = false;
  String _loadingMessage = 'Creating...';

  Future<void> _handleCreate() async {
    if (_nameController.text.isEmpty || _ageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final age = int.tryParse(_ageController.text);
    if (age == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid age')),
      );
      return;
    }

    // ADDED: age validation and isMinor logic
    if (age < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid age')),
      );
      return;
    }

    if (age > 21) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account creation is not possible after 21 years old.'),
          backgroundColor: AppColors.statusDanger,
        ),
      );
      return;
    }

    bool isMinor = age < 18;

    // Show confirmation for 18-21
    if (age >= 18 && age <= 21) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          
          title: Text('Confirmation', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          content: Text(
            'This child is a major (18-21 years old). Some parental restrictions will be limited. Do you want to continue?',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Continue', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Creating profile...';
    });

    try {
      final result = await FirestoreService().createChild(
        displayName: _nameController.text.trim(),
        age: age,
        isMinor: isMinor,
      );

      if (mounted) {
        _showConfigurationDialog(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.statusDanger),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = 'Creating...';
        });
      }
    }
  }

  // Post-creation bottom sheet (rich cards style)
  void _showConfigurationDialog(dynamic result) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(2))),
            SizedBox(height: 20),
            Icon(Icons.check_circle, color: Colors.greenAccent, size: 52),
            SizedBox(height: 12),
            Text('Profile Created!',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text(
              'How would you like to configure ${_nameController.text.trim()}\'s rules?',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            _configOption(
              ctx,
              Icons.auto_awesome,
              'Configure with AI',
              'Let AI suggest age-appropriate rules',
              AppColors.accentTeal,
              () {
                context.pushReplacement('/ai-hub',
                    extra: {'child': result, 'mode': 'setup'});
              },
            ),
            SizedBox(height: 10),
            _configOption(
              ctx,
              Icons.settings,
              'Configure manually',
              'Set rules step by step',
              AppColors.primary,
              () {
                context.pushReplacement('/child/config', extra: result);
              },
            ),
            SizedBox(height: 10),
            _configOption(
              ctx,
              Icons.skip_next,
              'Skip for now',
              'Configure rules later',
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
              () {
                context.pushReplacement('/child/link-gen', extra: result);
              },
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _configOption(BuildContext ctx, IconData icon, String title,
      String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 20),
          ],
        ),
      ),
    );
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
                  // SAME: close button
                  IconButton(
                    icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () => context.pop(),
                  ),
                  SizedBox(height: 24),
                  // SAME: title
                  Text(
                    'New Profile',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Add a profile for one of your children to start protecting them.",
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
                  ),
                  SizedBox(height: 40),
                  // SAME: avatar placeholder
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Icon(Icons.add_a_photo_outlined,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70), size: 32),
                    ),
                  ),
                  SizedBox(height: 40),
                  // SAME: fields
                  CustomTextField(
                    controller: _nameController,
                    hint: "Child's first name",
                    prefixIcon: Icons.child_care,
                  ),
                  SizedBox(height: 16),
                  CustomTextField(
                    controller: _ageController,
                    hint: 'Age (1-21)',
                    prefixIcon: Icons.calendar_today,
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 32),
                  // SAME: button
                  CustomButton(
                    text: _isLoading ? _loadingMessage : 'Next',
                    onPressed: _isLoading ? null : _handleCreate,
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
