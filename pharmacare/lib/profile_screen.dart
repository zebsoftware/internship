import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Sign in to view profile'));
    return SafeArea(child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final info = snapshot.data?.data() ?? {};
        final name = (info['fullName'] as String?)?.trim();
        final displayName = name?.isNotEmpty == true
            ? name! : (user.displayName?.isNotEmpty == true ? user.displayName! : (user.email ?? 'Pharmacy account'));
        void openSettings() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()));
        return ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Profile', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          InkWell(onTap: openSettings, borderRadius: BorderRadius.circular(20),
            child: Container(padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(colors: [Color(0xFF2B7AFE), Color(0xFF1E5DD6)])),
              child: Row(children: [
                const CircleAvatar(radius: 30, backgroundColor: Color(0xFF5795F9), child: Icon(Icons.person, size: 36, color: Colors.white)),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(user.email ?? 'Account profile', style: const TextStyle(color: Colors.white70)),
                ])),
                const Icon(Icons.edit_outlined, color: Colors.white),
              ]),
            ),
          ),
          const SizedBox(height: 26),
          Card(child: ListTile(
            leading: const Icon(Icons.settings_outlined, color: Color(0xFF2B7AFE)),
            title: const Text('Settings'),
            subtitle: const Text('Edit personal information, pharmacy details, currency and app preferences'),
            trailing: const Icon(Icons.chevron_right),
            onTap: openSettings,
          )),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B2020),
              padding: const EdgeInsets.all(17)),
            onPressed: () async { await FirebaseAuth.instance.signOut(); },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ]);
      },
    ));
  }
}
