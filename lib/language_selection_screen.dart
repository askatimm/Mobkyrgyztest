import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // 👈 1. Импортируем
import 'home_screen.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({Key? key}) : super(key: key);

  // 👇 Теперь эта функция асинхронная (async),
  //    так как смена языка требует времени
  void _selectLanguage(BuildContext context, Locale locale) async {
    // 👈 2. Используем 'context.setLocale'
    // Это изменит язык во всем приложении и сохранит выбор
    await context.setLocale(locale);

    // 3. Переходим на главный экран
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/boy_with_flags.png', height: 200),
                const SizedBox(height: 40),

                // 2. Текст (мы можем даже его перевести!)
                // Но для этого экрана оставим как есть,
                // так как пользователь еще не выбрал язык
                const Text(
                  'ТИЛДИ ТАНДАҢЫЗ / ВЫБЕРИТЕ ЯЗЫK',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 50),

                ElevatedButton(
                  // ... ваш стиль
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: const Color.fromARGB(255, 251, 173, 55),
                    shape: const StadiumBorder(),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: () {
                    // 👇 4. Передаем Locale('ky')
                    _selectLanguage(context, const Locale('ky'));
                  },
                  child: const Text('КЫРГЫЗЧА', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  // ... ваш стиль
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: const Color.fromARGB(255, 241, 246, 168),
                    shape: const StadiumBorder(),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: () {
                    // 👇 5. Передаем Locale('ru')
                    _selectLanguage(context, const Locale('ru'));
                  },
                  child: const Text('РУССКИЙ', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
