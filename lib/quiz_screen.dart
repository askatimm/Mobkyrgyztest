import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'quiz_result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Модель QuizTask ---
class QuizTask {
  final String id;
  final String? text;
  final String? audioUrl;
  final String? sentence;
  final String? promptSentence;
  final String? correctText;
  final String type;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final List<dynamic>? parts;
  final List<String>? answers;

  QuizTask({
    required this.id,
    this.text,
    this.audioUrl,
    this.sentence,
    this.promptSentence,
    this.correctText,
    this.parts,
    this.answers,
    required this.type,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
  });

  factory QuizTask.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return QuizTask(
      id: doc.id,
      text: data['text'],
      audioUrl: data['audioUrl'],
      sentence: data['sentence'],
      promptSentence: data['promptSentence'],
      correctText: data['correctText'],
      type: data['type'] ?? 'mcq',
      question: data['question'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctAnswerIndex: data['correctAnswerIndex'] ?? 0,
      parts: data['parts'] as List<dynamic>?,
      answers: data['answers'] != null
          ? List<String>.from(data['answers'])
          : null,
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
  List<bool?> _gapResults = [];
  final List<Map<String, String>> _writingMistakes = [];
  int _totalWritingGaps = 0;
  int _correctWritingGaps = 0;

  final TextEditingController _writingController = TextEditingController();

  List<TextEditingController> _gapControllers = [];
  bool _isWritingAnswered = false;

  bool get _isAdvancedWritingLevel {
    final level = widget.levelId.toLowerCase();
    return level == 'level_b1' || level == 'level_b2' || level == 'level_c1';
  }

  int _getTaskLimit() {
    switch (widget.subTestId) {
      case 'vocabulary':
      case 'lexica_grammatica':
        return 50;

      case 'listening':
        return 25;

      case 'reading':
        return 25;

      case 'speaking':
        return 20;

      case 'writing':
        return 20;

      default:
        return 20;
    }
  }

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

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _effectPlayer.dispose();
    _audioPlayer.dispose();
    _userPlayer.dispose();
    _recorder.dispose();
    _writingController.dispose();
    _disposeGapControllers();
    super.dispose();
  }

  void _disposeGapControllers() {
    for (final controller in _gapControllers) {
      controller.dispose();
    }
    _gapControllers.clear();
  }

  Future<List<QuizTask>> _loadTasks() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('levels')
        .doc(widget.levelId)
        .collection('sub_tests')
        .doc(widget.subTestId)
        .collection('tasks')
        .get();

    final allTasks = snapshot.docs
        .map((doc) => QuizTask.fromFirestore(doc))
        .toList();

    allTasks.shuffle();

    final limit = _getTaskLimit();

    _tasks = allTasks.take(limit).toList();

    return _tasks;
  }

  void _prepareCurrentTask() {
    if (_tasks.isEmpty) return;

    final task = _tasks[_currentIndex];

    _isMcqAnswered = false;
    _selectedAnswerIndex = null;
    _isSentenceAnswered = false;
    _isWritingAnswered = false;

    _disposeGapControllers();

    _wordBank = [];
    _assembledWords = [];
    _correctFirstWord = "";
    _hasUserRecording = false;
    _userRecordingPath = null;
    _isPlaying = false;

    _currentlyLoadedAudioUrl = null;
    _audioPlayer.stop();

    if (task.type == 'writing') {
      if (_isAdvancedWritingLevel) {
        final count = task.answers?.length ?? 0;
        _gapControllers = List.generate(count, (_) => TextEditingController());
        _gapResults = List.generate(count, (_) => null);
      } else if (task.sentence != null) {
        final words = task.sentence!
            .trim()
            .split(' ')
            .where((w) => w.isNotEmpty)
            .toList();

        if (words.isNotEmpty) {
          _correctFirstWord = words.first;
          _wordBank = List.from(words)..shuffle();
        }
      }
    } else if (task.audioUrl != null && task.audioUrl!.isNotEmpty) {
      _loadAudio(task.audioUrl!);
    }
  }

