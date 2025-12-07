import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ✅ 确保引入这三个文件
import 'package:hotel_reservation_app/app_shell.dart';
import 'package:hotel_reservation_app/services/database_service.dart';

class PreferencePage extends StatefulWidget {
  const PreferencePage({super.key});

  @override
  State<PreferencePage> createState() => _PreferencePageState();
}

class _PreferencePageState extends State<PreferencePage> {
  // --- 你的所有状态变量保持不变 ---
  String? floor;
  String? view;
  String? environment;
  String? roomLocation;
  String? familyNeeds;
  bool wheelchairAccessible = false;
  bool petFriendly = false;

  bool loading = true;
  bool _isSaving = false; // 控制按钮 loading 状态

  // --- 选项列表保持不变 ---
  final List<String> floorOptions = [
    'No Preference', 'Low Floor', 'High Floor',
  ];
  final List<String> viewOptions = [
    'No Preference', 'South-facing', 'East-facing', 'Sea View',
  ];
  final List<String> environmentOptions = [
    'No Preference', 'Quiet Room', 'Soundproofed Room',
  ];
  final List<String> roomLocationOptions = [
    'No Preference', 'Near Elevator', 'Far from Elevator', 'Near Exit',
  ];
  final List<String> familyNeedsOptions = [
    'No Preference', 'Family-friendly', 'Extra Bed', 'Family-friendly + Extra Bed',
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    // ... (保留你原来的加载逻辑，这部分没问题) ...
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('preferences').doc('userPrefs')
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      floor = data['preferredFloor'] == '' ? null : data['preferredFloor'];
      view = data['preferredView'] == '' ? null : data['preferredView'];
      environment = data['preferredEnvironment'] == '' ? null : data['preferredEnvironment'];
      roomLocation = (data['roomLocation'] ?? '') == '' ? null : data['roomLocation'];

      final bool legacyFamily = data['familyFriendly'] ?? false;
      final bool legacyExtraBed = data['extraBed'] ?? false;
      if (legacyFamily && legacyExtraBed) {
        familyNeeds = 'Family-friendly + Extra Bed';
      } else if (legacyFamily) {
        familyNeeds = 'Family-friendly';
      } else if (legacyExtraBed) {
        familyNeeds = 'Extra Bed';
      } else {
        final stored = (data['familyNeeds'] ?? '') as String;
        familyNeeds = stored == '' ? null : stored;
      }

      wheelchairAccessible = data['accessibility'] ?? false;
      petFriendly = data['petFriendly'] ?? false;
    }

    if (mounted) setState(() => loading = false);
  }

  // ✅ 修复：跳转主页的通用方法
  void _goToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (route) => false, // 清空路由栈，防止返回
    );
  }

  // ✅ 修复：Skip 逻辑
  Future<void> _skipSetup() async {
    setState(() => _isSaving = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    try {
      if (uid != null) {
        // 1. 标记数据库
        await DatabaseService().completeOnboarding(uid);
      }
      // 2. 强制跳转主页
      if (mounted) _goToHome();
    } catch (e) {
      print('Error skipping: $e');
      if (mounted) {
         // 即使报错也尝试跳转，避免卡死
         _goToHome();
      }
    }
  }

  // ✅ 修复：Save 逻辑
  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final bool saveFamily = (familyNeeds ?? '').contains('Family-friendly');
    final bool saveExtraBed = (familyNeeds ?? '').contains('Extra Bed');

    try {
      // 1. 保存偏好
      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('preferences').doc('userPrefs')
          .set({
        'preferredFloor': floor ?? '',
        'preferredView': view ?? '',
        'preferredEnvironment': environment ?? '',
        'roomLocation': roomLocation ?? '',
        'familyFriendly': saveFamily,
        'extraBed': saveExtraBed,
        'familyNeeds': familyNeeds ?? '',
        'accessibility': wheelchairAccessible,
        'petFriendly': petFriendly,
        'updatedAt': Timestamp.now(),
      });

      // 2. 标记完成新手引导
      await DatabaseService().completeOnboarding(uid);

      // 3. 强制跳转主页
      if (mounted) _goToHome();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
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
          // Skip 按钮
          TextButton(
            onPressed: _isSaving ? null : _skipSetup,
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
            const SizedBox(height: 20),

            _title("Preferred Floor"),
            _box(_dropdown(
              selectedValue: floor,
              options: floorOptions,
              onSelected: (v) => setState(() => floor = v == "No Preference" ? null : v),
            )),
            const SizedBox(height: 20),

            _title("Preferred View / Direction"),
            _box(_dropdown(
              selectedValue: view,
              options: viewOptions,
              onSelected: (v) => setState(() => view = v == "No Preference" ? null : v),
            )),
            const SizedBox(height: 20),

            _title("Preferred Environment"),
            _box(_dropdown(
              selectedValue: environment,
              options: environmentOptions,
              onSelected: (v) => setState(() => environment = v == "No Preference" ? null : v),
            )),
            const SizedBox(height: 20),

            _title("Room Location"),
            _box(_dropdown(
              selectedValue: roomLocation,
              options: roomLocationOptions,
              onSelected: (v) => setState(() => roomLocation = v == "No Preference" ? null : v),
            )),
            const SizedBox(height: 20),

            _title("Family Needs"),
            _box(_dropdown(
              selectedValue: familyNeeds,
              options: familyNeedsOptions,
              onSelected: (v) => setState(() => familyNeeds = v == "No Preference" ? null : v),
            )),
            const SizedBox(height: 20),

            _title("Accessibility Needed"),
            _box(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Wheelchair-accessible"),
                Switch(
                  value: wheelchairAccessible,
                  onChanged: (v) => setState(() => wheelchairAccessible = v),
                ),
              ],
            )),
            const SizedBox(height: 20),

            _title("Other Special Requests"),
            _box(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Pet-friendly"),
                Switch(
                  value: petFriendly,
                  onChanged: (v) => setState(() => petFriendly = v),
                ),
              ],
            )),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _savePreferences,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text("Save Preferences"),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- 你的辅助小组件保持不变 ---
  Widget _title(String s) => Text(s, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15));

  Widget _box(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: child,
    );
  }

  Widget _dropdown({
    required String? selectedValue,
    required List<String> options,
    required ValueChanged<String?> onSelected,
  }) {
    final String safeInitial = (selectedValue != null && options.contains(selectedValue))
        ? selectedValue!
        : "No Preference";

    return DropdownButtonFormField<String>(
      value: safeInitial,
      decoration: const InputDecoration(border: InputBorder.none),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
      onChanged: onSelected,
    );
  }
}