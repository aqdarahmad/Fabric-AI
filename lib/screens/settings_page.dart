import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/auth_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _factoryNameController = TextEditingController();
  final _inspectorNameController = TextEditingController();
  final _piIpController = TextEditingController();

  double _aiConfidence = 35.0;
  late Box _myBox;

  @override
  void initState() {
    super.initState();
    _myBox = Hive.box('fabricBox');
    _loadSettings();
  }

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
      _piIpController.text = _myBox.get('piIp', defaultValue: '192.168.1.197');
      _aiConfidence = _myBox.get('aiConfidence', defaultValue: 35.0);
    });
  }

  void _saveSettings() {
    _myBox.put('factoryName', _factoryNameController.text.trim());
    _myBox.put('inspectorName', _inspectorNameController.text.trim());
    _myBox.put('piIp', _piIpController.text.trim());
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

  @override
  void dispose() {
    _factoryNameController.dispose();
    _inspectorNameController.dispose();
    _piIpController.dispose();
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
              onPressed: () async {
                try {
                  await AuthService.logout();
                  if (context.mounted) {
                    Navigator.pop(context);
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error logging out: $e')),
                    );
                  }
                }
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

  void _deleteAccount() async {
    try {
      await AuthService.deleteAccount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account has been permanently deleted.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
          // 1. إعدادات الذكاء الاصطناعي
          _buildSectionTitle('AI Configuration'),
          Container(
            decoration: _buildCardDecoration(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'AI Sensitivity',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
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
                    overlayColor: const Color(0xFFE91E63).withOpacity(0.2),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _aiConfidence,
                    min: 10,
                    max: 90,
                    divisions: 16,
                    onChanged: (value) => setState(() => _aiConfidence = value),
                  ),
                ),
                Text(
                  'Higher value reduces false defect alarms.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. معلومات المصنع والرازبري
          _buildSectionTitle('Factory & Hardware Settings'),
          Container(
            decoration: _buildCardDecoration(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildTextField(
                  controller: _factoryNameController,
                  label: 'Factory Name',
                  hint: 'Appears on PDF reports',
                  icon: Icons.factory_rounded,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _inspectorNameController,
                  label: 'Inspector Name',
                  hint: 'E.g. Baraa Zakarna',
                  icon: Icons.badge_rounded,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _piIpController,
                  label: 'Raspberry Pi IP Address',
                  hint: 'E.g. 10.190.202.156',
                  icon: Icons.settings_ethernet,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. قسم الحساب الفعلي
          _buildSectionTitle('Account'),
          Container(
            decoration: _buildCardDecoration(),
            child: Column(
              children: [
                _buildSettingTile(
                  Icons.person_outline_rounded,
                  'Logged in as',
                  AuthService.email ?? 'Not Logged In',
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

          // زر حفظ التغييرات
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

          // زر تسجيل الخروج
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
  // الودجتس المساعدة
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
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20, color: Colors.grey[600]),
            filled: true,
            fillColor: Colors.grey[50],
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
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone and you will lose all access to your fabric reports.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteAccount();
              },
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
