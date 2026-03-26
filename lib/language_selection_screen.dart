import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  Future<void> _selectLanguage(BuildContext context, Locale locale) async {
    // 1. Устанавливаем язык
    await context.setLocale(locale);

    // 2. Сохраняем выбор
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('language_selected', true);
    await prefs.setString('language_code', locale.languageCode);

    // 3. Переход на главный экран
    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/mountain_language.webp'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                margin: const EdgeInsets.all(24.0),
                padding: const EdgeInsets.all(32.0),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 229, 238, 239)
                      .withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(30.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Выберите язык',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                      textAlign: TextAlign.center,
                    ).tr(),

                    const SizedBox(height: 10),

                    Text(
                      'Вы можете изменить это позже в настройках',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ).tr(),

                    const SizedBox(height: 40),

                    _buildLanguageButton(
                      context,
                      languageName: 'Кыргызча',
                      flagAsset: 'assets/images/flag_ky.png',
                      locale: const Locale('ky'),
                    ),

                    const SizedBox(height: 20),

                    _buildLanguageButton(
                      context,
                      languageName: 'Русский',
                      flagAsset: 'assets/images/flag_ru.png',
                      locale: const Locale('ru'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageButton(
    BuildContext context, {
    required String languageName,
    required String flagAsset,
    required Locale locale,
  }) {
    return InkWell(
      onTap: () => _selectLanguage(context, locale),
      borderRadius: BorderRadius.circular(30.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: AssetImage(flagAsset),
              backgroundColor: Colors.transparent,
            ),
            const SizedBox(width: 20),
            Text(
              languageName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
    );
  }
}