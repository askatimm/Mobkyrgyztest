import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

// 💡 Маленький класс для хранения данных о результате
class ResultData {
  final String imagePath;
  final String messageKey;
  final Color color;

  ResultData({
    required this.imagePath,
    required this.messageKey,
    required this.color,
  });
}

class QuizResultScreen extends StatelessWidget {
  final int score;
  final int totalQuestions;

  const QuizResultScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
  });

  // 💡 Эта функция определяет, что показывать,
  //    основываясь на проценте
  ResultData _getResultData() {
    double percentage = (score / totalQuestions) * 100;

    if (percentage <= 40) {
      return ResultData(
        imagePath: 'assets/images/results_bad.png',
        messageKey: 'results_bad_message',
        color: Colors.red.shade700,
      );
    } else if (percentage <= 80) {
      return ResultData(
        imagePath: 'assets/images/results_good.png',
        messageKey: 'results_good_message',
        color: Colors.orange.shade700,
      );
    } else {
      return ResultData(
        imagePath: 'assets/images/results_excellent.png',
        messageKey: 'results_excellent_message',
        color: Colors.green.shade700,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultData = _getResultData();
    final int incorrectAnswers = totalQuestions - score;

    return Scaffold(
      appBar: AppBar(
        title: Text('results_title'.tr()),
        centerTitle: true,
        automaticallyImplyLeading: false, // Убираем кнопку "назад"
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Изображение
              Image.asset(
                resultData.imagePath,
                height: 200, // 👈 Укажите нужный размер
              ),
              const SizedBox(height: 32),

              // 2. Блок с текстом и результатами
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Текст (Плохо, Хорошо, Отлично)
                    Text(
                      resultData.messageKey.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    // Статистика (как на вашем фото)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Туура жооп:
                        Column(
                          children: [
                            Text(
                              'results_correct'.tr(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$score',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        // Туура эмес жооп:
                        Column(
                          children: [
                            Text(
                              'results_incorrect'.tr(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$incorrectAnswers',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(), // Занимает все свободное место
              // 3. Кнопка "Закрыть"
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    // 💡 Возвращаемся на экран со списком тестов (Level...Tasks)
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'results_close_button'.tr(),
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
