import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const PharmaCareApp());
}

class PharmaCareApp extends StatelessWidget {
  const PharmaCareApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PharmaCare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2B7AFE),
        scaffoldBackgroundColor: const Color(0xFF0A1628),
        fontFamily: 'Inter',
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF2B7AFE),
          secondary: const Color(0xFF1E293B),
          surface: const Color(0xFF1E293B),
          background: const Color(0xFF0A1628),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
