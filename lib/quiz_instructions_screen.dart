import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'quiz_screen.dart'; // 👈 Импортируем экран теста

class QuizInstructionsScreen extends StatelessWidget {
  final String levelId;
  final String subTestId;
  final String subTestTitle;
  final String instructionKey;

  const QuizInstructionsScreen({
    Key? key,
    required this.levelId,
    required this.subTestId,
    required this.subTestTitle,
    required this.instructionKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 💡 Заголовок берем из названия теста
        title: Text(subTestTitle),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Занимать минимум места по центру
            children: [
              Text(
                "attention".tr(), // "Внимание!"
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                instructionKey.tr(), // "Прочитайте задание. Выберите..."
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.black54),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    // 💡 Переходим НА экран теста, ЗАМЕНЯЯ этот
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => QuizScreen(
                          levelId: levelId,
                          subTestId: subTestId,
                          subTestTitle: subTestTitle,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    "start_button".tr(), 
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
