import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';


import '../../core/services/api_service.dart';

class OtpSetupScreen extends StatefulWidget {
  const OtpSetupScreen({super.key});

  @override
  State<OtpSetupScreen> createState() => _OtpSetupScreenState();
}

class _OtpSetupScreenState extends State<OtpSetupScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  Future<void> _sendOtp() async {
    try {
      await ApiService().sendOtp();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending OTP: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredCode => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_enteredCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit code')),
      );
      return;
    }
    setState(() => _isVerifying = true);
    try {
      final success = await ApiService().verifyOtp(_enteredCode);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Code vérifié ! Bienvenue sur The Guardian.'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/dashboard');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Code incorrect. Veuillez réessayer.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _goBack() {
    // Déconnecte l'utilisateur et retourne à la page de connexion
    ApiService().clearToken();
    context.go('/login');
  }

  void _onDigitEntered(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
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
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _goBack,
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.security,
                              color: AppColors.primary, size: 48),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Secure Your Account',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'A 6-digit code has been sent\nto your email address.\nEnter it to access your account.',
                          style: TextStyle(
                            color: AppColors.textGray400,
                            fontSize: 14,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Demo code display
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.email_outlined,
                            color: AppColors.primary, size: 24),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Check your inbox',
                                style: TextStyle(
                                    color: AppColors.textGray400, fontSize: 12),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Code sent to email',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _sendOtp,
                          child: const Text('Resend',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Enter the 6-digit code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (i) {
                      return SizedBox(
                        width: 46,
                        height: 58,
                        child: TextField(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.07),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppColors.primary, width: 2),
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (val) => _onDigitEntered(i, val),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _verify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50)),
                      ),
                      child: Text(
                        _isVerifying ? 'Verifying...' : 'Activate 2FA',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: _goBack,
                      child: const Text('← Back to Login',
                          style: TextStyle(color: AppColors.textGray400)),
                    ),
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
