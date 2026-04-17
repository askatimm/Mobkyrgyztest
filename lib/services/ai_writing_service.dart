import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import '../models/essay_review.dart';

class AiWritingService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  Future<EssayReview> checkEssay({
    required BuildContext context,
    required String essay,
    required String targetLevel,
    String topic = '',
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'checkEssay',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 60),
        ),
      );

      final uiLanguage = context.locale.languageCode;

      final result = await callable.call({
        'essay': essay,
        'targetLevel': targetLevel,
        'topic': topic,
        'uiLanguage': uiLanguage,
      });

      final data = Map<String, dynamic>.from(result.data as Map);

      return EssayReview.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      final code = e.code;
      final message = (e.message ?? '').toLowerCase();

      // 429 Too Many Requests
      if (code == 'resource-exhausted' ||
          message.contains('429') ||
          message.contains('quota') ||
          message.contains('too many requests')) {
        throw Exception(
          'Сурамдар өтө көп болуп жатат. 1-2 мүнөттөн кийин кайра аракет кылыңыз.',
        );
      }

      // 404 Model not found / endpoint not found
      if (code == 'not-found' ||
          message.contains('404') ||
          message.contains('model not found') ||
          message.contains('not found')) {
        throw Exception(
          'AI модели убактылуу жеткиликсиз. Кийинчерээк кайра аракет кылыңыз.',
        );
      }

      // 503 / unavailable
      if (code == 'unavailable' ||
          message.contains('503') ||
          message.contains('unavailable') ||
          message.contains('high demand')) {
        throw Exception(
          'AI азыр бош эмес. Бир аздан кийин кайра аракет кылыңыз.',
        );
      }

      // Timeout
      if (code == 'deadline-exceeded' ||
          message.contains('timeout') ||
          message.contains('deadline')) {
        throw Exception(
          'Сервер өтө жай жооп берип жатат. Кайра аракет кылыңыз.',
        );
      }

      // Network / internet
      if (code == 'internal' &&
          (message.contains('network') ||
              message.contains('socket') ||
              message.contains('connection'))) {
        throw Exception(
          'Интернет байланышы көйгөйлүү болуп жатат. Тармакты текшерип кайра аракет кылыңыз.',
        );
      }

      // Default
      throw Exception(
        'Эссени текшерүүдө ката кетти. Кийинчерээк кайра аракет кылыңыз.',
      );
    } catch (e) {
      throw Exception(
        'Эссени текшерүү мүмкүн болгон жок. Кайра аракет кылыңыз.',
      );
    }
  }
}