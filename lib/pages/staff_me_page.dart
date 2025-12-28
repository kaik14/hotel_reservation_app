import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:hotel_reservation_app/services/auth_service.dart';

class StaffMePage extends StatelessWidget {
  const StaffMePage({super.key});

  DocumentReference<Map<String, dynamic>> _staffRef(String uid) {
    return FirebaseFirestore.instance.collection('staffs').doc(uid);
  }

  // ✅ 只查普通集合 staff_tasks（不走 collectionGroup）
  Stream<QuerySnapshot<Map<String, dynamic>>> _completedStream(String uid) {
    return FirebaseFirestore.instance
        .collection('staff_tasks')
        .where('staffUid', isEqualTo: uid)
        .snapshots();
  }

  String _taskTitle(Map<String, dynamic> data) {
    final serviceType =
        (data['serviceType'] ?? '').toString().trim().toLowerCase();
    final serviceName = (data['serviceName'] ?? '').toString().trim();

    if (serviceType == 'housekeeping') {
      final roomNo =
          (data['roomNumber'] ?? data['roomNo'] ?? '').toString().trim();
      return roomNo.isNotEmpty ? 'Room $roomNo - Housekeeping' : 'Housekeeping';
    }

    if (serviceName.isNotEmpty) return serviceName;

    if (serviceType.isNotEmpty) {
      if (serviceType == 'conferencehall') return 'Conference Hall';
      if (serviceType == 'taxi') return 'Airport Taxi';
      if (serviceType == 'laundry') return 'Laundry & Ironing';
      return '${serviceType[0].toUpperCase()}${serviceType.substring(1)}';
    }

    return 'Task';
  }

  String _timeText(Map<String, dynamic> data) {
    DateTime? dt;
    final handledAt = data['handledAt'];
    if (handledAt is Timestamp) dt = handledAt.toDate();

    if (dt == null) return 'Time N/A';
    return DateFormat('dd MMM yyyy • HH:mm').format(dt);
  }

  String _guestId(Map<String, dynamic> data) {
    return (data['userId'] ?? '-').toString();
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    final uid = u?.uid ?? '';
    final email = u?.email ?? '';

    if (uid.isEmpty) {
      return const SafeArea(child: Center(child: Text('Not logged in.')));
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _staffRef(uid).snapshots(),
              builder: (context, snap) {
                final data = snap.data?.data() ?? {};
                final name = (data['name'] ??
                        data['fullName'] ??
                        data['displayName'] ??
                        '')
                    .toString()
                    .trim();
                final role =
                    (data['role'] ?? data['level'] ?? 'Staff').toString().trim();

                final showName = name.isNotEmpty
                    ? name
                    : (email.isNotEmpty ? email.split('@').first : 'Staff');

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.person, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              showName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              role,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Email: $email',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'UID: $uid',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Completed title
            Row(
              children: const [
                Icon(Icons.task_alt, size: 18),
                SizedBox(width: 8),
                Text(
                  'Completed Tasks',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Completed list
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _completedStream(uid),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = [...(snap.data?.docs ?? [])];

                  // ✅ 手动按 handledAt 倒序
                  docs.sort((a, b) {
                    DateTime? at;
                    DateTime? bt;
                    final aa = a.data()['handledAt'];
                    final bb = b.data()['handledAt'];
                    if (aa is Timestamp) at = aa.toDate();
                    if (bb is Timestamp) bt = bb.toDate();
                    if (at == null && bt == null) return 0;
                    if (at == null) return 1;
                    if (bt == null) return -1;
                    return bt.compareTo(at);
                  });

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No completed tasks yet.',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final data = docs[i].data();
                      final title = _taskTitle(data);
                      final time = _timeText(data);
                      final guest = _guestId(data);

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.check, color: Colors.green),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    time,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Guest ID: $guest',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black45,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () async => AuthService().signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
