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

  // New: room location
  String? roomLocation;

  // Replaced two booleans with a dropdown-backed value for Family Needs
  String? familyNeeds;

  // Renamed for clarity in UI; keeps same Firestore key 'accessibility'
  bool wheelchairAccessible = false;

  // New: pet friendly
  bool petFriendly = false;

  bool loading = true;

  final List<String> floorOptions = [
    'No Preference',
    'Low Floor',
    'High Floor',
  ];

  // Updated view options
  final List<String> viewOptions = [
    'No Preference',
    'South-facing',
    'East-facing',
    'Sea View',
  ];

  // Updated environment options
  final List<String> environmentOptions = [
    'No Preference',
    'Quiet Room',
    'Soundproofed Room',
  ];

  // New room location options
  final List<String> roomLocationOptions = [
    'No Preference',
    'Near Elevator',
    'Far from Elevator',
    'Near Exit',
  ];

  // New family needs options (dropdown)
  final List<String> familyNeedsOptions = [
    'No Preference',
    'Family-friendly',
    'Extra Bed',
    'Family-friendly + Extra Bed',
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
      environment = data['preferredEnvironment'] == ''
          ? null
          : data['preferredEnvironment'];

      // New fields loaded from Firestore (keep backwards compatible defaults)
      roomLocation =
          (data['roomLocation'] ?? '') == '' ? null : data['roomLocation'];

      // Backwards compatibility: derive familyNeeds from legacy booleans
      final bool legacyFamily = data['familyFriendly'] ?? false;
      final bool legacyExtraBed = data['extraBed'] ?? false;
      if (legacyFamily && legacyExtraBed) {
        familyNeeds = 'Family-friendly + Extra Bed';
      } else if (legacyFamily) {
        familyNeeds = 'Family-friendly';
      } else if (legacyExtraBed) {
        familyNeeds = 'Extra Bed';
      } else {
        // If a new string value exists in data (in case saved previously)
        final stored = (data['familyNeeds'] ?? '') as String;
        familyNeeds = stored == '' ? null : stored;
      }

      wheelchairAccessible = data['accessibility'] ?? false;
      petFriendly = data['petFriendly'] ?? false;
    }

    setState(() => loading = false);
  }

  Future<void> _savePreferences() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // derive booleans for compatibility
    final bool saveFamily = (familyNeeds ?? '').contains('Family-friendly');
    final bool saveExtraBed = (familyNeeds ?? '').contains('Extra Bed');

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('preferences')
        .doc('userPrefs')
        .set({
      'preferredFloor': floor ?? '',
      'preferredView': view ?? '',
      'preferredEnvironment': environment ?? '',
      // New saved fields
      'roomLocation': roomLocation ?? '',
      // Save both legacy booleans for compatibility
      'familyFriendly': saveFamily,
      'extraBed': saveExtraBed,
      // Also store familyNeeds string (optional)
      'familyNeeds': familyNeeds ?? '',
      // Keep firestore key 'accessibility' for compatibility
      'accessibility': wheelchairAccessible,
      'petFriendly': petFriendly,
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // NEW: top spacer to push page content downward; adjust height as needed
            const SizedBox(height: 100),

            _title("Preferred Floor"),
            _box(
              _dropdown(
                selectedValue: floor,
                options: floorOptions,
                onSelected: (v) =>
                    setState(() => floor = v == "No Preference" ? null : v),
              ),
            ),
            const SizedBox(height: 20),

            _title("Preferred View / Direction"),
            _box(
              _dropdown(
                selectedValue: view,
                options: viewOptions,
                onSelected: (v) =>
                    setState(() => view = v == "No Preference" ? null : v),
              ),
            ),
            const SizedBox(height: 20),

            _title("Preferred Environment"),
            _box(
              _dropdown(
                selectedValue: environment,
                options: environmentOptions,
                onSelected: (v) => setState(
                  () => environment = v == "No Preference" ? null : v,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // New: Room Location
            _title("Room Location"),
            _box(
              _dropdown(
                selectedValue: roomLocation,
                options: roomLocationOptions,
                onSelected: (v) => setState(
                  () => roomLocation = v == "No Preference" ? null : v,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Family Needs as dropdown (replaces previous switches)
            _title("Family Needs"),
            _box(
              _dropdown(
                selectedValue: familyNeeds,
                options: familyNeedsOptions,
                onSelected: (v) => setState(
                  () => familyNeeds = v == "No Preference" ? null : v,
                ),
              ),
            ),
            const SizedBox(height: 20),

            _title("Accessibility Needed"),
            _box(
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Wheelchair-accessible"),
                  Switch(
                    value: wheelchairAccessible,
                    onChanged: (v) => setState(() => wheelchairAccessible = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _title("Other Special Requests"),
            _box(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // only keep Pet-friendly switch, remove text input
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Pet-friendly"),
                      Switch(
                        value: petFriendly,
                        onChanged: (v) => setState(() => petFriendly = v),
                      ),
                    ],
                  ),
                ],
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
    // Ensure the initial value exists in the options to avoid Dropdown assertion
    final String safeInitial = (selectedValue != null && options.contains(selectedValue))
        ? selectedValue!
        : "No Preference";

    return DropdownButtonFormField<String>(
      initialValue: safeInitial,
      decoration: const InputDecoration(border: InputBorder.none),
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: onSelected,
    );
  }
}
