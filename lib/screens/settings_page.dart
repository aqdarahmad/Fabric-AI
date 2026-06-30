import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Box _myBox;

  String _selectedLanguage = 'English';
  String _themeMode = 'light'; // 👈 مهم جداً

  @override
  void initState() {
    super.initState();
    _myBox = Hive.box('fabricBox');

    _selectedLanguage = _myBox.get('language', defaultValue: 'English');
    _themeMode = _myBox.get('themeMode', defaultValue: 'light');
  }

  void _saveTheme(String value) {
    setState(() => _themeMode = value);
    _myBox.put('themeMode', value);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Theme updated")),
    );
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("Light Mode"),
              trailing: _themeMode == 'light'
                  ? const Icon(Icons.check, color: Colors.pink)
                  : null,
              onTap: () {
                _saveTheme('light');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text("Dark Mode"),
              trailing: _themeMode == 'dark'
                  ? const Icon(Icons.check, color: Colors.pink)
                  : null,
              onTap: () {
                _saveTheme('dark');
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("English"),
              onTap: () {
                setState(() => _selectedLanguage = 'English');
                _myBox.put('language', 'English');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text("العربية"),
              onTap: () {
                setState(() => _selectedLanguage = 'العربية');
                _myBox.put('language', 'العربية');
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),

      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text("Language"),
            subtitle: Text(_selectedLanguage),
            onTap: _showLanguagePicker,
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text("Theme"),
            subtitle: Text(_themeMode),
            onTap: _showThemePicker,
          ),
        ],
      ),
    );
  }
}