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
import '../models/essay_review.dart';
import '../services/ai_writing_service.dart';
import '../services/ai_usage_service.dart';
import '../services/daily_topic_service.dart';
import 'screens/daily_limit_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final List<String>? hints;
  final int order;
  final bool isActive;

  QuizTask({
    required this.id,
    this.text,
    this.audioUrl,
    this.sentence,
    this.promptSentence,
    this.correctText,
    this.parts,
    this.answers,
    this.hints,
    required this.type,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.order,
    required this.isActive,
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
      type: (data['type'] ?? 'mcq').toString().trim().toLowerCase(),
      question: (data['question'] ?? '').toString(),
      options: List<String>.from(data['options'] ?? []),
      correctAnswerIndex: data['correctAnswerIndex'] ?? 0,
      parts: data['parts'] is List ? List<dynamic>.from(data['parts']) : null,
      answers: data['answers'] != null
          ? List<String>.from(data['answers'])
          : null,
      hints: data['hints'] is List ? List<String>.from(data['hints']) : null,
      order: (data['order'] ?? 0) as int,
      isActive: (data['isActive'] ?? true) as bool,
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

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<QuizTask>> _tasksFuture;
  List<QuizTask> _tasks = [];
  int _currentIndex = 0;
  int _score = 0;
  List<bool?> _gapResults = [];
  final List<Map<String, String>> _writingMistakes = [];
  int _totalWritingGaps = 0;
  int _correctWritingGaps = 0;

  final TextEditingController _writingController = TextEditingController();
  final AiWritingService _aiWritingService = AiWritingService();
  final AiUsageService _aiUsageService = AiUsageService();
  final DailyTopicService _dailyTopicService = DailyTopicService();

  static const int _maxAiChecksPerTopic =
      AiUsageService.maxChecksPerTopic;

  bool _isCheckingEssay = false;
  bool _isLoadingAiUsage = false;
  int _remainingAiChecks = _maxAiChecksPerTopic;
  EssayReview? _essayReview;
  bool _essayChecked = false;

  Future<void> _checkEssayWithAi() async {
    final text = _writingController.text.trim();

    final currentTask = _tasks[_currentIndex];

    if (text.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(('write_essay_first'.tr()))));
      return;
    }

    final minLength = _getMinEssayLength();
    final maxLength = _getMaxEssayLength();

    if (text.length < minLength) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Текст өтө кыска. Кеминде $minLength символ жазыңыз.'),
        ),
      );
      return;
    }

    if (text.length > maxLength) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Текст өтө узун. Максимум $maxLength символ гана уруксат.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isCheckingEssay = true;
      _essayReview = null;
      _essayChecked = false;
    });

    try {
      final usage = await _aiUsageService.tryConsumeCheck(
        topicId: currentTask.id,
      );

      if (usage == null) {
        if (!mounted) return;

        setState(() => _remainingAiChecks = 0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ai_checks_limit_reached'.tr())),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _remainingAiChecks = usage.remainingChecks;
        _isLoadingAiUsage = false;
      });

      debugPrint("TOPIC SENT: ${currentTask.question}");
      final review = await _aiWritingService.checkEssay(
        context: context,
        essay: text,
        targetLevel: _getAiTargetLevel(),
        topic: currentTask.question,
      );

      // 🔥 сохраняем как выполненную тему СРАЗУ
      if (_isAiEssayLevel) {
        final userId = FirebaseAuth.instance.currentUser!.uid;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('daily_topics')
            .doc('${widget.levelId}_${widget.subTestId}')
            .set({
              'completedTaskIds': FieldValue.arrayUnion([currentTask.id]),
            }, SetOptions(merge: true));
      }

      setState(() {
        _essayReview = review;
        _essayChecked = true;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка AI-проверки: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingEssay = false;
        });
      }
    }
  }

  Widget _buildEssayReviewCard(EssayReview review) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFD3FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ai_review_result'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          Text('${'score'.tr()}: ${review.score}/10'),
          const SizedBox(height: 6),

          Text('${'level'.tr()}: ${review.level}'),
          const SizedBox(height: 12),

          Text(
            'comment'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),

          Text(review.summary),
          const SizedBox(height: 16),

          Text(
            'corrected_text'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),

          Text(review.correctedText),
          const SizedBox(height: 16),

          Text(
            'mistakes'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (review.mistakes.isEmpty)
            Text('no_mistakes_found'.tr())
          else
            ...review.mistakes.map(
              (m) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE3EAFB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${'original'.tr()}: ${m.original}'),
                    const SizedBox(height: 4),

                    Text('${'correct1'.tr()}: ${m.corrected}'),
                    const SizedBox(height: 4),

                    Text('${'type'.tr()}: ${m.category}'),
                    const SizedBox(height: 4),

                    Text('${'explanation'.tr()}: ${m.explanation}'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<TextEditingController> _gapControllers = [];
  List<FocusNode> _gapFocusNodes = [];
  List<Set<int>> _hintedGapCharacterIndexes = [];
  int? _activeGapIndex;
  late final AnimationController _cursorBlinkController;
  late final Animation<double> _cursorOpacity;
  bool _isWritingAnswered = false;

  bool get _isGapWritingLevel {
    final level = widget.levelId.toLowerCase();
    return level == 'level_b1';
  }

  bool get _isAiEssayLevel {
    final level = widget.levelId.toLowerCase();

    return widget.subTestId == 'writing' &&
        (level == 'level_b2' || level == 'level_c1');
  }

  String _getAiTargetLevel() {
    final level = widget.levelId.toLowerCase();
    if (level == 'level_c1') return 'C1';
    return 'B2';
  }

  int _getMinEssayLength() {
    final level = widget.levelId.toLowerCase();

    if (level == 'level_c1') return 250;
    if (level == 'level_b2') return 150;

    return 30;
  }

  int _getMaxEssayLength() {
    final level = widget.levelId.toLowerCase();

    if (level == 'level_c1') return 1200;
    if (level == 'level_b2') return 800;

    return 500;
  }

  Future<void> _loadAiUsageForTask(String taskId) async {
    try {
      final usage = await _aiUsageService.getUsage(topicId: taskId);

      if (!mounted ||
          _tasks.isEmpty ||
          _currentIndex >= _tasks.length ||
          _tasks[_currentIndex].id != taskId) {
        return;
      }

      setState(() {
        _remainingAiChecks = usage.remainingChecks;
        _isLoadingAiUsage = false;
      });
    } catch (_) {
      if (!mounted ||
          _tasks.isEmpty ||
          _currentIndex >= _tasks.length ||
          _tasks[_currentIndex].id != taskId) {
        return;
      }

      setState(() {
        _remainingAiChecks = _maxAiChecksPerTopic;
        _isLoadingAiUsage = false;
      });
    }
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
  //  ПРОГРЕСС АУДИО
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

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

    _cursorBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _cursorOpacity = CurvedAnimation(
      parent: _cursorBlinkController,
      curve: Curves.easeInOut,
    );
    _cursorBlinkController.repeat(reverse: true);

    _tasksFuture = _loadTasks().then((loadedTasks) {
      if (mounted) {
        _prepareCurrentTask();
        setState(() {});
      }
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
    _positionSub = _audioPlayer.positionStream.listen((pos) {
      if (mounted) {
        setState(() => _position = pos);
      }
    });

    _durationSub = _audioPlayer.durationStream.listen((dur) {
      if (mounted && dur != null) {
        setState(() => _duration = dur);
      }
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _effectPlayer.dispose();
    _audioPlayer.dispose();
    _userPlayer.dispose();
    _recorder.dispose();
    _writingController.dispose();
    _cursorBlinkController.dispose();
    _disposeGapControllers();
    super.dispose();
  }

  void _disposeGapControllers() {
    for (final controller in _gapControllers) {
      controller.dispose();
    }
    _gapControllers.clear();

    for (final focusNode in _gapFocusNodes) {
      focusNode.dispose();
    }
    _gapFocusNodes.clear();

    _hintedGapCharacterIndexes.clear();
    _activeGapIndex = null;
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
        .where((task) => task.isActive)
        .toList();

    // ✅ ТОЛЬКО для writing (AI эссе)
    if (_isAiEssayLevel) {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      final dailyDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('daily_topics')
          .doc('${widget.levelId}_${widget.subTestId}');

      final dailyDoc = await dailyDocRef.get();

      final taskIds = await _dailyTopicService.getTodayTaskIds(
        levelId: widget.levelId,
        subTestId: widget.subTestId,
      );

      final completed = dailyDoc.exists
          ? List<String>.from(dailyDoc.data()?['completedTaskIds'] ?? [])
          : [];

      final filtered = allTasks
          .where(
            (task) => taskIds.contains(task.id) && !completed.contains(task.id),
          )
          .toList();

      // 🔥 если всё пройдено → лимит экран
      // if (filtered.isEmpty) {
      //   Future.microtask(() {
      //     if (!mounted) return;
      //     Navigator.pushReplacement(
      //       context,
      //       MaterialPageRoute(builder: (_) => const DailyLimitScreen()),
      //     );
      //   });
      //   return [];
      // }

      filtered.shuffle();
      _tasks = filtered;
      return _tasks;
    }

    // ✅ для остальных (грамматика, лексика и т.д.)
    allTasks.shuffle();

    final limitedTasks = allTasks.take(_getTaskLimit()).toList();

    _tasks = limitedTasks;
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
      _writingController.clear();
      _essayReview = null;
      _essayChecked = false;
      _isCheckingEssay = false;

      if (_isGapWritingLevel) {
        final count = task.answers?.length ?? 0;
        _gapControllers = List.generate(count, (_) => TextEditingController());
        _gapFocusNodes = List.generate(count, (_) => FocusNode());
        _hintedGapCharacterIndexes = List.generate(count, (_) => <int>{});
        _gapResults = List.generate(count, (_) => null);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              _tasks.isEmpty ||
              _currentIndex >= _tasks.length ||
              _tasks[_currentIndex].id != task.id) {
            return;
          }
          _focusFirstIncompleteWritingGap();
        });
      } else if (_isAiEssayLevel) {
        _remainingAiChecks = _maxAiChecksPerTopic;
        _isLoadingAiUsage = true;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadAiUsageForTask(task.id);
          }
        });
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

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  String _getFullUserAnswer(int index) {
    final task = _tasks[_currentIndex];
    final hint = (task.hints != null && index < task.hints!.length)
        ? task.hints![index]
        : '';

    return '$hint${_gapControllers[index].text}';
  }

  bool _areAllGapsFilled() {
    if (_gapControllers.isEmpty) return false;
    return _gapControllers.every((c) => c.text.trim().isNotEmpty);
  }

  int _editableLengthForGap(QuizTask task, int gapIndex) {
    final answers = task.answers ?? [];
    if (gapIndex >= answers.length) return 0;

    final hint = task.hints != null && gapIndex < task.hints!.length
        ? task.hints![gapIndex]
        : '';
    final builtInHintLength = hint.isNotEmpty ? 1 : 0;

    return (answers[gapIndex].length - builtInHintLength).clamp(
      0,
      answers[gapIndex].length,
    );
  }

  int? _findIncompleteWritingGap({int startIndex = 0}) {
    if (_tasks.isEmpty || _currentIndex >= _tasks.length) return null;

    final task = _tasks[_currentIndex];

    for (int gapIndex = startIndex;
        gapIndex < _gapControllers.length;
        gapIndex++) {
      if (_gapControllers[gapIndex].text.length <
          _editableLengthForGap(task, gapIndex)) {
        return gapIndex;
      }
    }

    return null;
  }

  void _focusFirstIncompleteWritingGap() {
    final gapIndex = _findIncompleteWritingGap();
    if (gapIndex != null) {
      _focusWritingGap(gapIndex);
    }
  }

  void _focusWritingGap(int gapIndex) {
    if (!mounted ||
        gapIndex < 0 ||
        gapIndex >= _gapControllers.length ||
        gapIndex >= _gapFocusNodes.length) {
      return;
    }

    final controller = _gapControllers[gapIndex];
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );

    setState(() => _activeGapIndex = gapIndex);
    _gapFocusNodes[gapIndex].requestFocus();
  }

  void _moveToNextWritingGap(int currentGapIndex) {
    final nextGapIndex = _findIncompleteWritingGap(
      startIndex: currentGapIndex + 1,
    );

    if (nextGapIndex != null) {
      _focusWritingGap(nextGapIndex);
      return;
    }

    FocusScope.of(context).unfocus();
    if (mounted) {
      setState(() => _activeGapIndex = null);
    }
  }

  void _handleWritingGapChanged(int gapIndex, String value) {
    _syncHintedCharacterIndexes(gapIndex, value);

    if (_tasks.isEmpty || _currentIndex >= _tasks.length) {
      setState(() {});
      return;
    }

    final task = _tasks[_currentIndex];
    final editableLength = _editableLengthForGap(task, gapIndex);

    if (value.length >= editableLength) {
      _moveToNextWritingGap(gapIndex);
    } else {
      setState(() => _activeGapIndex = gapIndex);
    }
  }

  void _revealNextWritingHint() {
    if (!_isGapWritingLevel ||
        _isWritingAnswered ||
        _tasks.isEmpty ||
        _gapControllers.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();

    final task = _tasks[_currentIndex];
    final answers = task.answers ?? [];

    for (int gapIndex = 0;
        gapIndex < answers.length && gapIndex < _gapControllers.length;
        gapIndex++) {
      final controller = _gapControllers[gapIndex];
      final hint = task.hints != null && gapIndex < task.hints!.length
          ? task.hints![gapIndex]
          : '';
      final builtInHintLength = hint.isNotEmpty ? 1 : 0;
      final editableLength = answers[gapIndex].length - builtInHintLength;

      if (controller.text.length >= editableLength) continue;

      final controllerIndex = controller.text.length;
      final answerIndex = builtInHintLength + controllerIndex;
      final revealedCharacter = answers[gapIndex][answerIndex];
      final updatedText = '${controller.text}$revealedCharacter';

      controller.value = TextEditingValue(
        text: updatedText,
        selection: TextSelection.collapsed(offset: updatedText.length),
      );

      setState(() {
        _hintedGapCharacterIndexes[gapIndex].add(controllerIndex);
      });

      if (updatedText.length >= editableLength) {
        _moveToNextWritingGap(gapIndex);
      } else {
        _focusWritingGap(gapIndex);
      }
      return;
    }
  }

  void _syncHintedCharacterIndexes(int gapIndex, String text) {
    if (gapIndex >= _hintedGapCharacterIndexes.length ||
        _tasks.isEmpty ||
        _currentIndex >= _tasks.length) {
      return;
    }

    final task = _tasks[_currentIndex];
    final answers = task.answers ?? [];
    if (gapIndex >= answers.length) return;

    final hint = task.hints != null && gapIndex < task.hints!.length
        ? task.hints![gapIndex]
        : '';
    final builtInHintLength = hint.isNotEmpty ? 1 : 0;
    final correctAnswer = answers[gapIndex];

    _hintedGapCharacterIndexes[gapIndex].removeWhere((controllerIndex) {
      final answerIndex = builtInHintLength + controllerIndex;
      return controllerIndex >= text.length ||
          answerIndex >= correctAnswer.length ||
          text[controllerIndex] != correctAnswer[answerIndex];
    });
  }

  void _checkWritingAnswersPerGap(QuizTask task) {
    final correctAnswers = task.answers ?? [];

    _gapResults = List.generate(correctAnswers.length, (i) {
      return _normalizeAnswer(_getFullUserAnswer(i)) ==
          _normalizeAnswer(correctAnswers[i]);
    });
  }

  void _collectWritingMistakes(QuizTask task) {
    final correctAnswers = task.answers ?? [];

    for (int i = 0; i < correctAnswers.length; i++) {
      final userText = _getFullUserAnswer(i).trim();
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
    FocusNode focusNode,
    int boxCount,
    int gapIndex,
    String hint,
  ) {
    const double boxWidth = 20;
    const double boxHeight = 28;
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
                children: List.generate(boxCount, (index) {
                  String displayChar = '';
                  int? controllerIndex;

                  final isBuiltInHint = hint.isNotEmpty && index == 0;

                  if (isBuiltInHint) {
                    displayChar = hint;
                  } else {
                    controllerIndex = hint.isNotEmpty ? index - 1 : index;
                    if (controllerIndex >= 0 &&
                        controllerIndex < controller.text.length) {
                      displayChar = controller.text[controllerIndex];
                    }
                  }

                  final isRevealedByButton =
                      controllerIndex != null &&
                      gapIndex < _hintedGapCharacterIndexes.length &&
                      _hintedGapCharacterIndexes[gapIndex].contains(
                        controllerIndex,
                      );
                  final isHintCell = isBuiltInHint || isRevealedByButton;
                  final cursorBoxIndex =
                      (hint.isNotEmpty ? 1 : 0) + controller.text.length;
                  final isActiveCursor =
                      !_isWritingAnswered &&
                      _activeGapIndex == gapIndex &&
                      focusNode.hasFocus &&
                      index == cursorBoxIndex &&
                      displayChar.isEmpty;

                  final cellBorderColor = isHintCell && !_isWritingAnswered
                      ? const Color(0xFF38A3DB)
                      : borderColor;

                  return Container(
                    width: boxWidth,
                    height: boxHeight,
                    margin: const EdgeInsets.only(right: gap),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: cellBorderColor,
                        width: isHintCell ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(5),
                      color: isHintCell
                          ? const Color(0xFFE4F6FF)
                          : Colors.white,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          displayChar,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isHintCell
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isHintCell
                                ? const Color(0xFF087EB8)
                                : Colors.black87,
                          ),
                        ),
                        if (isActiveCursor)
                          FadeTransition(
                            opacity: _cursorOpacity,
                            child: Container(
                              width: 1.8,
                              height: 17,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1677E8),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        if (isHintCell)
                          const Positioned(
                            top: 1,
                            right: 1,
                            child: Icon(
                              Icons.lightbulb_rounded,
                              size: 7,
                              color: Color(0xFF20A060),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
              Opacity(
                opacity: 0.01,
                child: SizedBox(
                  width: boxCount * (boxWidth + gap),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: !_isWritingAnswered,
                    showCursor: false,
                    maxLength: hint.isNotEmpty ? boxCount - 1 : boxCount,
                    textInputAction: gapIndex < _gapControllers.length - 1
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onTap: () {
                      controller.selection = TextSelection.collapsed(
                        offset: controller.text.length,
                      );
                      setState(() => _activeGapIndex = gapIndex);
                    },
                    onChanged: (value) {
                      _handleWritingGapChanged(gapIndex, value);
                    },
                    onEditingComplete: () {
                      _moveToNextWritingGap(gapIndex);
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
      if (_normalizeAnswer(_getFullUserAnswer(i)) !=
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
        actions: [
          if (widget.subTestId == 'writing' && _isGapWritingLevel)
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 7, bottom: 7),
              child: OutlinedButton.icon(
                onPressed:
                    _isWritingAnswered ? null : _revealNextWritingHint,
                icon: const Icon(Icons.lightbulb_outline_rounded, size: 19),
                label: Text('hint_button'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38A05A),
                  disabledForegroundColor: Colors.grey.shade400,
                  backgroundColor: Colors.white.withValues(alpha: 0.42),
                  side: const BorderSide(
                    color: Color(0xFF8CCEA2),
                    width: 1.4,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
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
    debugPrint('CURRENT TASK TYPE: ${task.type}');
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
        final hint = task.hints?[currentGap] ?? '';
        final fullAnswer = answers[currentGap];
        final boxCount = fullAnswer.length;
        gapIndex++;

        widgets.add(
          _buildLetterBoxesField(
            _gapControllers[currentGap],
            _gapFocusNodes[currentGap],
            boxCount,
            currentGap,
            hint,
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
    if (_isGapWritingLevel) {
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

    if (_isAiEssayLevel) {
      final limitReached = _remainingAiChecks <= 0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: limitReached
                  ? const Color(0xFFFFECEC)
                  : const Color(0xFFEAF7EF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: limitReached
                    ? const Color(0xFFE57373)
                    : const Color(0xFF83C99A),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  limitReached
                      ? Icons.block_rounded
                      : Icons.auto_awesome_rounded,
                  color: limitReached
                      ? const Color(0xFFC62828)
                      : const Color(0xFF268447),
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    limitReached
                        ? 'ai_checks_limit_reached'.tr()
                        : '${'ai_checks_remaining'.tr()}: '
                              '$_remainingAiChecks/$_maxAiChecksPerTopic',
                    style: TextStyle(
                      color: limitReached
                          ? const Color(0xFFC62828)
                          : const Color(0xFF23683A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_isLoadingAiUsage)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          // FutureBuilder<bool>(
          //   future: _userService.isPremium(),
          //   builder: (context, snapshot) {
          //     final isPremium = snapshot.data ?? false;

          //     if (isPremium) return const SizedBox.shrink();

          //     return Container(
          //       width: double.infinity,
          //       margin: const EdgeInsets.only(bottom: 16),
          //       padding: const EdgeInsets.all(14),
          //       decoration: BoxDecoration(
          //         color: const Color(0xFFFFF3CD),
          //         borderRadius: BorderRadius.circular(14),
          //         border: Border.all(color: const Color(0xFFFFD54F)),
          //       ),
          //       child: Column(
          //         crossAxisAlignment: CrossAxisAlignment.start,
          //         children: [
          //           const Row(
          //             children: [
          //               Icon(Icons.lock, color: Colors.orange),
          //               SizedBox(width: 8),
          //               Expanded(
          //                 child: Text(
          //                   'AI текшерүү Premium колдонуучулар үчүн гана жеткиликтүү',
          //                   style: TextStyle(
          //                     fontWeight: FontWeight.bold,
          //                     fontSize: 14,
          //                   ),
          //                 ),
          //               ),
          //             ],
          //           ),
          //           const SizedBox(height: 10),
          //           SizedBox(
          //             width: double.infinity,
          //             child: ElevatedButton(
          //               onPressed: () async {
          //                 await PremiumService.showPaywall();
          //                 setState(() {});
          //               },
          //               child: const Text('Премиум сатып алуу'),
          //             ),
          //           ),
          //         ],
          //       ),
          //     );
          //   },
          // ),
          Text(
            task.question,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _writingController,
            maxLines: 10,
            maxLength: _getMaxEssayLength(),
            decoration: InputDecoration(
              hintText: 'write_your_essay_here'.tr(),
              helperText: 'Минимум ${_getMinEssayLength()} символ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),

            onChanged: (_) {
              if (_essayReview != null || _essayChecked) {
                setState(() {
                  _essayReview = null;
                  _essayChecked = false;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          if (_essayReview != null) _buildEssayReviewCard(_essayReview!),
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
          constraints: const BoxConstraints(minHeight: 80, maxHeight: 180),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topCenter,
              child: Text(
                task.question,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
            ),
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
                    color: _isMcqAnswered
                        ? (index == task.correctAnswerIndex
                              ? Colors.green
                              : (index == _selectedAnswerIndex
                                    ? const Color.fromARGB(255, 245, 97, 86)
                                    : Colors.grey.shade400))
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          iconSize: 72,
          icon: _isPlayerLoading
              ? const CircularProgressIndicator()
              : Icon(
                  _isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
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
        ),

        /// ПРОГРЕСС БАР
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.blue,
            inactiveTrackColor: Colors.blue.withValues(alpha: 0.2),

            thumbColor: Colors.blue,
            overlayColor: Colors.blue.withValues(alpha: 0.2),

            trackHeight: 4,

            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            min: 0,
            max: _duration.inSeconds.toDouble().clamp(1, double.infinity),
            value: _position.inSeconds.toDouble().clamp(
              0,
              _duration.inSeconds.toDouble(),
            ),
            onChanged: (value) async {
              await _audioPlayer.seek(Duration(seconds: value.toInt()));
            },
          ),
        ),

        /// ⏱ время
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_position)),
              Text(_formatDuration(_duration)),
            ],
          ),
        ),
      ],
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
      // Для writing B2/C1 показываем DailyLimitScreen
      if (widget.subTestId == 'writing' && _isAiEssayLevel) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DailyLimitScreen()),
        );
        return;
      }

      // Для остальных разделов обычный экран результата
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QuizResultScreen(
            score: _score,
            totalQuestions: _tasks.length,
            writingMistakes: _writingMistakes,
            totalWritingGaps: _totalWritingGaps,
            correctWritingGaps: _correctWritingGaps,
            isAdvancedWriting:
                widget.subTestId == 'writing' && _isGapWritingLevel,
            isEssayLevel: widget.subTestId == 'writing' && _isAiEssayLevel,
          ),
        ),
      );
    }
  }

  Widget _buildBottomAction(QuizTask task) {
    if (task.type == 'speaking') {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: const StadiumBorder(),
            ),
            onPressed: _hasUserRecording ? _nextQuestion : null,
            child: Text(
              "next".tr(),
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

    if (task.type == 'writing') {
      if (_isAiEssayLevel) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: (_isCheckingEssay ||
                          _isLoadingAiUsage ||
                          _remainingAiChecks <= 0)
                      ? null
                      : () async {
                          FocusScope.of(context).unfocus();

                          final currentTask = _tasks[_currentIndex];

                          bool canUseAi = true;

                          // if (_isAiEssayLevel) {
                          //   canUseAi = await _aiUsageService.canUseAi(
                          //     topicId: currentTask.id,
                          //   );
                          // }

                          // if (!canUseAi &&
                          //     widget.subTestId == 'writing' &&
                          //     _isAiEssayLevel) {
                          //       if (!mounted) return;
                          //   Navigator.push(
                          //     context,
                          //     MaterialPageRoute(
                          //       builder: (_) => const DailyLimitScreen(),
                          //     ),
                          //   );
                          //   return;
                          // }
                          await _checkEssayWithAi();
                        },
                  child: _isCheckingEssay
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'check_with_ai'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              if (_essayChecked) ...[
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _nextQuestion,
                    child: Text(
                      'next'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }

      if (_isGapWritingLevel) {
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
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((
                  states,
                ) {
                  if (_isWritingAnswered) {
                    return isCorrect ? Colors.green : Colors.red;
                  }
                  return Colors.green;
                }),
                shape: WidgetStateProperty.all(const StadiumBorder()),
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
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((
                  states,
                ) {
                  if (_isSentenceAnswered) {
                    return isCorrect ? Colors.green : Colors.red;
                  }
                  return Colors.green;
                }),
                shape: WidgetStateProperty.all(const StadiumBorder()),
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
