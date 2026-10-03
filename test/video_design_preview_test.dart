import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kyrgyztestapp/home_screen.dart';
import 'package:kyrgyztestapp/preview/design_preview.dart';
import 'package:kyrgyztestapp/video_lessons_screen.dart';

// Use the production translation files, while avoiding real asynchronous file
// I/O inside the widget test's fake clock.
class _PreviewAssetLoader extends AssetLoader {
  const _PreviewAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}

Future<void> mountPreview(WidgetTester tester, {
  String language = 'ky', double width = 390, double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(EasyLocalization(
    key: ValueKey('preview-$language-$width-$scale'),
    assetLoader: const _PreviewAssetLoader(),
    supportedLocales: const [Locale('ky'), Locale('ru')],
    path: 'assets/translations', startLocale: Locale(language),
    fallbackLocale: const Locale('ru'), saveLocale: false,
    child: Builder(builder: (context) => MaterialApp(
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales, locale: context.locale,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const HomeScreen(initialIndex: 1),
    )),
  ));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('video-sphere')), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('sphere changes reset the dependent section picker', (tester) async {
    await mountPreview(tester);
    await tester.tap(find.byKey(const ValueKey('video-sphere')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('video-sphere-option-professional')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('video-section')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('video-section-option-greeting')), findsNothing);
    expect(find.byKey(const ValueKey('video-section-option-workplace')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('video-section-option-meeting')));
    await tester.pumpAndSettle();
    expect(find.text('Иш жолугушуусу: алгачкы кадам'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('video-level-B2')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Жумуш ордунда: алгачкы кадам'), 150,
      scrollable: find.descendant(of: find.byType(VideoLessonsScreen),
        matching: find.byType(Scrollable)).first);
    expect(find.text('Жумуш ордунда: алгачкы кадам'), findsOneWidget);
    expect(find.textContaining('B2 ·'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, skip: !DesignPreview.enabled);

  testWidgets('preview opens the player and the next lesson without Firebase', (tester) async {
    await mountPreview(tester);
    final start = find.text('Сабакты баштоо');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.text('Демо · плеердин дизайны'), findsOneWidget);
    final next = find.text('Кийинки сабак');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Саламдашуу: диалог'), findsWidgets);
    expect(tester.takeException(), isNull);
  }, skip: !DesignPreview.enabled);

  testWidgets('all three main tabs work without a signed-in account', (tester) async {
    await mountPreview(tester);
    await tester.tap(find.text('Орнотуулар'));
    await tester.pumpAndSettle();
    expect(find.text('Демо-профиль'), findsOneWidget);
    await tester.tap(find.text('Башкы бет'));
    await tester.pumpAndSettle();
    expect(find.text('Кыргызтест'), findsWidgets);
    await tester.tap(find.text('Видео'));
    await tester.pumpAndSettle();
    expect(find.text('Видео сабактар'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, skip: !DesignPreview.enabled);

  for (final width in [320.0, 390.0, 768.0]) {
    for (final language in ['ky', 'ru']) {
      for (final scale in [1.0, 1.6]) {
        testWidgets('video layout: $language, ${width}px, ${scale}x text', (tester) async {
          await mountPreview(tester, width: width, language: language, scale: scale);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const ValueKey('video-sphere')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }, skip: !DesignPreview.enabled);
      }
    }
  }
}
