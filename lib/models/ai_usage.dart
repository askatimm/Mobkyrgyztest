class AiUsage {
  final int usedChecks;
  final int maxChecks;
  final bool isPremium;
  final String topicId;
  final String userId;

  AiUsage({
    required this.usedChecks,
    required this.maxChecks,
    required this.isPremium,
    required this.topicId,
    required this.userId,
  });

  bool get canUseAi => usedChecks < maxChecks;

  int get remainingChecks {
    return (maxChecks - usedChecks).clamp(0, maxChecks).toInt();
  }

  factory AiUsage.fromMap(Map<String, dynamic> map) {
    return AiUsage(
      usedChecks: map['usedChecks'] ?? 0,
      maxChecks: map['maxChecks'] ?? 4,
      isPremium: map['isPremium'] ?? false,
      topicId: (map['topicId'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usedChecks': usedChecks,
      'maxChecks': maxChecks,
      'isPremium': isPremium,
      'topicId': topicId,
      'userId': userId,
    };
  }

  AiUsage copyWith({
    int? usedChecks,
    int? maxChecks,
    bool? isPremium,
    String? topicId,
    String? userId,
  }) {
    return AiUsage(
      usedChecks: usedChecks ?? this.usedChecks,
      maxChecks: maxChecks ?? this.maxChecks,
      isPremium: isPremium ?? this.isPremium,
      topicId: topicId ?? this.topicId,
      userId: userId ?? this.userId,
    );
  }
}