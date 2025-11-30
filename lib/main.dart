import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'splash_screen.dart';

// 1. ❗ Импортируйте Firebase Core
import 'package:firebase_core/firebase_core.dart';
// 2. ❗ Импортируйте ваш новый файл с ключами
import 'firebase_options.dart';

// 3. ❗ main() теперь должен быть 'async'
void main() async {
  // 4. ❗ Обязательные строки для Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 5. ❗ Обязательные строки для EasyLocalization
  await EasyLocalization.ensureInitialized();

  // 6. ❗ ИНИЦИАЛИЗАЦИЯ FIREBASE
  //    (Он будет использовать 'firebase_options.dart' автоматически)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ky'), Locale('ru')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ru'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      debugShowCheckedModeBanner: false, // 👈 (Как мы и делали)
      title: 'KyrgyzTest',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SplashScreen(),
    );
  }
}


