import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'settings_page.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyController = TextEditingController();

  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _nameController.text = user?.displayName ?? '';
    _emailController.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _saveProfile() async {
    try {
      await user?.updateDisplayName(_nameController.text.trim());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Widget _card(Widget child) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Profile"),
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsPage(),
                ),
              );
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [

            const SizedBox(height: 20),

            _card(
              Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFFE91E63).withOpacity(0.1),
                    child: const Icon(Icons.person, size: 50),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    user?.displayName ?? "User",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Text(user?.email ?? ""),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _card(
              Column(
                children: [
                  _field(
                    controller: _nameController,
                    label: "Full Name",
                    icon: Icons.person,
                    hint: "Enter your name",
                  ),

                  const SizedBox(height: 12),

                  _field(
                    controller: _emailController,
                    label: "Email",
                    icon: Icons.email,
                    hint: "Enter email",
                  ),

                  const SizedBox(height: 12),

                  _field(
                    controller: _phoneController,
                    label: "Phone",
                    icon: Icons.phone,
                    hint: "Enter phone",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [

                  ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E63),
                      minimumSize: const Size(double.infinity, 55),
                    ),
                    child: const Text("Save Changes"),
                  ),

                  const SizedBox(height: 10),

                  OutlinedButton(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      minimumSize: const Size(double.infinity, 55),
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text("Logout"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}