import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'quiz_result_screen.dart';

// --- Модель QuizTask ---
class QuizTask {
  final String id;
  final String? text;
  final String? audioUrl;
  final String? sentence;
  final String type; 
  final String question;
  final List<String> options;
  final int correctAnswerIndex;

  QuizTask({
    required this.id,
    this.text,
    this.audioUrl,
    this.sentence,
    required this.type,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
  });

  factory QuizTask.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return QuizTask(
      id: doc.id,
      text: data['text'],
      audioUrl: data['audioUrl'],
      sentence: data['sentence'],
      type: data['type'] ?? 'mcq',
      question: data['question'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctAnswerIndex: data['correctAnswerIndex'] ?? 0,
    );
  }
}

class QuizScreen extends StatefulWidget {
  final String levelId;
  final String subTestId;
  final String subTestTitle;

  const QuizScreen({
    super.key,
    required this.levelId,
    required this.subTestId,
    required this.subTestTitle,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late Future<List<QuizTask>> _tasksFuture;
  List<QuizTask> _tasks = [];
  int _currentIndex = 0;
  int _score = 0;


  // Плееры и запись
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _userPlayer = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<PlayerState>? _playerStateSubscription;
  String? _currentlyLoadedAudioUrl;
  
  // Общее состояние UI
  bool _isPlayerLoading = false;
  bool _isPlaying = false;
  bool _isRecording = false;
  bool _hasUserRecording = false;
  String? _userRecordingPath;

  // Состояние MCQ
  int? _selectedAnswerIndex;
  bool _isMcqAnswered = false;

  // Состояние Жазуу (Scramble)
  List<String> _wordBank = [];
  List<String> _assembledWords = [];
  String _correctFirstWord = "";
  bool _isSentenceAnswered = false;

  @override
  void initState() {
    super.initState();
    _tasksFuture = _loadTasks().then((loadedTasks) {
      if (mounted) _prepareCurrentTask();
      return loadedTasks;
    });

    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state.playing);
        if (state.processingState == ProcessingState.completed) {
          setState(() => _isPlaying = false);
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.pause();
        }
      }
    });
  }
  void _playFeedbackSound(bool isCorrect, String taskType) async {
  if (taskType == 'speaking') return;

}
  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _effectPlayer.dispose();
    _audioPlayer.dispose();
    _userPlayer.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<List<QuizTask>> _loadTasks() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('levels').doc(widget.levelId)
        .collection('sub_tests').doc(widget.subTestId)
        .collection('tasks').get();
    
    _tasks = snapshot.docs.map((doc) => QuizTask.fromFirestore(doc)).toList();
    _tasks.shuffle();
    return _tasks;
  }

  void _prepareCurrentTask() {
    if (_tasks.isEmpty) return;
    final task = _tasks[_currentIndex];

    // Сброс всех состояний
    _isMcqAnswered = false;
    _selectedAnswerIndex = null;
    _isSentenceAnswered = false;
    _wordBank = [];
    _assembledWords = [];
    _correctFirstWord = "";
    _hasUserRecording = false;
    _userRecordingPath = null;
    _isPlaying = false;

    if (task.type == 'writing' && task.sentence != null) {
      final words = task.sentence!.trim().split(' ').where((w) => w.isNotEmpty).toList();
      if (words.isNotEmpty) {
        _correctFirstWord = words.first;
        _wordBank = List.from(words)..shuffle();
      }
    } else if (task.audioUrl != null && task.audioUrl!.isNotEmpty) {
      _loadAudio(task.audioUrl!);
    }
  }

Future<void> _loadAudio(String url) async {
  if (url == _currentlyLoadedAudioUrl) return;
  try {
    // ❗ Проверка: не закрыт ли экран перед началом
    if (!mounted) return; 
    setState(() => _isPlayerLoading = true);
    
    await _audioPlayer.setUrl(url);
    _currentlyLoadedAudioUrl = url;
    
    // ❗ Проверка: не закрыл ли пользователь экран, пока грузился звук
    if (!mounted) return; 
    setState(() => _isPlayerLoading = false);
  } catch (e) {
    if (!mounted) return;
    setState(() => _isPlayerLoading = false);
  }
}

  // Логика записи (Speaking)
  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/speech_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(const RecordConfig(), path: path);
        setState(() { 
          _isRecording = true; 
          _userRecordingPath = path; 
          _hasUserRecording = false;
        });
      }
    } catch (e) {
      debugPrint("Ошибка записи: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stop();
      setState(() { _isRecording = false; _hasUserRecording = true; });
    } catch (e) {
      debugPrint("Ошибка остановки записи: $e");
    }
  }

  Future<void> _playUserRecording() async {
    if (_userRecordingPath != null) {
      await _userPlayer.setFilePath(_userRecordingPath!); 
      _userPlayer.play();
    }
  }

  //  UI Рендеринг 
  @override
