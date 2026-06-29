import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart'; // 🔴 أضفنا استدعاء مكتبة Hive هنا

import 'screens/signup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard.dart';
import 'screens/result_page.dart';
import 'screens/fabric_view_page.dart';
import 'screens/create_profile.dart';
import 'screens/settings_page.dart';
import 'home.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
   await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // 🔴 هذان السطران هما الحل السحري للشاشة الرمادية
  await Hive.initFlutter();
  await Hive.openBox('fabricBox'); // نفتح الصندوق قبل تشغيل التطبيق

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fabric Inspection App',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      initialRoute: '/login',

      routes: {
        '/signup': (context) => const SignUpScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomePage(),

        '/dashboard': (context) => FabricDashboard(),
        '/results': (context) => ResultPage(),
        '/view': (context) => FabricViewPage(),

        '/profile': (context) => const CreateProfileScreen(),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}
