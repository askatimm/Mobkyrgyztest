import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'quiz_instructions_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Проверь путь к файлу

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
        return 'assets/images/a1.webp';
      default:
        return 'assets/images/a1.webp';
    }
  }

  String _getInstructionKey(String subTestId) {
    if (subTestId == 'writing') {
      switch (levelId) {
        case 'level_b1':
          return 'writing_instruction_b1';
        case 'level_b2':
          return 'writing_instruction_b2';
        case 'level_c1':
          return 'writing_instruction_c1';
        default:
          return 'writing_instructions';
      }
    }

    switch (subTestId) {
      case 'lexica_grammatica':
        return 'lex_gram_instructions';
      case 'listening':
        return 'listening_instructions';
      case 'reading':
        return 'reading_instructions';
      case 'speaking':
        return 'speaking_instructions';
      default:
        return 'writing_instructions';
    }
  }

  Future<bool> _hasTasks(String subTestId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('levels')
        .doc(levelId)
        .collection('sub_tests')
        .doc(subTestId)
        .collection('tasks')
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
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
                                ),

                                _menuItem(
                                  Icons.headphones,
                                  'listening',
                                  context,
                                  'listening',
                                ),

                                _menuItem(
                                  Icons.book,
                                  'reading',
                                  context,
                                  'reading',
                                ),

                                _menuItem(
                                  Icons.chat_bubble_outline,
                                  'speaking',
                                  context,
                                  'speaking',
                                ),

                                _menuItem(
                                  Icons.edit,
                                  'writing',
                                  context,
                                  'writing',
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
  ) {
    return FutureBuilder<bool>(
      future: _hasTasks(subTestId),
      builder: (context, snapshot) {
        final bool isLocked = !(snapshot.data ?? false);

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isLocked ? 0.65 : 0.85),
            borderRadius: BorderRadius.circular(15),
          ),
          child: ListTile(
            leading: Icon(
              icon,
              color: isLocked ? Colors.grey : Colors.green[700],
              size: 26,
            ),
            title: Text(
              textKey.tr(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isLocked ? Colors.grey[600] : Colors.black,
              ),
            ),
            trailing: snapshot.connectionState == ConnectionState.waiting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isLocked ? Icons.lock_outline : Icons.chevron_right,
                    size: 20,
                    color: isLocked ? Colors.grey : Colors.black54,
                  ),
            onTap: isLocked
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuizInstructionsScreen(
                          levelId: levelId,
                          subTestId: subTestId,
                          subTestTitle: textKey.tr(),
                          instructionKey: _getInstructionKey(subTestId),
                        ),
                      ),
                    );
                  },
          ),
        );
      },
    );
  }
}
