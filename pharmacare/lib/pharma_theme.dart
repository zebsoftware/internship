import 'package:flutter/material.dart';

class PharmaTheme {
  static const navy = Color(0xFF071A31);
  static const card = Color(0xFF182B45);
  static const blue = Color(0xFF247CFF);
  static const teal = Color(0xFF17BB9C);
  static const muted = Color(0xFF9BB1CD);

  static InputDecoration input(String label, {IconData? icon}) => InputDecoration(
    labelText: label,
    prefixIcon: icon == null ? null : Icon(icon, color: muted),
    filled: true, fillColor: const Color(0xFF213550),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
  );
}

class PharmaSection extends StatelessWidget {
  final String title;
  final Widget child;
  const PharmaSection({super.key, required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: PharmaTheme.card, borderRadius: BorderRadius.circular(22)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12), child,
    ]),
  );
}
