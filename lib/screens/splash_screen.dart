import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  void _navigateToNextScreen() {
    // الانتظار لمدة 3 ثوانٍ لعرض شعار التطبيق بشكل لائق
    Timer(const Duration(seconds: 3), () {
      // جلب حالة المستخدم الحالي من الفايربيس
      if (AuthService.isLoggedIn) {
        // إذا كان مسجلاً ومؤكداً بريده، يذهب للرئيسية مباشرة
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // خلاف ذلك، يذهب لصفحة الدخول
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // الشعار (شعار علاقة الملابس الخاص بتطبيقك)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFE91E63).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.checkroom,
                size: 60,
                color: Color(0xFFE91E63),
              ),
            ),
            const SizedBox(height: 24),

            // اسم التطبيق
            const Text(
              "Fabric AI",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE91E63),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),

            // وصف بسيط تحت الاسم
            Text(
              "Smart Fabric Inspection System",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 60),

            // مؤشر انتظار دائري ناعم بالأسفل متناسق مع اللون الأساسي
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Color(0xFFE91E63),
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
