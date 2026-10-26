import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'pharmacy_settings.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set portrait orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  FirebaseAuth.instance.authStateChanges().listen((_) {
    PharmacySettingsService.instance.listen();
  });
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
        useMaterial3: true,
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF071A31), foregroundColor: Colors.white),
        cardTheme: CardThemeData(color: const Color(0xFF172A45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(foregroundColor: Colors.white)),
        primaryColor: const Color(0xFF2B7AFE),
        scaffoldBackgroundColor: const Color(0xFF0A1628),
        fontFamily: 'Inter',
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF2B7AFE),
          secondary: const Color(0xFF1E293B),
          surface: const Color(0xFF1E293B),
          background: const Color(0xFF0A1628),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0F172A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          hintStyle: const TextStyle(color: Color(0xFF64748B)),
        ),
      ),
      home: const PharmaCareSplash(),
    );
  }
}