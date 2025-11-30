import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'level_detail_screen.dart'; // 👈 Этот мы используем

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

  // 💡 Создадим список страниц для BottomNavigationBar
  //    (пока у нас только одна, но это для будущего)
  static final List<Widget> _widgetOptions = <Widget>[
    HomeContent(), // 👈 Мы вынесли контент в отдельный виджет
    Center(
      // 3. ❗ СТРАНИЦА "НАСТРОЙКИ" (пока заглушка)
      //    Мы используем ключ 'nav_settings' из JSON
      child: Text('nav_settings'.tr(), style: TextStyle(fontSize: 30)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.school),
            // 4. ❗ ПЕРЕВОДИМ ТЕКСТ
            label: 'nav_home'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            // 5. ❗ ПЕРЕВОДИМ ТЕКСТ
            label: 'nav_settings'.tr(),
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey.shade600,
        onTap: _onItemTapped,
        // 💡 Теперь мы можем показывать лейблы, т.к. они переводятся
        showSelectedLabels: true,
        showUnselectedLabels: true,
        backgroundColor: Colors.grey.shade200,
      ),
      // 6. ❗ Показываем нужный виджет из списка
      body: _widgetOptions.elementAt(_selectedIndex),
    );
  }
}

// -----------------------------------------------------------------
// 💡 Виджет с основным контентом (заголовок + кнопки)
//    Мы вынесли его из Scaffold, чтобы он был частью списка _widgetOptions
// -----------------------------------------------------------------
class HomeContent extends StatelessWidget {
  const HomeContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        // Используем Expanded, чтобы кнопки
        // занимали оставшееся место и скроллились
        Expanded(child: SingleChildScrollView(child: _buildLevelGrid(context))),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 25),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 74, 191, 237).withOpacity(0.6),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.elliptical(250, 100),
        ),
      ),
      child: Text(
        'app_title'.tr(), 
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildLevelGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: LevelButton(
                  level: "A1",
                  color: Colors.orange.shade400,
                  onTap: () {
                
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        // Мы передаем 'level_a1' как ID,
                        // который совпадает с ключом в JSON
                        builder: (context) =>
                            const LevelDetailScreen(levelId: 'level_a1'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: LevelButton(
                  level: "A2",
                  color: Colors.yellow.shade700,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const LevelDetailScreen(levelId: 'level_a2'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: LevelButton(
                  level: "B1",
                  color: Colors.green.shade400,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const LevelDetailScreen(levelId: 'level_b1'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: LevelButton(
                  level: "B2",
                  color: Colors.green.shade700,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const LevelDetailScreen(levelId: 'level_b2'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LevelButton(
            level: "C1",
            color: Colors.red.shade400,
            isWide: true,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      const LevelDetailScreen(levelId: 'level_c1'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class LevelButton extends StatelessWidget {
  const LevelButton({
    super.key,
    required this.level,
    required this.color,
    required this.onTap,
    this.isWide = false,
  });

  final String level;
  final Color color;
  final bool isWide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // весь код LevelButton
    double height = isWide ? 100 : 120;
    double? width = isWide ? double.infinity : null;

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        elevation: 3.0,
        shadowColor: Colors.black.withOpacity(0.3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              level,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
