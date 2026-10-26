import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class PharmaCareMark extends StatelessWidget {
  final double size;
  const PharmaCareMark({super.key, this.size = 88});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF148BFF), Color(0xFF0063D6), Color(0xFF00AB84)]),
      borderRadius: BorderRadius.circular(size * .25),
      boxShadow: [BoxShadow(color: const Color(0xFF0F83F6).withValues(alpha: .2), blurRadius: size * .32)],
    ),
    child: Icon(Icons.medical_services_rounded, color: Colors.white, size: size * .60),
  );
}

/// Branded launch screen; Firebase auth persists until explicit sign-out or revocation.
class PharmaCareSplash extends StatefulWidget {
  const PharmaCareSplash({super.key});
  @override
  State<PharmaCareSplash> createState() => _PharmaCareSplashState();
}

class _PharmaCareSplashState extends State<PharmaCareSplash> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => FirebaseAuth.instance.currentUser == null
            ? const LoginScreen() : const DashboardScreen(),
      ));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF061D39),
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const PharmaCareMark(size: 116),
      const SizedBox(height: 26),
      const Text.rich(TextSpan(children: [
        TextSpan(text: 'Pharma', style: TextStyle(color: Colors.white)),
        TextSpan(text: 'Care', style: TextStyle(color: Color(0xFF26D7A9))),
      ]), style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -.8)),
      const SizedBox(height: 8),
      const Text('Your Pharmacy Partner', style: TextStyle(color: Color(0xFFA8BDD7), fontSize: 16)),
      const SizedBox(height: 60),
      const SizedBox(width: 76, child: LinearProgressIndicator(minHeight: 3, color: Color(0xFF2B7AFE), backgroundColor: Color(0xFF274260))),
    ])),
  );
}
