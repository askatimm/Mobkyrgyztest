import 'package:cloud_functions/cloud_functions.dart';
import '../models/essay_review.dart';

class AiWritingService {
  final FirebaseFunctions _functions =
    FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<EssayReview> checkEssay({
    required String essay,
    required String targetLevel,
    String topic = '',
  }) async {
    final callable = _functions.httpsCallable('checkEssay');

    final result = await callable.call({
      'essay': essay,
      'targetLevel': targetLevel,
      'topic': topic,
    });

    final data = Map<String, dynamic>.from(result.data as Map);
    return EssayReview.fromMap(data);
  }
}