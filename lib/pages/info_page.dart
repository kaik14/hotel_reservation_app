import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // 用于状态栏样式
import 'package:hotel_reservation_app/data/info_data.dart'; // ✅ 用于 InfoMessage 模型

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  List<InfoMessage> messages = [];

  Set<String> _readKeys = {};
  List<String> _orderKeys = [];

  String _keyOf(InfoMessage m) =>
      '${m.title}|${m.timestamp.millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _loadMessagesFromFirebase();
  }

  // ✅ 从 Firebase 读取用户消息
  Future<void> _loadMessagesFromFirebase() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('messages')
        .orderBy('timestamp')
        .get();

    messages = snap.docs.map((d) {
      final data = d.data();
      return InfoMessage(
        title: data['title'] ?? '',
        message: data['message'] ?? '',
        senderIcon: data['senderIcon'] ?? 'system',
        timestamp: (data['timestamp'] as Timestamp).toDate(),
        isRead: false,
      );
    }).toList();

    await _loadPersistentState(); // ✅ 载入已读状态与排序
    setState(() {});
  }

  // ✅ 从本地记录中恢复已读状态与排序
  Future<void> _loadPersistentState() async {
    final prefs = await SharedPreferences.getInstance();

    _readKeys = (prefs.getStringList('message_read_keys') ?? []).toSet();
    _orderKeys = prefs.getStringList('message_order_keys') ?? [];

    for (final m in messages) {
      if (_readKeys.contains(_keyOf(m))) {
        m.isRead = true;
      }
    }

    // ✅ 恢复顺序
    if (_orderKeys.isNotEmpty) {
      messages.sort((a, b) {
        int ai = _orderKeys.indexOf(_keyOf(a));
        int bi = _orderKeys.indexOf(_keyOf(b));
        return ai.compareTo(bi);
      });
    }
  }

  // ✅ 保存已读与顺序
  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('message_read_keys', _readKeys.toList());

    final order = messages.map(_keyOf).toList();
    await prefs.setStringList('message_order_keys', order);
  }

  // ✅ 点击消息 → 标记已读 + 移到最后
  void _showMessageDetail(InfoMessage msg, int index) async {
    msg.isRead = true;
    _readKeys.add(_keyOf(msg));

    final moved = messages.removeAt(index);
    messages.add(moved);

    await _persistState();
    setState(() {});

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          msg.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.message, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 16),
            Text(
              DateFormat('yyyy-MM-dd HH:mm').format(msg.timestamp),
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  // ✅ 头像逻辑保持原样
  Widget _buildAvatar(InfoMessage msg) {
    if (msg.senderIcon == 'system') {
      return const CircleAvatar(
        radius: 25,
        backgroundImage: AssetImage('assets/icons/hotel_icon.png'),
        backgroundColor: Colors.white,
      );
    }
    return CircleAvatar(
      radius: 25,
      backgroundImage: _loadUserImage(msg.senderIcon),
    );
  }

  ImageProvider _loadUserImage(String path) {
    if (path.startsWith('http')) return NetworkImage(path);
    return AssetImage(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🔵 与 Service 页一致的浅蓝灰背景 #DEE4EC
      backgroundColor: const Color.fromARGB(255, 222, 228, 236),

      // 🔧 顶部栏统一风格（#0F1722，高度 97，白色标题，细分隔线）+ 副标题
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1722),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        toolbarHeight: 97, // 统一高度
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF0F1722),
          statusBarIconBrightness: Brightness.light, // Android 浅色图标
          statusBarBrightness: Brightness.dark, // iOS 深底
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Messages',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Latest updates and notifications.',
              style: TextStyle(
                color: Color(0x99FFFFFF), // 半透明白
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            height: 0.5,
            color: Colors.white.withOpacity(0.08), // 细分隔线
          ),
        ),
      ),

      body: messages.isEmpty
          ? const Center(
              child: Text(
                'No messages yet.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final preview = msg.message.length > 25
                    ? '${msg.message.substring(0, 25)}...'
                    : msg.message;
                final time = DateFormat('HH:mm').format(msg.timestamp);

                return InkWell(
                  onTap: () => _showMessageDetail(msg, index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            _buildAvatar(msg),
                            if (!msg.isRead)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.title,
                                style: TextStyle(
                                  fontWeight: msg.isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                preview,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
