import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'quiz_instructions_screen.dart'; // Проверь путь к файлу

class VolumeBackButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;

  const VolumeBackButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  State<VolumeBackButton> createState() => _VolumeBackButtonState();
}

class _VolumeBackButtonState extends State<VolumeBackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 52,
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF7BC94D), // светлый верх
              Color(0xFF4E8F2F), // тёмный низ
            ],
          ),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.text.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.3,
          ),
        ),
      ),
    );
  }
}

class LevelDetailScreen extends StatelessWidget {
  final String levelId;

  const LevelDetailScreen({super.key, required this.levelId});

  String _backgroundForLevel() {
    // Картинки берем из локальных ассетов
    switch (levelId) {
      case 'level_a1':
        return 'assets/images/a1.png';
      default:
        return 'assets/images/a1.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // 🔹 ФОН ИЗ ASSETS
          Positioned.fill(
            child: Image.asset(_backgroundForLevel(), fit: BoxFit.cover),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 6),
                Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14), 
                  ),
                  child: Text(
                    '${levelId}_title'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                ),

                Expanded(
                  child: Align(
                    alignment: Alignment(0, 0.3), // ⬅ можно менять!
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              // Внутри Column в LevelDetailScreen
                              children: [
                                _menuItem(
                                  Icons.menu_book,
                                  'lex_grammar',
                                  context,
                                  'lexica_grammatica',
                                  'lex_gram_instructions',
                                ),

                                _menuItem(
                                  Icons.headphones,
                                  'listening',
                                  context,
                                  'listening',
                                  'listening_instructions',
                                ),

                                _menuItem(
                                  Icons.book,
                                  'reading',
                                  context,
                                  'reading',
                                  'reading_instructions',
                                ),

                                _menuItem(
                                  Icons.chat_bubble_outline,
                                  'speaking',
                                  context,
                                  'speaking', // с пробелом в конце
                                  'speaking_instructions',
                                ),

                                _menuItem(
                                  Icons.edit,
                                  'writing',
                                  context,
                                  'writing',
                                  'writing_instructions',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 🔹 КНОПКА "АРТКА"
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 30,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: VolumeBackButton(
                      text: 'back_button'.tr(),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Общий метод для кнопок меню
  Widget _menuItem(
    IconData icon,
    String textKey,
    BuildContext context,
    String subTestId,
    String instrKey,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.green[700], size: 26),
        title: Text(
          textKey.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () {
          // ПЕРЕХОДИМ СРАЗУ В ИНСТРУКЦИИ
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuizInstructionsScreen(
                levelId: levelId,
                subTestId: subTestId,
                subTestTitle: textKey.tr(),
                instructionKey: instrKey, // Используем ключ из твоего JSON
              ),
            ),
          );
        },
      ),
    );
  }
}
