import 'package:flutter/material.dart';

class PreferencePage extends StatefulWidget {
  const PreferencePage({super.key});

  @override
  State<PreferencePage> createState() => _PreferencePageState();
}

class _PreferencePageState extends State<PreferencePage> {
  String? selectedLocation;
  String? selectedRoomType;
  bool includeBreakfast = false;
  bool includeWifi = false;

  final List<String> locations = ['Kuala Lumpur', 'Penang', 'Langkawi'];
  final List<String> roomTypes = ['Suite', 'Standard', 'Economy'];

  void _savePreferences() async {
    // 🔹 这里你可以保存到 Firestore 或 SharedPreferences
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setString('location', selectedLocation ?? '');
    // await prefs.setString('roomType', selectedRoomType ?? '');
    // await prefs.setBool('breakfast', includeBreakfast);
    // await prefs.setBool('wifi', includeWifi);

    // 🔹 保存后返回主页
    Navigator.pop(context);
  }

  void _skip() {
    // 用户点击右上角叉号（不想输入偏好）
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Set Your Preferences',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black), // ✅ 右上角叉号
            onPressed: _skip,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preferred Location',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedLocation,
                  hint: const Text('Choose location'),
                  decoration: _inputDecoration(),
                  items: locations
                      .map((loc) =>
                          DropdownMenuItem(value: loc, child: Text(loc)))
                      .toList(),
                  onChanged: (val) => setState(() => selectedLocation = val),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Preferred Room Type',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedRoomType,
                  hint: const Text('Choose room type'),
                  decoration: _inputDecoration(),
                  items: roomTypes
                      .map((type) =>
                          DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (val) => setState(() => selectedRoomType = val),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Additional Preferences',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: includeBreakfast,
                  onChanged: (v) => setState(() => includeBreakfast = v!),
                  title: const Text('Include breakfast'),
                ),
                CheckboxListTile(
                  value: includeWifi,
                  onChanged: (v) => setState(() => includeWifi = v!),
                  title: const Text('Free WiFi'),
                ),

                const SizedBox(height: 30),

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
                    child: const Text('Save Preferences'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() => InputDecoration(
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );
}