  String _normalizeAnswer(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _areAllGapsFilled() {
    if (_gapControllers.isEmpty) return false;
    return _gapControllers.every((c) => c.text.trim().isNotEmpty);
  }

  void _checkWritingAnswersPerGap(QuizTask task) {
    final correctAnswers = task.answers ?? [];

    _gapResults = List.generate(correctAnswers.length, (i) {
      return _normalizeAnswer(_gapControllers[i].text) ==
          _normalizeAnswer(correctAnswers[i]);
    });
  }

  void _collectWritingMistakes(QuizTask task) {
    final correctAnswers = task.answers ?? [];

    for (int i = 0; i < correctAnswers.length; i++) {
      final userText = _gapControllers[i].text.trim();
      final correctText = correctAnswers[i].trim();

      _totalWritingGaps++;

      if (_normalizeAnswer(userText) == _normalizeAnswer(correctText)) {
        _correctWritingGaps++;
      } else {
        _writingMistakes.add({
          'user': userText.isEmpty ? '—' : userText,
          'correct': correctText,
        });
      }
    }
  }

  Widget _buildLetterBoxesField(
    TextEditingController controller,
    int boxCount,
    int gapIndex,
  ) {
    const double boxWidth = 18;
    const double boxHeight = 24;
    const double gap = 2;

    Color borderColor = Colors.grey.shade400;

    if (_isWritingAnswered && gapIndex < _gapResults.length) {
      final result = _gapResults[gapIndex];
      if (result == true) {
        borderColor = Colors.green;
      } else if (result == false) {
        borderColor = Colors.red;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.centerLeft,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  boxCount,
                  (index) => Container(
                    width: boxWidth,
                    height: boxHeight,
                    margin: const EdgeInsets.only(right: gap),
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(5),
                      color: Colors.white,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      index < controller.text.length
                          ? controller.text[index]
                          : '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: 0.01,
                child: SizedBox(
                  width: boxCount * (boxWidth + gap),
                  child: TextField(
                    controller: controller,
                    enabled: !_isWritingAnswered,
                    maxLength: boxCount,
                    onChanged: (_) {
                      setState(() {});
                    },
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_isWritingAnswered &&
              gapIndex < _gapResults.length &&
              _gapResults[gapIndex] == false)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '✓ ${_tasks[_currentIndex].answers![gapIndex]}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isWritingAnswerCorrect(QuizTask task) {
    final correctAnswers = task.answers ?? [];
    if (correctAnswers.length != _gapControllers.length) return false;

    for (int i = 0; i < correctAnswers.length; i++) {
      if (_normalizeAnswer(_gapControllers[i].text) !=
          _normalizeAnswer(correctAnswers[i])) {
        return false;
      }
    }
    return true;
  }

  Future<void> _loadAudio(String url) async {
    if (url.isEmpty || url == _currentlyLoadedAudioUrl) {
      setState(() => _isPlayerLoading = false);
      debugPrint('audio skip: empty or already loaded');
      return;
    }

    try {
      setState(() => _isPlayerLoading = true);
      debugPrint('START load audio: $url');

      await _audioPlayer.setUrl(url).timeout(const Duration(seconds: 10));

      _currentlyLoadedAudioUrl = url;
      debugPrint('AUDIO LOADED OK');
    } catch (e) {
      debugPrint("Ошибка загрузки аудио: $e");
    } finally {
      if (mounted) setState(() => _isPlayerLoading = false);
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path =
            '${dir.path}/speech_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
      setState(() {
        _isRecording = false;
        _hasUserRecording = true;
      });
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

  // --- Вспомогательный виджет для меток "вопрос", "ответ", "текст" ---
  Widget _buildSmallLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5, left: 4),
        child: Text(
          text.toLowerCase(),
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedQuestion(String text) {
    final RegExp exp = RegExp(r'\*\*(.*?)\*\*');
    final List<TextSpan> spans = [];

    int currentIndex = 0;
    final matches = exp.allMatches(text);

    for (final match in matches) {
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.35,
            ),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
            height: 1.35,
          ),
        ),
      );

      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            height: 1.35,
          ),
        ),
      );
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: spans),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subTestTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/mountain_gr.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.white.withValues(alpha: 0.65),
              BlendMode.lighten,
            ),
          ),
        ),
        child: FutureBuilder<List<QuizTask>>(
          future: _tasksFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text("Ошибка загрузки: ${snapshot.error}"));
            }
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
                  _buildProgressBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 8,
                        bottom: 16,
                      ),
                      child: _buildTaskBody(task),
                    ),
                  ),
                  _buildBottomAction(task),
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
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 0),
      child: Row(
        children: [
          Text(
            "${_currentIndex + 1}/${_tasks.length}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
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
      case 'writing':
        return _buildWritingUI(task);
      case 'speaking':
        return _buildSpeakingUI(task);
      case 'reading':
        return _buildReadingUI(task);
      default:
        return _buildMcqUI(task);
    }
  }

  List<Widget> _buildInlineWritingWidgets(QuizTask task) {
    final parts = task.parts ?? [];
    final answers = task.answers ?? [];
    final List<Widget> widgets = [];
    int gapIndex = 0;

    for (final part in parts) {
      if (part == null) {
        final currentGap = gapIndex;
        final boxCount = answers[currentGap].length;
        gapIndex++;

        widgets.add(
          _buildLetterBoxesField(
            _gapControllers[currentGap],
            boxCount,
            currentGap,
          ),
        );
      } else {
        final text = part.toString();
        final words = text.split(RegExp(r'(\s+)'));

        for (final word in words) {
          if (word.isEmpty) continue;

          widgets.add(
            Text(
              word,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          );
        }
      }
    }

    return widgets;
  }

  // --- 1. UI: Writing (Жазуу) ---
  Widget _buildWritingUI(QuizTask task) {
    if (_isAdvancedWritingLevel) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.question,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200, width: 2),
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 2,
              runSpacing: 10,
              children: _buildInlineWritingWidgets(task),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                task.question,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.lightbulb, color: Colors.orange),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "hint_first_word".tr(args: [_correctFirstWord]),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            children: _assembledWords
                .asMap()
                .entries
                .map(
                  (e) => ActionChip(
                    label: Text(e.value),
                    onPressed: _isSentenceAnswered
                        ? null
                        : () {
                            setState(() {
                              _wordBank.add(e.value);
                              _assembledWords.removeAt(e.key);
                            });
                          },
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 40),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: _wordBank
              .asMap()
              .entries
              .map(
                (e) => ActionChip(
                  label: Text(e.value),
                  backgroundColor: Colors.blue.shade50,
                  onPressed: _isSentenceAnswered
                      ? null
                      : () {
                          setState(() {
                            _assembledWords.add(e.value);
                            _wordBank.removeAt(e.key);
                          });
                        },
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  // --- 2. UI: Speaking (Сүйлөө) ---
  Widget _buildSpeakingUI(QuizTask task) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "listen_tt_sample".tr(),
          style: TextStyle(color: Colors.grey.shade700),
        ),
        Center(child: _buildAudioPlayerWidget()),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Text(
            task.question,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        _buildSmallLabel("answer".tr()),
        Center(child: _buildMicButton()),
        if (_hasUserRecording)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: ElevatedButton.icon(
                onPressed: _playUserRecording,
                icon: const Icon(Icons.play_circle_filled),
                label: Text("listen_user".tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --- 3. UI: MCQ (Лексика, Грамматика, Аудио) ---
  Widget _buildMcqUI(QuizTask task) {
    if (task.options.isEmpty) {
      return const Center(child: Text('No options available'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSmallLabel("question".tr()),
        if (task.audioUrl != null && task.audioUrl!.isNotEmpty) ...[
          Center(child: _buildAudioPlayerWidget()),
          const SizedBox(height: 20),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade200, width: 2),
          ),
          child: _buildHighlightedQuestion(task.question),
        ),
        const SizedBox(height: 10),
        _buildSmallLabel("answer".tr()),
        ...List.generate(
          task.options.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(
                    double.infinity,
                    50,
                  ), // одинаковая высота
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  backgroundColor: _isMcqAnswered
                      ? (index == task.correctAnswerIndex
                            ? Colors.green.shade100
                            : (index == _selectedAnswerIndex
                                  ? Colors.red.shade100
                                  : Colors.white))
                      : Colors.white,
                  foregroundColor: Colors.black,
                  shape: const StadiumBorder(),
                  side: BorderSide(
                    color: _isMcqAnswered && index == task.correctAnswerIndex
                        ? Colors.green
                        : Colors.grey.shade400,
                    width:
                        _isMcqAnswered &&
                            (index == task.correctAnswerIndex ||
                                index == _selectedAnswerIndex)
                        ? 3
                        : 1,
                  ),
                  elevation: 0,
                ),
                onPressed: _isMcqAnswered ? null : () => _submitMcq(index),
                child: Text(
                  task.options[index],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- 4. UI: Reading (Окуу) ---
  Widget _buildReadingUI(QuizTask task) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (task.text != null) ...[
          _buildSmallLabel("текст"),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10), //
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            constraints: const BoxConstraints(maxHeight: 300), //
            child: SingleChildScrollView(
              child: MarkdownBody(data: task.text!, softLineBreak: true),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Подтягивает "вопрос" и "ответ" автоматически
        _buildMcqUI(task),
      ],
    );
  }

  Widget _buildAudioPlayerWidget() {
    return IconButton(
      iconSize: 72,
      icon: _isPlayerLoading
          ? const CircularProgressIndicator()
          : Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: Colors.blue,
            ),
      onPressed: _isPlayerLoading
          ? null
          : () {
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
      // Это заставляет детектор ловить нажатия во всей области,
      // даже если она перекрыта прозрачным краем другого виджета
      behavior: HitTestBehavior.opaque,
      onTap: _isRecording ? _stopRecording : _startRecording,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _isRecording ? Colors.red : Colors.blue,
              shape: BoxShape.circle,
              boxShadow: _isRecording
                  ? [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 10,
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              _isRecording ? Icons.stop : Icons.mic,
              color: Colors.white,
              size: 48,
            ),
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

  void _submitMcq(int index) {
    final currentTask = _tasks[_currentIndex];
    setState(() {
      _isMcqAnswered = true;
      _selectedAnswerIndex = index;
      bool isCorrect = (index == currentTask.correctAnswerIndex);
      if (isCorrect) _score++;
      _playFeedbackSound(isCorrect, currentTask.type);
    });
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
        MaterialPageRoute(
          builder: (context) => QuizResultScreen(
            score: _score,
            totalQuestions: _tasks.length,
            writingMistakes: _writingMistakes,
            totalWritingGaps: _totalWritingGaps,
            correctWritingGaps: _correctWritingGaps,
            isAdvancedWriting: _isAdvancedWritingLevel,
          ),
        ),
      );
    }
  }

  Widget _buildBottomAction(QuizTask task) {
    if (task.type == 'writing') {
      if (_isAdvancedWritingLevel) {
        final isReadyToCheck = _areAllGapsFilled();
        final isCorrect = _isWritingAnswered
            ? _isWritingAnswerCorrect(task)
            : false;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isWritingAnswered
                    ? (isCorrect ? Colors.green : Colors.red)
                    : Colors.green,
                shape: const StadiumBorder(),
              ),
              onPressed: (isReadyToCheck && !_isWritingAnswered)
                  ? () {
                      _checkWritingAnswersPerGap(task);
                      _collectWritingMistakes(task);

                      final result = _gapResults.every((e) => e == true);

                      setState(() {
                        _isWritingAnswered = true;
                        if (result) _score++;
                      });

                      _playFeedbackSound(result, task.type);

                      Future.delayed(
                        const Duration(milliseconds: 4000),
                        _nextQuestion,
                      );
                    }
                  : null,
              child: Text(
                _isWritingAnswered
                    ? (isCorrect ? "correct".tr() : "incorrect".tr())
                    : "check_button".tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }

      bool isReadyToCheck = _wordBank.isEmpty;
      final isCorrect = _assembledWords.join(' ') == task.sentence;

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
                    ? (isCorrect ? Colors.green : Colors.red)
                    : Colors.green,
                shape: const StadiumBorder(),
              ),
              onPressed: (isReadyToCheck && !_isSentenceAnswered)
                  ? () {
                      final result = _assembledWords.join(' ') == task.sentence;

                      setState(() {
                        _isSentenceAnswered = true;
                        if (result) _score++;
                      });

                      _playFeedbackSound(result, task.type);

                      Future.delayed(
                        const Duration(milliseconds: 1500),
                        _nextQuestion,
                      );
                    }
                  : null,
              child: Text(
                _isSentenceAnswered
                    ? (isCorrect ? "correct".tr() : "incorrect".tr())
                    : "check_button".tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _playFeedbackSound(bool isCorrect, String taskType) async {
    if (taskType == 'speaking') return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('test_sound') ?? true)) return;
    try {
      await _effectPlayer.stop();
      String assetPath = isCorrect
          ? 'assets/audio/success.mp3'
          : 'assets/audio/err.mp3';
      await _effectPlayer.setAsset(assetPath);
      await _effectPlayer.play();
    } catch (e) {
      debugPrint("Ошибка звука: $e");
    }
  }
}
