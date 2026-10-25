import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'screens/splash_screen.dart'; // 🟢 استدعاء شاشة الفلاش الجديدة
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

  if (kIsWeb) {
    // Firebase web config is passed at build time with --dart-define
    // (see render-build.sh). These are public identifiers, not secrets.
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
        appId: String.fromEnvironment('FIREBASE_APP_ID'),
        messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
        authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
        storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  await Hive.initFlutter();
  await Hive.openBox('fabricBox');

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

      // 🟢 تعديل أول مسار يفتحه التطبيق ليصبح شاشة الفلاش
      initialRoute: '/',

      routes: {
        '/': (context) =>
            const SplashScreen(), // 🟢 ربط مسار البداية بشاشة الفلاش
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
