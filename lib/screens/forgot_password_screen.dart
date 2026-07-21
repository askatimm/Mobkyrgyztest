import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home_screen.dart';
import '../services/auth_service.dart';
import '../services/premium_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthService _authService = AuthService();
  late final TextEditingController _emailController;

  bool _isSending = false;
  bool _isGoogleLoading = false;

  bool get _isBusy => _isSending || _isGoogleLoading;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('reset_password_email_required'.tr());
      return;
    }

    setState(() => _isSending = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      _showMessage('reset_password_sent'.tr());
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'invalid-email' => 'reset_password_email_invalid'.tr(),
        'too-many-requests' => 'reset_password_too_many_requests'.tr(),
        _ => 'reset_password_error'.tr(),
      };

      if (mounted) {
        _showMessage(message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      await _authService.signInWithGoogle();
      await PremiumService.syncUserWithRevenueCat();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('login_seen', true);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (_) {
      if (mounted) {
        _showMessage('google_login_error'.tr());
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF8EC4FF), Color(0xFFEAF4FF)],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Image.asset(
              'assets/images/login_landscape.png',
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.02),
                  Colors.white.withValues(alpha: 0.12),
                ],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 36,
                    ),
                    child: Column(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _GlassIconButton(
                              icon: Icons.arrow_back_rounded,
                              onPressed: _isBusy
                                  ? null
                                  : () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: _GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const _MailIllustration(),
                                const SizedBox(height: 24),
                                Text(
                                  'reset_password_title'.tr(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    height: 1.15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF171C26),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'reset_password_subtitle'.tr(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.45,
                                    color: const Color(
                                      0xFF3D4A5C,
                                    ).withValues(alpha: 0.78),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                TextField(
                                  controller: _emailController,
                                  enabled: !_isBusy,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: _isBusy
                                      ? null
                                      : (_) => _sendResetLink(),
                                  decoration: InputDecoration(
                                    hintText: 'reset_email_hint'.tr(),
                                    hintStyle: TextStyle(
                                      color: const Color(
                                        0xFF59677A,
                                      ).withValues(alpha: 0.65),
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.mail_outline_rounded,
                                      color: Color(0xFF59677A),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withValues(
                                      alpha: 0.28,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 19,
                                      horizontal: 18,
                                    ),
                                    border: _fieldBorder(Colors.white),
                                    enabledBorder: _fieldBorder(
                                      Colors.white.withValues(alpha: 0.68),
                                    ),
                                    focusedBorder: _fieldBorder(
                                      const Color(0xFF2F7DF6),
                                      width: 1.7,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _GradientButton(
                                  isLoading: _isSending,
                                  onPressed: _isBusy ? null : _sendResetLink,
                                  icon: Icons.send_rounded,
                                  label: 'send_reset_link'.tr(),
                                ),
                                const SizedBox(height: 24),
                                _DividerLabel(label: 'reset_or'.tr()),
                                const SizedBox(height: 20),
                                _GoogleButton(
                                  isLoading: _isGoogleLoading,
                                  onPressed: _isBusy ? null : _loginWithGoogle,
                                ),
                                const SizedBox(height: 22),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: Icon(
                                        Icons.lock_outline_rounded,
                                        size: 20,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'reset_social_note'.tr(),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.45,
                                          color: Color(0xFF5F6D80),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton.icon(
                          onPressed: _isBusy
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 19),
                          label: Text('reset_back_to_login'.tr()),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF2F7DF6),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(30, 34, 30, 28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.72),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.10),
                blurRadius: 34,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.20),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon),
            color: Colors.white,
            tooltip: 'back_button'.tr(),
          ),
        ),
      ),
    );
  }
}

class _MailIllustration extends StatelessWidget {
  const _MailIllustration();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 132,
        height: 132,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.65),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF60A5FA).withValues(alpha: 0.24),
              blurRadius: 30,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.mark_email_unread_rounded,
              size: 72,
              color: Color(0xFF4F8DF7),
            ),
            Positioned(
              right: 24,
              bottom: 24,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF377DF1),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.isLoading,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final bool isLoading;
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled
            ? const LinearGradient(
                colors: [Color(0xFF4B94FF), Color(0xFF2E6FF2)],
              )
            : LinearGradient(
                colors: [
                  const Color(0xFF4B94FF).withValues(alpha: 0.45),
                  const Color(0xFF2E6FF2).withValues(alpha: 0.45),
                ],
              ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: const Color(0xFF2E6FF2).withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: SizedBox(
        height: 56,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : Icon(icon, color: Colors.white, size: 20),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFC8D6E8))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF6B7788), fontSize: 13),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFC8D6E8))),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Image.asset(
                'assets/images/google_logo.png',
                width: 22,
                height: 22,
              ),
        label: Text('reset_google_login'.tr()),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF202733),
          backgroundColor: Colors.white.withValues(alpha: 0.72),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.80)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
