import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hotel_reservation_app/app_shell.dart';

class PreferencePage extends StatefulWidget {
  const PreferencePage({super.key});

  @override
  State<PreferencePage> createState() => _PreferencePageState();
}

class _PreferencePageState extends State<PreferencePage> {
  String? floor;
  String? view;
  String? environment;
  bool familyFriendly = false;
  bool accessibility = false;

  bool loading = true;

  final List<String> floorOptions = [
    'No Preference',
    'Low Floor',
    'Middle Floor',
    'High Floor'
  ];

  final List<String> viewOptions = [
    'No Preference',
    'City View',
    'Sea View',
    'Garden View'
  ];

  final List<String> environmentOptions = [
    'No Preference',
    'Quiet',
    'Lively',
    'Natural'
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('preferences')
        .doc('userPrefs')
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      floor = data['preferredFloor'] == '' ? null : data['preferredFloor'];
      view = data['preferredView'] == '' ? null : data['preferredView'];
      environment =
          data['preferredEnvironment'] == '' ? null : data['preferredEnvironment'];
      familyFriendly = data['familyFriendly'] ?? false;
      accessibility = data['accessibility'] ?? false;
    }

    setState(() => loading = false);
  }

  Future<void> _savePreferences() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('preferences')
      .doc('userPrefs')
      .set({
    'preferredFloor': floor ?? '',
    'preferredView': view ?? '',
    'preferredEnvironment': environment ?? '',
    'familyFriendly': familyFriendly,
    'accessibility': accessibility,
    'updatedAt': Timestamp.now(),
  });

  // ✅ 保存后跳转回 Search（Tab 0）
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const AppShell(initialIndex: 0)),
    (route) => false,
  );
}


  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Set Personal Preferences',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Skip",
              style: TextStyle(color: Colors.black, fontSize: 16),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title("Preferred Floor"),
            _box(_dropdown(
              selectedValue: floor,
              options: floorOptions,
              onSelected: (v) =>
                  setState(() => floor = v == "No Preference" ? null : v),
            )),
            const SizedBox(height: 20),

            _title("Preferred View"),
            _box(_dropdown(
              selectedValue: view,
              options: viewOptions,
              onSelected: (v) =>
                  setState(() => view = v == "No Preference" ? null : v),
            )),
            const SizedBox(height: 20),

            _title("Preferred Environment"),
            _box(_dropdown(
              selectedValue: environment,
              options: environmentOptions,
              onSelected: (v) =>
                  setState(() => environment = v == "No Preference" ? null : v),
            )),
            const SizedBox(height: 20),

            _title("Family Friendly"),
            _box(
              Switch(
                value: familyFriendly,
                onChanged: (v) => setState(() => familyFriendly = v),
              ),
            ),
            const SizedBox(height: 20),

            _title("Accessibility Needed"),
            _box(
              Switch(
                value: accessibility,
                onChanged: (v) => setState(() => accessibility = v),
              ),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _savePreferences,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text("Save Preferences"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(String s) => Text(
        s,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      );

  Widget _box(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _dropdown({
    required String? selectedValue,
    required List<String> options,
    required ValueChanged<String?> onSelected,
  }) {
    return DropdownButtonFormField<String>(
      value: selectedValue ?? "No Preference",
      decoration: const InputDecoration(border: InputBorder.none),
      items: options
          .map(
            (o) => DropdownMenuItem(value: o, child: Text(o)),
          )
          .toList(),
      onChanged: onSelected,
    );
  }
}
