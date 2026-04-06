class EssayMistake {
  final String original;
  final String corrected;
  final String category;
  final String explanation;

  EssayMistake({
    required this.original,
    required this.corrected,
    required this.category,
    required this.explanation,
  });

  factory EssayMistake.fromMap(Map<String, dynamic> map) {
    return EssayMistake(
      original: (map['original'] ?? '').toString(),
      corrected: (map['corrected'] ?? '').toString(),
      category: (map['category'] ?? '').toString(),
      explanation: (map['explanation'] ?? '').toString(),
    );
  }
}

class EssayReview {
  final int score;
  final String level;
  final String summary;
  final String correctedText;
  final String topicRelevance;
  final int topicScore;
  final String topicComment;
  final List<EssayMistake> mistakes;

  EssayReview({
    required this.score,
    required this.level,
    required this.summary,
    required this.correctedText,
    required this.topicRelevance,
    required this.topicScore,
    required this.topicComment,
    required this.mistakes,
  });

  factory EssayReview.fromMap(Map<String, dynamic> map) {
    return EssayReview(
      score: (map['score'] ?? 0) is int
          ? map['score'] as int
          : int.tryParse(map['score'].toString()) ?? 0,
      level: (map['level'] ?? '').toString(),
      summary: (map['summary'] ?? '').toString(),
      correctedText: (map['correctedText'] ?? '').toString(),
      topicRelevance: (map['topicRelevance'] ?? '').toString(),
      topicScore: (map['topicScore'] ?? 0) is int
          ? map['topicScore'] as int
          : int.tryParse(map['topicScore'].toString()) ?? 0,
      topicComment: (map['topicComment'] ?? '').toString(),
      mistakes: (map['mistakes'] as List<dynamic>? ?? [])
          .map((e) => EssayMistake.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}