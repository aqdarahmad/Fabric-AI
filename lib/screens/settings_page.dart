import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _factoryNameController = TextEditingController();
  final _inspectorNameController = TextEditingController();
  double _aiConfidence = 35.0;
  late Box _myBox;

  // 🟢 المتغير السحري لتحديد رتبة المستخدم الحالية ('admin' أو 'worker')
  String _userRole = 'worker';
  String _selectedLanguage = 'English';

  @override
  void initState() {
    super.initState();
    _myBox = Hive.box('fabricBox');
    _loadSettings();
  }

  // تحميل الإعدادات والرتبة من الـ Hive
  void _loadSettings() {
    setState(() {
      _factoryNameController.text = _myBox.get(
        'factoryName',
        defaultValue: 'Fabric Check Factory',
      );
      _inspectorNameController.text = _myBox.get(
        'inspectorName',
        defaultValue: 'Baraa Zakarna',
      );
      _aiConfidence = _myBox.get('aiConfidence', defaultValue: 35.0);
      _userRole = _myBox.get(
        'userRole',
        defaultValue: 'worker',
      ); // قراءة الرتبة
    });
  }

  // حفظ الإعدادات
  void _saveSettings() {
    _myBox.put('factoryName', _factoryNameController.text.trim());
    _myBox.put('inspectorName', _inspectorNameController.text.trim());
    _myBox.put('aiConfidence', _aiConfidence);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }

  // تبديل الرتبة للتجربة أمام لجنة المناقشة (Demo Switcher)
  Future<void> _toggleRoleDemo() async {
    String newRole = _userRole == 'admin' ? 'worker' : 'admin';
    await _myBox.put('userRole', newRole);
    setState(() {
      _userRole = newRole;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🔒 Role switched to: ${newRole.toUpperCase()} (Demo Mode)',
        ),
        backgroundColor: Colors.blueAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _factoryNameController.dispose();
    _inspectorNameController.dispose();
    super.dispose();
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = _userRole == 'admin';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 👨‍✈️ أولاً: بطاقة المستخدم الفخمة مع شارة الرتبة الملونة
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _buildCardDecoration(),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: isAdmin
                      ? Colors.green[100]
                      : Colors.blue[100],
                  child: Icon(
                    isAdmin ? Icons.admin_panel_settings : Icons.person,
                    size: 32,
                    color: isAdmin ? Colors.green[800] : Colors.blue[800],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _inspectorNameController.text,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // شارة الرتبة الملونة الذكية
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isAdmin ? Colors.green[50] : Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isAdmin ? Colors.green : Colors.blue,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isAdmin
                              ? "👨‍✈️ SUPERVISOR / ADMIN"
                              : "👷 INSPECTOR / WORKER",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isAdmin
                                ? Colors.green[800]
                                : Colors.blue[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 🛠️ ميزة العرض التوضيحي السحرية أمام اللجنة للتبديل السريع بين الرتب
          _buildSectionTitle('Demo Controls (For Presentation)'),
          Container(
            decoration: _buildCardDecoration(),
            child: ListTile(
              leading: const Icon(
                Icons.swap_horizontal_circle,
                color: Colors.blueAccent,
              ),
              title: const Text(
                "Switch Role (For Demo)",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                "Current: ${_userRole.toUpperCase()}",
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: _toggleRoleDemo,
            ),
          ),
          const SizedBox(height: 20),

          // 🟢 القسم الأول: إعدادات الذكاء الاصطناعي (مغلقة للعمال، مفتوحة للمشرفين)
          _buildSectionTitle('AI Configuration'),
          Opacity(
            opacity: isAdmin ? 1.0 : 0.6, // تظليل الخيار للعمال لتبدو مقفلة
            child: Container(
              decoration: _buildCardDecoration(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'AI Sensitivity',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!isAdmin) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.lock,
                              color: Colors.amber,
                              size: 18,
                            ), // رمز القفل الذكي للعمال
                          ],
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_aiConfidence.toInt()}%',
                          style: const TextStyle(
                            color: Color(0xFFE91E63),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: const Color(0xFFE91E63),
                      inactiveTrackColor: const Color(
                        0xFFE91E63,
                      ).withOpacity(0.2),
                      thumbColor: const Color(0xFFE91E63),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: _aiConfidence,
                      min: 10,
                      max: 90,
                      divisions: 16,
                      onChanged: isAdmin
                          ? (value) => setState(() => _aiConfidence = value)
                          : null, // تعطيل السلايدر للعمال
                    ),
                  ),
                  Text(
                    isAdmin
                        ? 'Higher value reduces false defect alarms.'
                        : '🔒 Locked: Only supervisors can modify AI sensitivity.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isAdmin ? Colors.grey[600] : Colors.amber[900],
                      fontWeight: isAdmin ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 🟢 القسم الثاني: إعدادات التقارير والـ PDF (مغلقة للعمال، مفتوحة للمشرفين)
          _buildSectionTitle('Factory Information'),
          Opacity(
            opacity: isAdmin ? 1.0 : 0.6,
            child: Container(
              decoration: _buildCardDecoration(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTextField(
                    controller: _factoryNameController,
                    label: 'Factory Name',
                    hint: 'Appears on PDF reports',
                    icon: Icons.factory_rounded,
                    enabled: isAdmin, // تعطيل الكتابة للعمال
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _inspectorNameController,
                    label: 'Inspector Name',
                    hint: 'E.g. Baraa Zakarna',
                    icon: Icons.badge_rounded,
                    enabled: isAdmin, // تعطيل الكتابة للعمال
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 🔵 القسم الثالث: تفضيلات التطبيق (من تصميمك)
          _buildSectionTitle('App Preferences'),
          Container(
            decoration: _buildCardDecoration(),
            child: Column(
              children: [
                _buildSettingTile(
                  Icons.language_rounded,
                  'Language',
                  _selectedLanguage,
                  () => _showLanguagePicker(),
                ),
                _buildDivider(),
                _buildSettingTile(
                  Icons.dark_mode_outlined,
                  'Theme',
                  'Light',
                  () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 🔵 القسم الرابع: القانونية والحساب (من تصميمك)
          _buildSectionTitle('Account & Legal'),
          Container(
            decoration: _buildCardDecoration(),
            child: Column(
              children: [
                _buildSettingTile(
                  Icons.privacy_tip_outlined,
                  'Privacy Policy',
                  'Read our privacy policy',
                  () {},
                ),
                _buildDivider(),
                _buildSettingTile(
                  Icons.delete_outline_rounded,
                  'Delete Account',
                  'Permanently delete your data',
                  () => _showDeleteAccountDialog(),
                  textColor: Colors.red,
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // 🟢 زر حفظ التعديلات (يظهر فقط إذا كان مشرفاً Admin)
          if (isAdmin) ...[
            ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 55),
                elevation: 0,
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 🔵 زر تسجيل الخروج
          OutlinedButton(
            onPressed: _logout,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 55),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded),
                SizedBox(width: 8),
                Text(
                  'Logout',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ==========================================
  // 🎨 الودجتس المساعدة
  // ==========================================

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      ),
    );
  }

  BoxDecoration _buildCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool enabled, // متغير التحكم بالقفل
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled, // تفعيل أو قفل الكتابة
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20, color: Colors.grey[600]),
            filled: true,
            fillColor: enabled
                ? Colors.grey[50]
                : Colors.grey[200], // تظليل الحقل المقفل
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE91E63), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    Color? textColor,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (textColor ?? const Color(0xFFE91E63)).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: textColor ?? const Color(0xFFE91E63),
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: textColor ?? Colors.grey,
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, color: Colors.grey[100]);
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Language',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildLanguageOption('English'),
              _buildLanguageOption('العربية'),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(String language) {
    return ListTile(
      title: Text(language),
      trailing: _selectedLanguage == language
          ? const Icon(Icons.check_circle, color: Color(0xFFE91E63))
          : null,
      onTap: () {
        setState(() => _selectedLanguage = language);
        Navigator.pop(context);
      },
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Account',
            style: TextStyle(color: Colors.red),
          ),
          content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
