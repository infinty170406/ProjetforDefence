import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/services/api_service.dart';
import '../../core/services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;

  bool _isValidEmail(String email) =>
      RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
          .hasMatch(email);

  bool _validate() {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });
    bool valid = true;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty) {
      setState(() => _emailError = 'Email required');
      valid = false;
    } else if (!_isValidEmail(email)) {
      setState(() => _emailError = 'Invalid email address');
      valid = false;
    }
    if (password.isEmpty) {
      setState(() => _passwordError = 'Password required');
      valid = false;
    }
    return valid;
  }

  Future<void> _handleLogin() async {
    if (!_validate()) return;
    setState(() => _isLoading = true);
    try {
      await ApiService().loginWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      // SYNC PUSH TOKEN
      await NotificationService().syncToken();
      
      if (mounted) context.go('/dashboard');
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

  Future<void> _handleGoogleSignIn() async {
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
              Text(e is ApiException ? e.message : 'Google Sign-In failed: $e'),
          backgroundColor: AppColors.statusDanger,
        ));
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 48),
                  Text('Login',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 40,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Happy to see you again.',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 18)),
                  SizedBox(height: 40),
                  _buildGoogleButton(),
                  SizedBox(height: 20),
                  _buildDivider(),
                  SizedBox(height: 20),
                  CustomTextField(
                    controller: _emailController,
                    hint: 'Email',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    errorText: _emailError,
                  ),
                  SizedBox(height: 16),
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
                  ),
                  SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: Text('Forgot password?',
                          style: TextStyle(color: AppColors.primary)),
                    ),
                  ),
                  SizedBox(height: 12),
                  CustomButton(
                    text: _isLoading ? 'Logging in...' : 'Login',
                    onPressed: _isLoading ? null : _handleLogin,
                  ),
                  SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? ",
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70))),
                      GestureDetector(
                        onTap: () => context.push('/signup'),
                        child: Text('Sign Up',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Center(
                    child: TextButton.icon(
                      icon: Icon(Icons.phonelink_setup, size: 16),
                      label: Text('Setup child device'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60),
                      ),
                      onPressed: () => context.push('/child/pair'),
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

  Widget _buildGoogleButton() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return GestureDetector(
      onTap: _isGoogleLoading ? null : _handleGoogleSignIn,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isLight ? Colors.white.withValues(alpha: 0.92) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isLight ? const Color(0xFFCBD5E1) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)),
          boxShadow: isLight ? [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.08), blurRadius: 8, offset: Offset(0, 2))] : [],
        ),
        child: _isGoogleLoading
            ? Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Theme.of(context).colorScheme.onSurface)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleLogo(),
                  SizedBox(width: 12),
                  Text('Continue with Google',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
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
        Expanded(child: Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('or',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
        ),
        Expanded(child: Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12))),
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
      decoration: BoxDecoration(shape: BoxShape.circle),
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
          ..strokeWidth = size.width * 0.18);
  }

  @override
  bool shouldRepaint(_) => false;
}
