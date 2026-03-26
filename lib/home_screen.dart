import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'level_detail_screen.dart';
import 'settings_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    context.locale;

    final List<Widget> widgetOptions = [
      const HomeContent(),
      const SettingsScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: _BubbleBottomBar(
        selectedIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class _BubbleBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _BubbleBottomBar({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _BottomBarItem(
                      icon: Icons.home_outlined,
                      label: 'nav_home'.tr(),
                      selected: selectedIndex == 0,
                      hideInside: selectedIndex == 0,
                      onTap: () => onTap(0),
                    ),
                  ),
                  Expanded(
                    child: _BottomBarItem(
                      icon: Icons.settings_outlined,
                      label: 'nav_settings'.tr(),
                      selected: selectedIndex == 1,
                      hideInside: selectedIndex == 1,
                      onTap: () => onTap(1),
                    ),
                  ),
                ],
              ),
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            bottom: 38,
            left: selectedIndex == 0
                ? MediaQuery.of(context).size.width * 0.25 - 34
                : MediaQuery.of(context).size.width * 0.75 - 34,
            child: GestureDetector(
              onTap: () => onTap(selectedIndex),
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 71, 174, 234),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: Icon(
                  selectedIndex == 0
                      ? Icons.home_outlined
                      : Icons.settings_outlined,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool hideInside;
  final VoidCallback onTap;

  const _BottomBarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.hideInside,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF7A3E7A) : Colors.grey.shade700;

    return InkWell(
      borderRadius: BorderRadius.circular(36),
      onTap: onTap,
      child: SizedBox(
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: hideInside ? Colors.transparent : color,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              hideInside ? '' : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    const double squareHeight = 170;
    const double wideHeight = 115;
    const double gap = 16;

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/mountain1.webp',
            fit: BoxFit.cover,
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
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
                  Text(
                    'app_subtitle'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 30),

                  Row(
                    children: [
                      Expanded(
                        child: _buildLevelCard(
                          context,
                          imagePath: 'assets/images/level_a1.webp',
                          title: 'levels.a1'.tr(),
                          levelId: 'level_a1',
                          height: squareHeight,
                        ),
                      ),
                      SizedBox(width: gap),
                      Expanded(
                        child: _buildLevelCard(
                          context,
                          imagePath: 'assets/images/level_b2.webp',
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
                          imagePath: 'assets/images/level_b1.webp',
                          title: 'levels.b1'.tr(),
                          levelId: 'level_b1',
                          height: squareHeight,
                        ),
                      ),
                      SizedBox(width: gap),
                      Expanded(
                        child: _buildLevelCard(
                          context,
                          imagePath: 'assets/images/level_a2.webp',
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
                    imagePath: 'assets/images/level_c1.webp',
                    title: 'levels.c1'.tr(),
                    levelId: 'level_c1',
                    height: wideHeight,
                    isWide: true,
                  ),
                  const SizedBox(height: 140),
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
                Expanded(
                  flex: isWide ? 5 : 7,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(color: Colors.grey.shade200),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        height: 1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
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