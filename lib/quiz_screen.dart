import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:just_audio/just_audio.dart';
import 'quiz_result_screen.dart';

// --- Модель QuizTask (без изменений) ---
class QuizTask {
  final String id;
  final String? text;
  final String? audioUrl;
  final String? sentence;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;

  QuizTask({
    required this.id,
    this.text,
    this.audioUrl,
    this.sentence,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
  });

  factory QuizTask.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    try {
      return QuizTask(
        id: doc.id,
        text: data['text'],
        audioUrl: data['audioUrl'],
        sentence: data['sentence'],
        question: data['question'] ?? 'Вопрос не найден',
        options: List<String>.from(data['options'] ?? []),
        correctAnswerIndex: data['correctAnswerIndex'] ?? 0,
      );
    } catch (e) {
      print("💥 ОШИБКА ПРЕОБРАЗОВАНИЯ (Serialization Error):");
      print("   Не удалось обработать документ с ID: ${doc.id}");
      print("   Причина: $e");
      print("   Данные документа: $data");
      rethrow;
    }
  }
}

// --- Экран (без изменений) ---
class QuizScreen extends StatefulWidget {
  final String levelId;
  final String subTestId;
  final String subTestTitle;

  const QuizScreen({
    Key? key,
    required this.levelId,
    required this.subTestId,
    required this.subTestTitle,
  }) : super(key: key);

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

// --- Состояние (без изменений) ---
class _QuizScreenState extends State<QuizScreen> {
  late Future<List<QuizTask>> _tasksFuture;
  List<QuizTask> _tasks = [];

  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSubscription;
  String? _currentlyLoadedAudioUrl;

  bool _isPlayerLoading = false;
  bool _isPlaying = false;
  int _currentIndex = 0;
  int _score = 0;

  int? _selectedAnswerIndex;
  bool _isMcqAnswered = false;

  List<String> _wordBank = [];
  List<String> _assembledWords = [];
  String _correctFirstWord = "";
  bool _isSentenceAnswered = false;

  @override
  void initState() {
    super.initState();
    print("--- Загрузка QuizScreen ---");
    print("   Level ID: ${widget.levelId}");
    print("   SubTest ID: ${widget.subTestId}");

    _tasksFuture = _loadTasks().then((loadedTasks) {
      if (mounted) {
        _prepareCurrentTask();
      }
      return loadedTasks;
    });

    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _audioPlayer.pause();
            _audioPlayer.seek(Duration.zero);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<List<QuizTask>> _loadTasks() async {
    final path = 'levels/${widget.levelId}/sub_tests/${widget.subTestId}/tasks';
    print("   Запрос в Firebase по пути: $path");

    try {
      final snapshot = await FirebaseFirestore.instance.collection(path).get();

      if (snapshot.docs.isEmpty) {
        print("   Результат: Успешно, но 0 документов (коллекция пуста).");
      } else {
        print(
          "   Результат: Успешно, найдено ${snapshot.docs.length} документов.",
        );
      }

      _tasks = snapshot.docs.map((doc) => QuizTask.fromFirestore(doc)).toList();
      _tasks.shuffle();
      return _tasks;
    } catch (e) {
      print("🛑 КРИТИЧЕСКАЯ ОШИБКА (Firebase/Network Error):");
      print("   Не удалось выполнить .get() запрос.");
      print("   Причина: $e");
      rethrow;
    }
  }

  void _prepareCurrentTask() {
    if (_tasks.isEmpty) return;
    final task = _tasks[_currentIndex];
    _selectedAnswerIndex = null;
    _isMcqAnswered = false;
    _isSentenceAnswered = false;
    _wordBank = [];
    _assembledWords = [];
    _correctFirstWord = "";
    if (task.sentence != null && task.sentence!.isNotEmpty) {
      final words = task.sentence!.split(' ');
      if (words.isNotEmpty) {
        _correctFirstWord = words.first;
      }
      _wordBank = List.from(words)..shuffle();
    } else if (task.audioUrl != null && task.audioUrl!.isNotEmpty) {
      _loadAudio(task.audioUrl!);
    }
  }

  Future<void> _loadAudio(String newAudioUrl) async {
    if (newAudioUrl == _currentlyLoadedAudioUrl) {
      return;
    }
    try {
      if (mounted) {
        setState(() {
          _isPlayerLoading = true;
        });
      }
      await _audioPlayer.setUrl(newAudioUrl);
      _currentlyLoadedAudioUrl = newAudioUrl;
      if (mounted) {
        setState(() {
          _isPlayerLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlayerLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка загрузки аудио: $e')));
      }
    }
  }

  void _playAudio() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      try {
        await _audioPlayer.play();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка воспроизведения аудио: $e')),
          );
        }
      }
    }
  }

