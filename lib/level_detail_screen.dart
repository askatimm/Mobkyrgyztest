import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'task_widgets/level_a1_tasks.dart';
import 'task_widgets/level_a2_tasks.dart';
import 'task_widgets/level_b1_tasks.dart';
import 'task_widgets/level_b2_tasks.dart';
import 'task_widgets/level_c1_tasks.dart';

class LevelDetailScreen extends StatelessWidget {
  final String levelId;

  const LevelDetailScreen({Key? key, required this.levelId}) : super(key: key);

  Widget _buildLevelContent(Map<String, dynamic> data) {
    // 4. ❗ ИЗВЛЕКАЕМ URL ИЗ ДАННЫХ
    final String imageUrl = data['imageUrl'] ?? ''; // ?? '' для безопасности
    switch (levelId) {
      case 'level_a1':
        return LevelA1Tasks(imageUrl: imageUrl, levelId: levelId);
      case 'level_a2':
        return LevelA2Tasks(imageUrl: imageUrl, levelId: levelId);
      case 'level_b1':
        return LevelB1Tasks(imageUrl: imageUrl, levelId: levelId);
      case 'level_b2':
        return LevelB2Tasks(imageUrl: imageUrl, levelId: levelId);
      case 'level_c1':
        return LevelC1Tasks(imageUrl: imageUrl, levelId: levelId);
      default:
        return const Center(child: Text('Ошибка: Уровень не найден'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(levelId.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('levels')
            .doc(levelId)
            .get(),
        builder:
            (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Что-то пошло не так.'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: Text('Документ не найден.'));
              }

              final Map<String, dynamic> data =
                  (snapshot.data!.data() as Map<String, dynamic>?) ?? {};

              return Column(
                children: [
                  Expanded(child: _buildLevelContent(data)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 50.0),
                    child: SizedBox(
                      width: double.infinity, // Во всю ширину
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                            255,
                            125,
                            197,
                            92,
                          ),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          // Функция "Назад"
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          "back_button".tr(),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
      ),
    );
  }
}
