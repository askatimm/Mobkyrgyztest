import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'level_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  static final List<Widget> _widgetOptions = <Widget>[
    const HomeContent(),
    // Заглушка для экрана настроек
    Center(
      child: Text(
        'nav_settings'.tr(),
        style: const TextStyle(fontSize: 30),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        elevation: 0,
        backgroundColor: Colors.white.withValues(alpha: 1),
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.school),
            label: 'nav_home'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: 'nav_settings'.tr(),
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey.shade600,
        onTap: _onItemTapped,
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    // Высота квадратных карточек (A1-B2)
    const double squareHeight = 160; 
    // Высота широкой карточки (C1)
    const double wideHeight = 110;
    const double gap = 16;

    return Stack(
      children: [
        /// 1. ФОНОВОЕ ИЗОБРАЖЕНИЕ
        Positioned.fill(
          child: Image.asset(
            'assets/images/mountains_bg.png',
            fit: BoxFit.cover,
          ),
        ),

        /// 2. КОНТЕНТ
        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  /// ЗАГОЛОВОК
                  const Text(
                    'Кыргызтест',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: 1.2,
                    ),
                  ),

                  const SizedBox(height: 8),

                  /// ПОДЗАГОЛОВОК (из JSON)
                  Text(
                    'app_subtitle'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                  ),

                  const SizedBox(height: 40),

                  /// СЕТКА КАРТ
                  Row(
                    children: [
                      Expanded(
                        child: _buildLevelCard(
                          context,
                          imagePath: 'assets/images/level_a1.png',
                          title: 'levels.a1'.tr(),
                          levelId: 'level_a1',
                          height: squareHeight,
                        ),
                      ),
                      SizedBox(width: gap),
                      Expanded(
                        child: _buildLevelCard(
                          context,
                          imagePath: 'assets/images/level_a2.png',
                          title: 'levels.a2'.tr(),
                          levelId: 'level_a2',
                          height: squareHeight,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: gap),

                  Row(
                    children: [
                      Expanded(
                        child: _buildLevelCard(
                          context,
                          imagePath: 'assets/images/level_b1.png',
                          title: 'levels.b1'.tr(),
                          levelId: 'level_b1',
                          height: squareHeight,
                        ),
                      ),
                      SizedBox(width: gap),
                      Expanded(
                        child: _buildLevelCard(
                          context,
                          imagePath: 'assets/images/level_b2.png',
                          title: 'levels.b2'.tr(),
                          levelId: 'level_b2',
                          height: squareHeight,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: gap),

                  _buildLevelCard(
                    context,
                    imagePath: 'assets/images/level_c1.png',
                    title: 'levels.c1'.tr(),
                    levelId: 'level_c1',
                    height: wideHeight,
                    isWide: true,
                  ),

                  const SizedBox(height: 120), // Отступ для BottomNav
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelCard(
    BuildContext context, {
    required String imagePath,
    required String title,
    required String levelId,
    required double height,
    bool isWide = false,
  }) {
    final borderRadius = BorderRadius.circular(20);

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LevelDetailScreen(levelId: levelId),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ИЗОБРАЖЕНИЕ (Сверху)
                Expanded(
                  flex: isWide ? 6 : 9, 
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => 
                        Container(color: Colors.grey.shade200),
                  ),
                ),
                
                // ТЕКСТОВЫЙ БЛОК (Теперь по центру)
                Expanded(
                  flex: isWide ? 2 : 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    // Центрируем содержимое контейнера
                    alignment: Alignment.center, 
                    child: Text(
                      title,
                      // Центрируем сам текст внутри виджета
                      textAlign: TextAlign.center, 
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}