Widget build(BuildContext context) {
  return Scaffold(
    // Делаем AppBar прозрачным, чтобы фон был виден полностью
    appBar: AppBar(
      title: Text(widget.subTestTitle),
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    extendBodyBehindAppBar: true, // Фон заходит под верхнюю панель
    body: Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage('assets/images/mountain_gr.png'),
          fit: BoxFit.cover,
          // Добавляем фильтр, чтобы картинка была светлее и текст читался лучше
          colorFilter: ColorFilter.mode(
            Colors.white.withValues(alpha: 0.65), 
            BlendMode.lighten
          ),
        ),
      ),
      child: FutureBuilder<List<QuizTask>>(
        future: _tasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || _tasks.isEmpty) {
            return const Center(child: Text('Задания не найдены'));
          }

          final task = _tasks[_currentIndex];

          return SafeArea(
            child: Column(
              children: [
                _buildProgressBar(), // Ваша полоска и нумерация
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildTaskBody(task), // Контент (MCQ, Жазуу и т.д.)
                  ),
                ),
                _buildBottomAction(task), // Кнопки "Проверить" или "Далее"
              ],
            ),
          );
        },
      ),
    ),
  );
}

Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Row( 
        children: [
          // 1. Нумерация слева
          Text(
            "${_currentIndex + 1}/${_tasks.length}",
            style: const TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 12), // Отступ между текстом и полоской
          
          // 2. Полоска прогресса (Expanded заставляет её занять всё оставшееся место)
          Expanded( 
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (_currentIndex + 1) / _tasks.length,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskBody(QuizTask task) {
    switch (task.type) {
      case 'writing': return _buildWritingUI(task);
      case 'speaking': return _buildSpeakingUI(task);
      case 'reading': return _buildReadingUI(task);
      default: return _buildMcqUI(task);
    }
  }

  // --- 1. UI: Writing (Сборка предложения) ---
  Widget _buildWritingUI(QuizTask task) {
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(task.question, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          IconButton(
            icon: const Icon(Icons.lightbulb, color: Colors.orange), 
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("hint_first_word".tr(args: [_correctFirstWord])))
              );
            },
          ),
        ]),
        const SizedBox(height: 20),
        // Контейнер для собранных слов (с исправленным BoxConstraints)
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100, 
            borderRadius: BorderRadius.circular(12), 
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Wrap(
            spacing: 8, runSpacing: 8, 
            children: _assembledWords.asMap().entries.map((e) => ActionChip(
              label: Text(e.value), 
              onPressed: _isSentenceAnswered ? null : () {
                setState(() { _wordBank.add(e.value); _assembledWords.removeAt(e.key); });
              },
            )).toList(),
          ),
        ),
        const SizedBox(height: 40),
        // Банк слов
        Wrap(
          spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
          children: _wordBank.asMap().entries.map((e) => ActionChip(
            label: Text(e.value),
            backgroundColor: Colors.blue.shade50,
            onPressed: _isSentenceAnswered ? null : () {
              setState(() { _assembledWords.add(e.value); _wordBank.removeAt(e.key); });
            },
          )).toList(),
        ),
      ],
    );
  }

  // UI Speaking 
  Widget _buildSpeakingUI(QuizTask task) {
    return Column(
      children: [
        const Text("Прослушайте образец:", style: TextStyle(color: Colors.grey)),
        _buildAudioPlayerWidget(),
        const SizedBox(height: 30),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Text(
            task.question, 
            textAlign: TextAlign.center, 
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 50),
        _buildMicButton(),
        const SizedBox(height: 24),
        if (_hasUserRecording)
          ElevatedButton.icon(
            onPressed: _playUserRecording,
            icon: const Icon(Icons.play_circle_filled),
            label: Text("listen_user".tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange, 
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
          )
      ],
    );
  }

  // UI MCQ (Обычный тест) 
  Widget _buildMcqUI(QuizTask task) {
  return Column(
    children: [
      if (task.audioUrl != null && task.audioUrl!.isNotEmpty) ...[
        _buildAudioPlayerWidget(),
        const SizedBox(height: 20),
      ],
      
      // Блок вопроса в рамке 
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200, width: 2), 
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          task.question, 
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), 
          textAlign: TextAlign.center
        ),
      ),
      
      const SizedBox(height: 20),

      // Варианты ответов
      ...List.generate(task.options.length, (index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: _isMcqAnswered 
                  ? (index == task.correctAnswerIndex ? Colors.green.shade100 : (index == _selectedAnswerIndex ? Colors.red.shade100 : Colors.white)) 
                  : Colors.white,
              foregroundColor: Colors.black,
              shape: const StadiumBorder(), 
              side: BorderSide(
                color: _isMcqAnswered && index == task.correctAnswerIndex ? Colors.green : Colors.grey.shade400
              ),
            ),
            onPressed: _isMcqAnswered ? null : () => _submitMcq(index),
            child: Text(task.options[index], style: const TextStyle(fontSize: 14)),
          ),
        ),
      )),
    ],
  );
}

  // UI Reading
  Widget _buildReadingUI(QuizTask task) {
    return Column(
      children: [
        if (task.text != null) 
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade200, 
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(child: MarkdownBody(data: task.text!)),
          ),
        const SizedBox(height: 30),
        _buildMcqUI(task),
      ],
    );
  }

  // Вспомогательные виджеты

  Widget _buildAudioPlayerWidget() {
    return IconButton(
      iconSize: 72,
      icon: _isPlayerLoading 
          ? const CircularProgressIndicator()
          : Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.blue),
      onPressed: _isPlayerLoading ? null : () {
        if (_isPlaying) { 
          _audioPlayer.pause(); 
        } else { 
          _audioPlayer.play(); 
        }
      },
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: _isRecording ? _stopRecording : _startRecording,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _isRecording ? Colors.red : Colors.blue,
              shape: BoxShape.circle,
              boxShadow: _isRecording ? [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 20, spreadRadius: 10)] : [],
            ),
            child: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 12),
          Text(
            _isRecording ? "recording".tr() : "start_record".tr(),
            style: TextStyle(
              color: _isRecording ? Colors.red : Colors.blue, 
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // Логика действий 

  void _submitMcq(int index) {
  final currentTask = _tasks[_currentIndex]; // Получаем текущую задачу
  
  setState(() {
    _isMcqAnswered = true;
    _selectedAnswerIndex = index;
    
    // Проверяем правильность ответа
    bool isCorrect = (index == currentTask.correctAnswerIndex);
    if (isCorrect) _score++; // Увеличиваем счет при успехе

    // 🔊 Запускаем звук (автоматически пропустит Говорение внутри функции)
    _playFeedbackSound(isCorrect, currentTask.type); 
  });

  // Задержка перед переходом к следующему вопросу
  Future.delayed(const Duration(milliseconds: 1500), _nextQuestion);
}
  
  void _nextQuestion() {
    _audioPlayer.stop();
    _userPlayer.stop();
    if (_currentIndex < _tasks.length - 1) {
      setState(() { 
        _currentIndex++; 
        _prepareCurrentTask(); 
      });
    } else {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (c) => QuizResultScreen(score: _score, totalQuestions: _tasks.length))
      );
    }
  }

  Widget _buildBottomAction(QuizTask task) {
    // Кнопка для режима Writing
    if (task.type == 'writing') {
      bool isReadyToCheck = _wordBank.isEmpty;
      return AnimatedOpacity(
        opacity: isReadyToCheck ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSentenceAnswered 
                    ? (_assembledWords.join(' ') == task.sentence ? Colors.green : Colors.red) 
                    : Colors.green,
                shape: const StadiumBorder(),
                elevation: 4,
              ),
              onPressed: (isReadyToCheck && !_isSentenceAnswered) ? () {

                bool isCorrect = _assembledWords.join(' ') == task.sentence;
                
                setState(() {
                  _isSentenceAnswered = true;
                  if (isCorrect) _score++;
                });

                _playFeedbackSound(isCorrect, task.type); 

                Future.delayed(const Duration(milliseconds: 1500), _nextQuestion);
              } : null,
              child: Text(
                _isSentenceAnswered 
                    ? (_assembledWords.join(' ') == task.sentence ? "correct".tr() : "incorrect".tr()) 
                    : "check_button".tr(),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
           ),
          ),
        ),
      );
    }

    // Кнопка для режима Speaking
    if (task.type == 'speaking') {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green, 
              shape: const StadiumBorder(),
              elevation: 4,
            ),
            onPressed: _hasUserRecording ? () {
              _score++; 
              _nextQuestion();
            } : null,
            child: Text("next".tr(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    if (_isMcqAnswered) {
      bool isCorrect = _selectedAnswerIndex == task.correctAnswerIndex;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        color: isCorrect ? Colors.green : Colors.red,
        child: Text(
          isCorrect ? "correct".tr() : "incorrect".tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      );
    }

    return const SizedBox(height: 20);
  }
}