import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/services/api_service.dart';
import '../../core/services/notification_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() =>
      _SignupScreenState();
}

class _PasswordRule {
  final String label;
  final bool Function(String) check;
  _PasswordRule(this.label, this.check);
  bool get met => check(_currentPassword);
  static String _currentPassword = '';
}

class _SignupScreenState
    extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _nameError;
  String? _emailError;
  String? _passwordError;

  bool _isValidEmail(String email) =>
      RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
          .hasMatch(email);

  bool _isStrongPassword(String p) =>
      p.length >= 8 &&
      p.contains(RegExp(r'[A-Z]')) &&
      p.contains(RegExp(r'[a-z]')) &&
      p.contains(RegExp(r'[0-9]')) &&
      p.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=/\\]'));

  late final List<_PasswordRule> _rules = [
    _PasswordRule('At least 8 characters', (p) => p.length >= 8),
    _PasswordRule('One uppercase letter', (p) => p.contains(RegExp(r'[A-Z]'))),
    _PasswordRule('One lowercase letter', (p) => p.contains(RegExp(r'[a-z]'))),
    _PasswordRule('One number', (p) => p.contains(RegExp(r'[0-9]'))),
    _PasswordRule('One special character',
        (p) => p.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=/\\]'))),
  ];

  bool _validate() {
    setState(() {
      _nameError = null;
      _emailError = null;
      _passwordError = null;
    });
    bool valid = true;
    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'Full name required');
      valid = false;
    }
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = 'Email required');
      valid = false;
    } else if (!_isValidEmail(email)) {
      setState(() => _emailError = 'Invalid email address');
      valid = false;
    }
    final pass = _passwordController.text;
    if (pass.isEmpty) {
      setState(() => _passwordError = 'Password required');
      valid = false;
    } else if (!_isStrongPassword(pass)) {
      setState(() => _passwordError = 'Password does not meet requirements');
      valid = false;
    }
    return valid;
  }

  Future<void> _handleRegister() async {
    if (!_validate()) return;
    setState(() => _isLoading = true);
    try {
      await ApiService().registerWithEmailPassword(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );
      // SYNC PUSH TOKEN
      await NotificationService().syncToken();
      
      if (mounted) context.go('/otp-setup');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException ? e.message : e.toString()),
          backgroundColor: AppColors.statusDanger,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignUp() async {
    setState(() => _isGoogleLoading = true);
    try {
      await ApiService().signInWithGoogle();
      // SYNC PUSH TOKEN
      await NotificationService().syncToken();
      
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(e is ApiException ? e.message : 'Google sign-up failed: $e'),
          backgroundColor: AppColors.statusDanger,
        ));
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _PasswordRule._currentPassword = _passwordController.text;
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
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Create an account',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Protect your children with The Guardian.',
                      style: TextStyle(
                          color: AppColors.textGray400, fontSize: 14)),
                  const SizedBox(height: 28),

                  // Google Sign-Up
                  _buildGoogleButton(),
                  const SizedBox(height: 20),
                  _buildDivider(),
                  const SizedBox(height: 20),

                  CustomTextField(
                    controller: _nameController,
                    hint: 'Full name',
                    prefixIcon: Icons.person_outline,
                    errorText: _nameError,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _emailController,
                    hint: 'Email',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    errorText: _emailError,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _passwordController,
                    hint: 'Password',
                    prefixIcon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: _obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    onSuffixTap: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    errorText: _passwordError,
                    onChanged: (_) => setState(() {}),
                  ),
                  // Real-time password strength indicators
                  if (_passwordController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12, left: 4),
                      child: Column(
                        children: [
                          ..._rules.map((r) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                      r.met
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: r.met
                                          ? Colors.greenAccent
                                          : Colors.white38,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(r.label,
                                        style: TextStyle(
                                          color: r.met
                                              ? Colors.greenAccent
                                              : Colors.white54,
                                          fontSize: 12,
                                        )),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  const SizedBox(height: 28),
                  CustomButton(
                    text: _isLoading ? 'Creating account...' : 'Create Account',
                    onPressed: _isLoading ? null : _handleRegister,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account? ',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 14)),
                        GestureDetector(
                          onTap: () => context.go('/login'),
                          child: const Text('Login',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleButton() {
    return GestureDetector(
      onTap: _isGoogleLoading ? null : _handleGoogleSignUp,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: _isGoogleLoading
            ? const Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleLogo(),
                  const SizedBox(width: 12),
                  const Text('Sign up with Google',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.12))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('or',
              style: TextStyle(color: AppColors.textGray400, fontSize: 13)),
        ),
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.12))),
      ],
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final colors = [
      const Color(0xFF4285F4),
      const Color(0xFF34A853),
      const Color(0xFFFBBC05),
      const Color(0xFFEA4335),
    ];
    for (int i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.72),
        (i * 3.14159 / 2) - 0.3,
        3.14159 / 2 + 0.3,
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.18,
      );
    }
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(center.dx + radius * 0.7, center.dy),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = size.width * 0.18,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
