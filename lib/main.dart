import 'dart:async'; // Для работы со стримами
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Не забудьте добавить в pubspec.yaml
import 'splash_screen.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ky'), Locale('ru')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ru'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    // 2. Запускаем глобальный слушатель интернета
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
    // 3. Отменяем подписку при закрытии приложения
    _connectivitySubscription?.cancel();
    super.dispose();
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
        primarySwatch: Colors.blue,
        useMaterial3: true, // Рекомендуется для современного дизайна
      ),
      home: const SplashScreen(),
    );
  }
}
