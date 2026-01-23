import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'home_screen.dart'; // Убедитесь, что этот импорт правильный

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({Key? key}) : super(key: key);

  void _selectLanguage(BuildContext context, Locale locale) async {
    await context.setLocale(locale);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Используем голубой цвет фона, как на примере
    return Scaffold(
      backgroundColor: const Color(0xFF40B3D1),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              // Белая карточка с закругленными углами
              margin: const EdgeInsets.all(24.0),
              padding: const EdgeInsets.all(32.0),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 229, 238, 239),
                borderRadius: BorderRadius.circular(30.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Заголовок
                  const Text(
                    'Выберите язык',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                    textAlign: TextAlign.center,
                  ).tr(), // .tr() для перевода, если нужно
                  const SizedBox(height: 10),
                  // Подсказка
                  Text(
                    'Вы можете изменить это позже в настройках',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ).tr(), // .tr() для перевода, если нужно
                  const SizedBox(height: 40),

                  // Кнопка для Кыргызского языка
                  _buildLanguageButton(
                    context,
                    languageName: 'Кыргызча',

                    flagAsset: 'assets/images/flag_ky.png', 
                    locale: const Locale('ky'),
                  ),
                  const SizedBox(height: 20),

                  // Кнопка для Русского языка
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
    );
  }

  // Метод для создания стилизованной кнопки выбора языка
  Widget _buildLanguageButton(
    BuildContext context, {
    required String languageName,
    required String flagAsset,
    required Locale locale,
  }) {
    return InkWell(
      onTap: () {
        _selectLanguage(context, locale);
      },
      borderRadius: BorderRadius.circular(30.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30.0),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Круглый флаг
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.transparent,
              // Убедитесь, что у вас есть эти изображения в assets
              backgroundImage: AssetImage(flagAsset), 
            ),
            const SizedBox(width: 20),
            // Название языка
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