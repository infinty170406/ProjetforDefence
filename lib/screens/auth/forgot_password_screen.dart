import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService().sendPasswordResetEmail(email);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text('Email Sent', style: TextStyle(color: Colors.white)),
            content: const Text(
              'A password reset link has been sent to your email address.',
              style: TextStyle(color: AppColors.textGray400),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/login');
                },
                child: const Text('Back to Login', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
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
            child: Padding(
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
                    'Reset Password',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Enter your email to receive a reset link.',
                    style: TextStyle(
                      color: AppColors.textGray400,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 48),
                  CustomTextField(
                    controller: _emailController,
                    hint: 'Email',
                    prefixIcon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 32),
                  CustomButton(
                    text: 'Send link',
                    isLoading: _isLoading,
                    onPressed: _handleReset,
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