  void _nextQuestion() {
    _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
      if (_currentIndex < _tasks.length - 1) {
        _currentIndex++;
        _prepareCurrentTask();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                QuizResultScreen(score: _score, totalQuestions: _tasks.length),
          ),
        );
      }
    });
  }

  void _checkMcqAnswer(int selectedIndex) {
    if (_isMcqAnswered) return;
    setState(() {
      _isMcqAnswered = true;
      _selectedAnswerIndex = selectedIndex;
      if (selectedIndex == _tasks[_currentIndex].correctAnswerIndex) {
        _score++;
      }
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }

  void _onWordBankTap(String word, int index) {
    setState(() {
      _assembledWords.add(word);
      _wordBank.removeAt(index);
    });
  }

  void _onAssembledWordTap(String word, int index) {
    setState(() {
      _wordBank.add(word);
      _assembledWords.removeAt(index);
    });
  }

  void _showHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("hint_first_word".tr(args: [_correctFirstWord]),
       ),
      ),
    );
  }

  void _checkSentence() {
    if (_isSentenceAnswered) return;
    final String assembledSentence = _assembledWords.join(' ');
    final String correctSentence = _tasks[_currentIndex].sentence!;
    setState(() {
      _isSentenceAnswered = true;
      if (assembledSentence == correctSentence) {
        _score++;
      }
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.subTestTitle)),
      body: FutureBuilder<List<QuizTask>>(
        future: _tasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || _tasks.isEmpty) {
            if (snapshot.hasError) {
              print("   FutureBuilder поймал ошибку: ${snapshot.error}");
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Не удалось загрузить задания.\n\nОшибка:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (snapshot.data != null && snapshot.data!.isEmpty) {
              return const Center(
                child: Text('В этом тесте пока нет заданий.'),
              );
            }

            return const Center(child: Text('Не удалось загрузить задания'));
          }

          final task = _tasks[_currentIndex];
          return _buildQuizUI(task);
        },
      ),
    );
  }

  Widget _buildQuizUI(QuizTask task) {
    double progressValue = (_currentIndex + 1) / _tasks.length;
    final bool isSentenceTask =
        task.sentence != null && task.sentence!.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Container(
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: progressValue,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    '${_currentIndex + 1} / ${_tasks.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: isSentenceTask
                  ? _buildSentenceScrambleUI(task)
                  : _buildMcqUI(task),
            ),
          ),
        ),
        isSentenceTask
            ? _buildSentenceCheckButton() // 👈 Ваша новая кнопка здесь
            : _buildMcqFeedbackBar(),
      ],
    );
  }

  Widget _buildMcqUI(QuizTask task) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (task.audioUrl != null && task.audioUrl!.isNotEmpty)
          _buildAudioPlayer(),
        if (task.text != null && task.text!.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxHeight: 270),
            child: SingleChildScrollView(
              child: MarkdownBody(
                data: task.text!,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(14),
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: const Color.fromARGB(255, 35, 2, 251)),
            borderRadius: BorderRadius.circular(8),
            color: const Color.fromARGB(255, 247, 245, 223),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            task.question,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(task.options.length, (index) {
          return _buildOptionButton(task, index);
        }),
      ],
    );
  }

  Widget _buildSentenceScrambleUI(QuizTask task) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                task.question,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.lightbulb_outline, color: Colors.orange),
              onPressed: _isSentenceAnswered ? null : _showHint,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _assembledWords.asMap().entries.map((entry) {
              int idx = entry.key;
              String word = entry.value;
              return InkWell(
                onTap: _isSentenceAnswered
                    ? null
                    : () => _onAssembledWordTap(word, idx),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(word, style: const TextStyle(fontSize: 16)),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.center,
            children: _wordBank.asMap().entries.map((entry) {
              int idx = entry.key;
              String word = entry.value;
              return InkWell(
                onTap: _isSentenceAnswered
                    ? null
                    : () => _onWordBankTap(word, idx),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(word, style: const TextStyle(fontSize: 16)),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- 💡💡💡 ВАША НОВАЯ ФУНКЦИЯ 💡💡💡 ---
  // Кнопка "Проверить" для "Жазуу"
  Widget _buildSentenceCheckButton() {
    final bool isCorrect =
        _assembledWords.join(' ') == _tasks[_currentIndex].sentence;

    // 1. 💡 Текст по умолчанию - "Проверить"
    Color color = Colors.green;
    String text = 'check_button'.tr();

    // 2. 💡 Если ответили - показываем "Правильно" / "Неправильно"
    if (_isSentenceAnswered) {
      color = isCorrect ? Colors.green : Colors.red;
      text = isCorrect ? 'correct'.tr() : 'incorrect'.tr();
    }

    // 3. 💡 Оборачиваем в Container, чтобы дать отступы
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      width: double.infinity,
      child: AnimatedOpacity(
        // 👈 4. Плавно появляется/исчезает
        duration: const Duration(milliseconds: 300),
        // 5. 💡 ПОКАЗЫВАЕМ ТОЛЬКО ЕСЛИ БАНК СЛОВ ПУСТ
        opacity: _wordBank.isEmpty ? 1.0 : 0.0,
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              // 6. 💡 ДЕЛАЕМ КНОПКУ КРУГЛОЙ (как "Начать")
              shape: const StadiumBorder(),
            ),
            // 7. 💡 Блокируем кнопку, если слова не собраны или уже ответили
            onPressed: (_wordBank.isEmpty && !_isSentenceAnswered)
                ? _checkSentence
                : null,
            child: Text(
              text, // 👈 8. Показываем правильный текст
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
  // --- 💡💡💡 КОНЕЦ НОВОЙ ФУНКЦИИ 💡💡💡 ---

  Widget _buildMcqFeedbackBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: _getMcqFeedbackColor(),
      child: Text(
        _getMcqFeedbackText(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  String _getMcqFeedbackText() {
    if (!_isMcqAnswered) return '';
    if (_selectedAnswerIndex == _tasks[_currentIndex].correctAnswerIndex)
      return 'correct'.tr();
    return 'incorrect'.tr();
  }

  Color _getMcqFeedbackColor() {
    if (!_isMcqAnswered) return Colors.transparent;
    if (_selectedAnswerIndex == _tasks[_currentIndex].correctAnswerIndex)
      return Colors.green;
    return Colors.red;
  }

  Widget _buildAudioPlayer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            iconSize: 36,
            icon: _isPlayerLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                  ),
            color: Colors.blue,
            onPressed: () => _playAudio(),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton(QuizTask task, int index) {
    Color buttonColor = const Color.fromARGB(255, 235, 244, 241);
    Color borderColor = const Color.fromARGB(255, 57, 57, 57);
    if (_isMcqAnswered) {
      if (index == task.correctAnswerIndex) {
        buttonColor = Colors.green.shade100;
        borderColor = Colors.green;
      } else if (index == _selectedAnswerIndex) {
        buttonColor = Colors.red.shade100;
        borderColor = Colors.red;
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _isMcqAnswered
              ? null
              : () => _checkMcqAnswer(index), // Блокируем после ответа
          style: OutlinedButton.styleFrom(
            backgroundColor: buttonColor,
            side: BorderSide(color: borderColor, width: 2),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            task.options[index],
            style: const TextStyle(fontSize: 16, color: Colors.black),
          ),
        ),
      ),
    );
  }
}
