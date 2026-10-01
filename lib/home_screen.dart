import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'level_detail_screen.dart';
import 'settings_screen.dart';
import 'video_lessons_screen.dart';
import 'preview/design_preview.dart';
import 'widgets/video_design.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final Set<int> _visitedIndexes = {0};

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 2).toInt();
    _visitedIndexes.add(_selectedIndex);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _visitedIndexes.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    context.locale;

    final widgetOptions = <Widget>[
      const HomeContent(),
      _visitedIndexes.contains(1)
          ? const VideoLessonsScreen()
          : const SizedBox.shrink(),
      _visitedIndexes.contains(2)
          ? const SettingsScreen()
          : const SizedBox.shrink(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _selectedIndex, children: widgetOptions),
      bottomNavigationBar: _BubbleBottomBar(
        selectedIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class _BubbleBottomBar extends StatelessWidget {
  const _BubbleBottomBar({required this.selectedIndex, required this.onTap});
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => SafeArea(top: false,
    child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: LearningColors.navy.withValues(alpha: 0.08),
              blurRadius: 24, offset: const Offset(0, 4))],
          border: Border.all(color: LearningColors.border),
        ),
        child: Row(children: [
          for (var index = 0; index < 3; index++)
            Expanded(child: _BottomBarItem(
              icon: [Icons.home_rounded, Icons.play_circle_outline_rounded,
                  Icons.settings_outlined][index],
              label: ['nav_home', 'nav_video', 'nav_settings'][index].tr(),
              selected: index == selectedIndex, onTap: () => onTap(index),
            )),
        ]),
      ),
    ),
  );
}

class _BottomBarItem extends StatelessWidget {
  const _BottomBarItem({required this.icon, required this.label,
      required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(selected: selected,
    button: true, label: label, excludeSemantics: true,
    child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(18),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(color: selected ? const Color(0xFFE7EFF9) : Colors.transparent,
              borderRadius: BorderRadius.circular(18)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 25, color: selected ? LearningColors.blue : LearningColors.muted),
            const SizedBox(height: 5),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? LearningColors.blue : LearningColors.muted)),
          ]),
        ),
      ),
    ),
  );
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
                  if (DesignPreview.enabled) ...[
                    const DesignPreviewNotice(),
                    const SizedBox(height: 16),
                  ],
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
