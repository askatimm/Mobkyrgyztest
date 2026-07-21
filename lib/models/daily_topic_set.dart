class DailyTopicSet {
  final String date;
  final List<String> taskIds;

  DailyTopicSet({
    required this.date,
    required this.taskIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'taskIds': taskIds,
    };
  }

  factory DailyTopicSet.fromMap(Map<String, dynamic> map) {
    return DailyTopicSet(
      date: map['date'] ?? '',
      taskIds: List<String>.from(map['taskIds'] ?? []),
    );
  }
}