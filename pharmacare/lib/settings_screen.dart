import 'pharma_theme.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pharmacy_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final name = TextEditingController();
  final personalName = TextEditingController();
  final personalPhone = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final tax = TextEditingController();
  final threshold = TextEditingController();
  final expiry = TextEditingController();
  String currency = 'PKR';
  bool alerts = true, saving = false;

  @override
  void initState() {
    super.initState();
    final s = PharmacySettingsService.instance.current.value;
    name.text = s.name;
    _loadProfile(); phone.text = s.phone; address.text = s.address;
    tax.text = s.taxPercent.toString();
    threshold.text = s.lowStockThreshold.toString();
    expiry.text = s.expiryWarningDays.toString();
    currency = s.currency; alerts = s.alertsEnabled;
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!mounted) return;
      personalName.text = doc.data()?['fullName'] as String? ?? user.displayName ?? '';
      personalPhone.text = doc.data()?['phoneNumber'] as String? ?? '';
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load profile: $e')));
    }
  }

  @override
  void dispose() {
    for (final c in [name, phone, address, tax, threshold, expiry, personalName, personalPhone]) { c.dispose(); }
    super.dispose();
  }

  Future<void> save() async {
    final taxValue = double.tryParse(tax.text);
    final thresholdValue = int.tryParse(threshold.text);
    final expiryValue = int.tryParse(expiry.text);
    if (taxValue == null || thresholdValue == null || expiryValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid numeric settings')));
      return;
    }
    setState(() => saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('Sign in required');
      await PharmacySettingsService.instance.save(PharmacySettings(
        name: name.text.trim(), phone: phone.text.trim(), address: address.text.trim(),
        currency: currency, taxPercent: taxValue,
        lowStockThreshold: thresholdValue, expiryWarningDays: expiryValue,
        alertsEnabled: alerts,
      ));
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'fullName': personalName.text.trim(),
        'phoneNumber': personalPhone.text.trim(),
      });
      await user.updateDisplayName(personalName.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget field(String label, TextEditingController controller, {bool number = false}) =>
    Padding(padding: const EdgeInsets.only(bottom: 16), child: TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    ));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Personal Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      field('Your full name', personalName),
      field('Your phone', personalPhone),
      const SizedBox(height: 12),
      const Text('Pharmacy & App Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      field('Pharmacy name', name),
      field('Contact phone', phone),
      field('Address', address),
      DropdownButtonFormField<String>(
        value: currency,
        decoration: const InputDecoration(labelText: 'Base currency'),
        items: supportedCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => setState(() => currency = v ?? currency),
      ),
      const Padding(padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Changing currency after inventory/orders exist requires a controlled migration. This screen will never silently relabel existing prices.')),
      field('Default sales tax (%)', tax, number: true),
      field('Low-stock threshold', threshold, number: true),
      field('Expiry warning days', expiry, number: true),
      SwitchListTile(title: const Text('Enable stock and expiry alerts'), value: alerts,
        onChanged: (v) => setState(() => alerts = v)),
      const SizedBox(height: 12),
      FilledButton(onPressed: saving ? null : save,
        child: Text(saving ? 'Saving...' : 'Save settings')),
    ]),
  );
}
