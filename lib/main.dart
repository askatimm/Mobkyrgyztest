import 'dart:async'; // Для работы со стримами
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Не забудьте добавить в pubspec.yaml
import 'splash_screen.dart';
import 'firebase_options.dart';
import 'services/premium_service.dart';
import 'home_screen.dart';
import 'preview/design_preview.dart';
import 'widgets/video_design.dart';

// 1. Глобальный ключ для доступа к SnackBar из любой точки приложения
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Блокируем ориентацию
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await EasyLocalization.ensureInitialized();
  if (!DesignPreview.enabled) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await PremiumService.init();
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ky'), Locale('ru')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ru'),
      startLocale: DesignPreview.enabled ? const Locale('ky') : null,
      saveLocale: !DesignPreview.enabled,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    // 2. Запускаем глобальный слушатель интернета
    if (DesignPreview.enabled) return;
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (results.contains(ConnectivityResult.none)) {
        _showGlobalNoInternetSnackBar();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 3. Отменяем подписку при закрытии приложения
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !DesignPreview.enabled) {
      unawaited(PremiumService.syncUserWithRevenueCat(forceRefresh: true));
    }
  }

  // Функция для показа SnackBar через глобальный ключ
  void _showGlobalNoInternetSnackBar() {
    scaffoldMessengerKey.currentState
        ?.clearSnackBars(); // Убираем старые сообщения
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text("no_internet".tr()), // Текст подтянется из JSON
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 4. ПРИВЯЗЫВАЕМ КЛЮЧ
      scaffoldMessengerKey: scaffoldMessengerKey,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      debugShowCheckedModeBanner: false,
      title: 'KyrgyzTest',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: LearningColors.blue),
        scaffoldBackgroundColor: LearningColors.background,
        useMaterial3: true, // Рекомендуется для современного дизайна
      ),
      home: DesignPreview.enabled
          ? const HomeScreen(initialIndex: DesignPreview.initialTab)
          : const SplashScreen(),
    );
  }
}
