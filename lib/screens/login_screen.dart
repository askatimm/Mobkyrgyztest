import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

import '../home_screen.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _goToHome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('login_seen', true);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _loginWithEmail() async {
    try {
      setState(() => _isLoading = true);

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await _goToHome();
    } on FirebaseAuthException catch (e) {
      String message = 'Кирүү мүмкүн болгон жок';

      if (e.code == 'user-not-found') {
        message = 'Мындай аккаунт табылган жок';
      } else if (e.code == 'invalid-credential') {
        message = 'Email же пароль туура эмес';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    try {
      setState(() => _isLoading = true);

      await _authService.signInWithGoogle();
      await _goToHome();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google аркылуу кирүү мүмкүн болгон жок')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithApple() async {
    try {
      setState(() => _isLoading = true);

      await _authService.signInWithApple();
      await _goToHome();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apple аркылуу кирүү мүмкүн болгон жок')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.20),
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFB8D9FF), Color(0xFFF5F7FB)],
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

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.school_rounded,
                            size: 80,
                            color: Color(0xFF3B82F6),
                          ),
                          const SizedBox(height: 20),

                          Text(
                            'welcome'.tr(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            'enter_personal_info'.tr(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black54,
                            ),
                          ),

                          const SizedBox(height: 28),

                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration(
                              hint: 'email'.tr(),
                              icon: Icons.email_outlined,
                            ),
                          ),

                          const SizedBox(height: 16),

                          TextField(
                            controller: passwordController,
                            obscureText: _obscurePassword,
                            decoration: _inputDecoration(
                              hint: 'password'.tr(),
                              icon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _loginWithEmail,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B82F6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text(
                                      'Кирүү',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'no_account'.tr(),
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  fontSize: 14,
                                ),
                              ),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const RegisterScreen(),
                                          ),
                                        );
                                      },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'register_now'.tr(),
                                  style: const TextStyle(
                                    color: Color(0xFF3B82F6),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  context.locale.languageCode == 'ky'
                                      ? "же"
                                      : "или",
                                ),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),

                          const SizedBox(height: 16),

                          Center(
                            child: InkWell(
                              onTap: _isLoading ? null : _loginWithGoogle,
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: const Center(
                                  child: Image(
                                    image: AssetImage(
                                      'assets/images/google_logo.png',
                                    ),
                                    width: 28,
                                    height: 28,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          if (_authService.canUseAppleSignIn)
                            SizedBox(
                              height: 56,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _loginWithApple,
                                icon: const Icon(Icons.apple),
                                label: const Text('Apple аркылуу кирүү'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.black87,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.25),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
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
