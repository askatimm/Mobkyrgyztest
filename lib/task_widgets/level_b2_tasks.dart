import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 1. Импортируйте Firestore
import '../widgets/sub_test_button.dart';
import '../quiz_instructions_screen.dart'; // 👈 2. Импортируйте экран ИНСТРУКЦИЙ

class LevelB2Tasks extends StatelessWidget {
  final String imageUrl;
  final String levelId;

  // 3. ❗ Конструктор принимает levelId
  LevelB2Tasks({super.key, required this.imageUrl, required this.levelId});

  @override
  Widget build(BuildContext context) {
    // 4. ❗ ВЕСЬ build МЕТОД ЗАМЕНЕН
    return Column(
      // Оборачиваем в Column
      children: [
        // --- 1. Ваша картинка (остается как была) ---
        Container(
          height: 200,
          width: 350,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder:
                  (
                    BuildContext context,
                    Widget child,
                    ImageChunkEvent? loadingProgress,
                  ) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // --- 2. Список кнопок из Firebase ---
        Expanded(
          // 👈 Занимает оставшееся место
          child: StreamBuilder<QuerySnapshot>(
            // 5. ❗ Загружаем подтесты для этого levelId
            stream: FirebaseFirestore.instance
                .collection('levels')
                .doc(levelId) // 'level_a1'
                .collection('sub_tests')
                .snapshots(),

            builder:
                (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Ошибка загрузки тестов'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // 6. ❗ Строим список кнопок
                  return ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 16.0,
                    ),
                    children: snapshot.data!.docs.map((
                      DocumentSnapshot document,
                    ) {
                      Map<String, dynamic> data =
                          document.data()! as Map<String, dynamic>;

                      // 7. ❗ ВОТ ГДЕ СОЗДАЮТСЯ ПЕРЕМЕННЫЕ
                      String subTestId = document.id; // 'lexica_grammatica'
                      String title =
                          data['title'] ??
                          (data['title_key']?.toString().tr() ?? 'Ошибка');
                      String instructionKey =
                          data['instruction_key'] ?? 'lex_gram_instructions';    

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: SubTestButton(
                          title: title, // 👈 Используем 'title'
                          onTap: () {
                            // 8. ❗ ПЕРЕДАЕМ 'title' И 'subTestId'
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => QuizInstructionsScreen(
                                  levelId: levelId,
                                  subTestId: subTestId,
                                  subTestTitle: title,
                                  instructionKey: instructionKey,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
          ),
        ),
      ],
    );
  }
}
