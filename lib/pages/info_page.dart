import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hotel_reservation_app/data/info_data.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  void _showMessageDetail(InfoMessage msg, int index) {
    setState(() {
      msg.isRead = true;
      final readMsg = infoMessages.removeAt(index);
      infoMessages.add(readMsg);
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(msg.title, style: const TextStyle(fontWeight: FontWeight.bold)),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: infoMessages.isEmpty
          ? const Center(
              child: Text('No messages yet.',
                  style: TextStyle(color: Colors.grey, fontSize: 16)))
          : ListView.builder(
              itemCount: infoMessages.length,
              itemBuilder: (context, index) {
                final msg = infoMessages[index];
                final preview = msg.message.length > 25
                    ? '${msg.message.substring(0, 25)}...'
                    : msg.message;
                final time = DateFormat('HH:mm').format(msg.timestamp);

                return InkWell(
                  onTap: () => _showMessageDetail(msg, index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        // 左侧头像
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundImage: AssetImage(msg.senderIcon),
                            ),
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
                              )
                          ],
                        ),
                        const SizedBox(width: 12),
                        // 中间标题和消息
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(msg.title,
                                  style: TextStyle(
                                      fontWeight: msg.isRead
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(preview,
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.grey)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 右侧时间
                        Text(time,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
