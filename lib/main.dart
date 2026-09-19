import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// الاستدعاءات النسبية الصافية لمنع تضارب الـ Compiler
import 'core/network_service.dart';
import 'screens/lock_screen.dart';

// 🌐 كلاس تخطي شهادات الأمان لضمان نجاح الاتصال المباشر بـ سرفر الـ ESP32
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

  runApp(
    ChangeNotifierProvider(
      create: (_) => NetworkService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF020408),
        colorScheme: const ColorScheme.dark(primary: Color(0xFFFF1E1E), background: Color(0xFF020408)),
      ),
      home: const LockScreen(),
    );
  }
}

