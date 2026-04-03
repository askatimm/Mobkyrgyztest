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
  final List<Map<String, String>> writingMistakes;
  final int totalWritingGaps;
  final int correctWritingGaps;
  final bool isAdvancedWriting;

  const QuizResultScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
    this.writingMistakes = const [],
    this.totalWritingGaps = 0,
    this.correctWritingGaps = 0,
    this.isAdvancedWriting = false,
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

  ResultData _getAdvancedWritingResultData() {
    final percent = totalWritingGaps == 0
        ? 0
        : (correctWritingGaps / totalWritingGaps) * 100;

    if (percent < 40) {
      return ResultData(
        imagePath: 'assets/images/results_bad.png',
        messageKey: 'results_bad_message',
        color: Colors.red.shade700,
      );
    } else if (percent <= 80) {
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
    if (isAdvancedWriting) {
      final wrongCount = totalWritingGaps - correctWritingGaps;
      final resultData = _getAdvancedWritingResultData();

      return Scaffold(
        appBar: AppBar(
          title: Text('results_title'.tr()),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Image.asset(resultData.imagePath, height: 200),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        resultData.messageKey.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: resultData.color,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
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
                                '$correctWritingGaps',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
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
                                '$wrongCount',
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
                const SizedBox(height: 16),
                Expanded(
                  child: totalWritingGaps == 0
                      ? Center(
                          child: Text(
                            'Жооптор эсептелген жок',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        )
                      : writingMistakes.isEmpty
                      ? Center(
                          child: Text(
                            'all_answers_correct'.tr(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(top: 8),
                          itemCount: writingMistakes.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = writingMistakes[index];

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${'your_answer'.tr()}: ${item['user']}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${'correct_answer'.tr()}: ${item['correct']}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
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

    final wrongAnswers = totalQuestions - score;
    final resultData = _getResultData();

    return Scaffold(
      appBar: AppBar(
        title: Text('results_title'.tr()),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(resultData.imagePath, height: 200),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      resultData.messageKey.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: resultData.color,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
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
                              '$wrongAnswers',
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
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
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
