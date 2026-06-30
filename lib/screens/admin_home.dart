import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  late Box _myBox;

  final _factoryController = TextEditingController();
  final _inspectorController = TextEditingController();

  double _aiConfidence = 35;

  @override
  void initState() {
    super.initState();
    _myBox = Hive.box('fabricBox');

    _factoryController.text =
        _myBox.get('factoryName', defaultValue: 'Factory');
    _inspectorController.text =
        _myBox.get('inspectorName', defaultValue: 'Inspector');
    _aiConfidence = _myBox.get('aiConfidence', defaultValue: 35.0);
  }

  void _save() {
    _myBox.put('factoryName', _factoryController.text.trim());
    _myBox.put('inspectorName', _inspectorController.text.trim());
    _myBox.put('aiConfidence', _aiConfidence);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Settings saved successfully"),
        backgroundColor: Colors.green,
      ),
    );
  }

  BoxDecoration _card() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        title: const Text("Admin Panel"),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // 🔵 AI CONTROL
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "AI Control",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "Confidence: ${_aiConfidence.toInt()}%",
                  style: const TextStyle(color: Colors.grey),
                ),

                Slider(
                  value: _aiConfidence,
                  min: 10,
                  max: 90,
                  divisions: 16,
                  activeColor: Colors.pink,
                  onChanged: (v) => setState(() => _aiConfidence = v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 🟢 FACTORY INFO
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _card(),
            child: Column(
              children: [

                TextField(
                  controller: _factoryController,
                  decoration: InputDecoration(
                    labelText: "Factory Name",
                    prefixIcon: const Icon(Icons.factory),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                TextField(
                  controller: _inspectorController,
                  decoration: InputDecoration(
                    labelText: "Inspector Name",
                    prefixIcon: const Icon(Icons.badge),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // 💾 SAVE BUTTON
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Save Changes",
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
      drawer: Drawer(
  child: Column(
    children: [
      UserAccountsDrawerHeader(
        decoration: const BoxDecoration(
          color: Colors.pink,
        ),
        accountName: const Text("Admin Panel"),
        accountEmail: const Text("Control Dashboard"),
        currentAccountPicture: const CircleAvatar(
          child: Icon(Icons.admin_panel_settings, size: 30),
        ),
      ),

      ListTile(
        leading: const Icon(Icons.home),
        title: const Text("Home"),
        onTap: () {
          Navigator.pushReplacementNamed(context, '/adminHome');
        },
      ),

      ListTile(
        leading: const Icon(Icons.dashboard),
        title: const Text("Dashboard"),
        onTap: () {
          Navigator.pushNamed(context, '/dashboard');
        },
      ),

      ListTile(
        leading: const Icon(Icons.settings),
        title: const Text("Settings"),
        onTap: () {
          Navigator.pushNamed(context, '/settings');
        },
      ),

      ListTile(
        leading: const Icon(Icons.person),
        title: const Text("Profile"),
        onTap: () {
          Navigator.pushNamed(context, '/profile');
        },
      ),

      const Spacer(),

      const Divider(),

      ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text("Logout"),
        onTap: () {
          Navigator.pushReplacementNamed(context, '/login');
        },
      ),
    ],
  ),
),
    );
  }
}