import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:family_map/auth/supabase_auth_manager.dart';
import 'package:family_map/theme.dart';
import 'package:family_map/widgets/glass_panel.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _auth = SupabaseAuthManager();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;

  String _friendlyAuthError(Object e) {
    // Supabase throws AuthApiException for most auth failures.
    if (e is sb.AuthApiException) {
      final code = (e.code ?? '').toLowerCase();
      if (code == 'invalid_credentials') return 'Invalid email or password.';
      if (code == 'email_not_confirmed') return 'Please confirm your email before signing in.';
      if (code == 'user_already_exists') return 'An account already exists for that email.';
      if (code == 'over_request_rate_limit') return 'Too many attempts. Please wait a moment and try again.';
      if (code == 'signup_disabled') return 'Sign-ups are disabled for this project.';
      return e.message;
    }
    if (e is sb.AuthException) return e.message;
    if (e is sb.PostgrestException) {
      // Typically indicates an RLS/policy issue with profile tables, etc.
      return 'Signed in, but the app is blocked by a database policy (RLS). Please contact support.';
    }
    return e.toString();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email and password.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        await _auth.createAccountWithEmail(context: context, email: email, password: password);
      } else {
        await _auth.signInWithEmail(context: context, email: email, password: password);
      }
      // go_router redirect will take over.
    } catch (e) {
      debugPrint('Auth submit failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyAuthError(e))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your email first.')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _auth.resetPassword(context: context, email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent (if the account exists).')),
      );
    } catch (e) {
      debugPrint('Reset password failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyAuthError(e))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? DarkModeColors.darkSurface : LightModeColors.lightSurface;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppGradients.diamondGradient.colors.first.withValues(alpha: 0.22),
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -90,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppGradients.emeraldGradient.colors.first.withValues(alpha: 0.18),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: GlassPanel(
                    gradient: AppGradients.diamondGradient,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Family Cockpit',
                          style: context.textStyles.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isSignUp ? 'Create an account to start sharing.' : 'Sign in to start tracking.',
                          style: context.textStyles.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _ModeChip(
                                  label: 'Sign in',
                                  selected: !_isSignUp,
                                  onTap: _isLoading ? null : () => setState(() => _isSignUp = false),
                                ),
                              ),
                              Expanded(
                                child: _ModeChip(
                                  label: 'Create',
                                  selected: _isSignUp,
                                  onTap: _isLoading ? null : () => setState(() => _isSignUp = true),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _GlassTextField(
                          controller: _emailCtrl,
                          label: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        _GlassTextField(
                          controller: _passwordCtrl,
                          label: 'Password',
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.20),
                            disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
                            elevation: 0,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                                )
                              : Text(
                                  _isSignUp ? 'Create account' : 'Sign in',
                                  style: context.textStyles.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                                ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: _isLoading ? null : _resetPassword,
                              style: TextButton.styleFrom(foregroundColor: Colors.white, overlayColor: Colors.transparent),
                              child: Text(
                                'Forgot password?',
                                style: context.textStyles.labelMedium?.copyWith(color: Colors.white.withValues(alpha: 0.92)),
                              ),
                            ),
                            TextButton(
                              onPressed: _isLoading ? null : () => setState(() => _isSignUp = !_isSignUp),
                              style: TextButton.styleFrom(foregroundColor: Colors.white, overlayColor: Colors.transparent),
                              child: Text(
                                _isSignUp ? 'Have an account?' : 'Create account',
                                style: context.textStyles.labelMedium?.copyWith(color: Colors.white.withValues(alpha: 0.92)),
                              ),
                            ),
                          ],
                        ),
                        if (kIsWeb) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Tip: If email confirmations are enabled in Supabase Auth, you may need to confirm before sign-in works.',
                            style: context.textStyles.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.75), height: 1.4),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _ModeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? Colors.white.withValues(alpha: 0.22) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Center(
            child: Text(
              label,
              style: context.textStyles.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _GlassTextField({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: context.textStyles.bodyMedium?.copyWith(color: Colors.white),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: context.textStyles.labelMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.28))),
      ),
    );
  }
}
