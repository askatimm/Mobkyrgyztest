import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kyrgyztestapp/language_selection_screen.dart';
import 'package:kyrgyztestapp/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startSplash();
  }

  Future<void> _startSplash() async {
    // Ждем 3 секунды
    await Future.delayed(const Duration(seconds: 3));

    final prefs = await SharedPreferences.getInstance();
    final bool isLanguageSelected =
        prefs.getBool('language_selected') ?? false;

    if (!mounted) return;

    // Навигация
    if (isLanguageSelected) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const LanguageSelectionScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Используем Stack, чтобы изображение перекрыло всю площадь экрана
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/splashlogo1.png',
              // BoxFit.cover растягивает картинку так, чтобы не было пустых мест.
              // Лишние части (верх/низ или бока) будут аккуратно обрезаны 
              // в зависимости от пропорций экрана телефона.
              fit: BoxFit.cover, 
              // Центрируем, чтобы обрезка шла равномерно со всех сторон
              alignment: Alignment.center,
            ),
          ),
        ],
      ),
    );
  }
}