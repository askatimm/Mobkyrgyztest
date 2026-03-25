import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _userName = "User";
  bool _isSoundEnabled = true;
  String _avatarPath = 'assets/images/avatar_1.jpeg';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _userName = prefs.getString('user_name') ?? "User";
      _isSoundEnabled = prefs.getBool('test_sound') ?? true;
      _avatarPath = prefs.getString('avatar_path') ?? 'assets/images/avatar_1.jpeg';
    });
  }

  Future<void> _saveSoundSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('test_sound', value);
    setState(() => _isSoundEnabled = value);
  }

  void _editName() {
    final controller = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("edit_name".tr()),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: "enter_name".tr()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("cancel".tr())),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('user_name', controller.text);
              if (!mounted) return;
              setState(() => _userName = controller.text);
              Navigator.pop(context);
            },
            child: Text("save".tr()),
          ),
        ],
      ),
    );
  }

  void _changeAvatar() {
    final avatars = [
      'assets/images/avatar_1.jpeg',
      'assets/images/avatar_2.jpeg',
      'assets/images/avatar_3.jpeg',
    ];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("avatar".tr()),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: avatars.map((path) {
            return GestureDetector(
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('avatar_path', path);
                if (!mounted) return;
                setState(() => _avatarPath = path);
                Navigator.pop(context);
              },
              child: CircleAvatar(radius: 32, backgroundImage: AssetImage(path)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _sendFeedback() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'info@kyrgyztest.gov.kg',
      query: 'subject=Feedback&body=Описание проблемы:',
    );
    await launchUrl(uri);
  }

  Widget _settingsContainer(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 215, 218, 243).withValues(alpha: 0.95), // Сделали контейнеры чуть прозрачными
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Прозрачный AppBar, чтобы фон был виден под ним
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("settings".tr()),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/bg_sett.png'), // Ваш фоновый рисунок
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.white.withValues(alpha: 0.35), 
              BlendMode.lighten
            ),
          ),
        ),
        child: SafeArea( // Используем SafeArea внутри контейнера, чтобы контент не залезал под челку
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 24),

                /// ===== PROFILE =====
                CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage(_avatarPath),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () {
                    _editName();
                    // Чтобы одновременно менять имя и аватар, можно вызвать по очереди 
                    // или объединить в одно окно
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(
                    _userName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                // Кнопка смены аватара отдельно для удобства
                TextButton(
                  onPressed: _changeAvatar,
                  child: Text("avatar".tr()), 
                ),

                /// ===== LANGUAGE + SOUND =====
                _settingsContainer([
                  ListTile(
                    leading: const Icon(Icons.language, color: Colors.blueAccent),
                    title: Text("language".tr()),
                    subtitle: Text(
                      context.locale.languageCode == 'ky' ? "Кыргызча" : "Русский",
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      if (context.locale.languageCode == 'ru') {
                        await context.setLocale(const Locale('ky'));
                      } else {
                        await context.setLocale(const Locale('ru'));
                      }
                      setState(() {});
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.volume_up, color: Colors.blueAccent),
                    title: Text("sound_in_tests".tr()),
                    value: _isSoundEnabled,
                    onChanged: _saveSoundSetting,
                  ),
                ]),

                /// ===== OTHER SETTINGS =====
                _settingsContainer([
                  ListTile(
                    leading: const Icon(Icons.feedback_outlined, color: Colors.blueAccent),
                    title: Text("feedback".tr()),
                    onTap: _sendFeedback,
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.phone_android, color: Colors.blueAccent),
                    title: Text("+996 (555) 00-06-61"),
                    subtitle: Text("Support Number"),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}