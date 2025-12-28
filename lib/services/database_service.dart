// lib/database_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

 // 1. 修改：增加 [role] 参数，默认为 'customer'
  Future<void> createUserData(String uid, String email, String firstName,
      String lastName, String phoneNumber, {String role = 'customer'}) async { // 👈 修改了这里
    DocumentReference userDoc = _db.collection('users').doc(uid);
    
    await userDoc.set({
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'role': role, // 👈 这里使用传入的参数
      'createdAt': FieldValue.serverTimestamp(),
      'isSetup': true, // 管理员添加的员工默认跳过偏好设置
    });
  }

  // 2. 获取用户数据 (Stream)
  //    ProfilePage 将使用它来实时显示用户名
  Stream<DocumentSnapshot> getUserDataStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  // ✅ 3. 获取用户角色 (已修复 print 警告)
  Future<String> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return data['role'] ?? 'customer';
      }
    } catch (e) {
      // ✅ 2. 这里改成了 debugPrint
      debugPrint('Error fetching user role: $e');
    }
    return 'customer'; // 默认回退
  }

// ✅ 4. 添加预订 (核心功能)
  // 参数建议：除了简单的 String，最好传入具体的房间ID、日期范围、总价等
  Future<void> addBooking({
    required String uid,
    required String roomName,
    required String roomId,
    required DateTime startDate,
    required DateTime endDate,
    required double totalPrice,
    required String imageUrl,
  }) async {
    try {
      await _db.collection('bookings').add({
        'userId': uid,
        'roomName': roomName,
        'roomId': roomId,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'totalPrice': totalPrice,
        'imageUrl': imageUrl,
        'status': 'confirmed', // 默认状态
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Booking added successfully!');
    } catch (e) {
      debugPrint('Error adding booking: $e');
      rethrow;
    }
  }

// ✅ 5. 获取当前用户的预订列表 (Stream)
  // Customer 用：只看自己的
  Stream<QuerySnapshot> getUserBookingsStream(String uid) {
    return _db
        .collection('bookings')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true) // 按时间倒序
        .snapshots();
  }

  // ✅ 6. (新增) 获取所有预订
  // Admin/Staff 用：查看所有人的
  Stream<QuerySnapshot> getAllBookingsStream() {
    return _db
        .collection('bookings')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ✅ 6. 完成新手引导 (核心修复)
  // 当用户点击 Skip 或 Save 时调用，打上标记，防止下次再进偏好页
  Future<void> completeOnboarding(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'isSetup': true, // 打个勾
      });
    } catch (e) {
      // 如果文档不存在（极少数情况），则用 set 合并
      await _db.collection('users').doc(uid).set({
        'isSetup': true,
      }, SetOptions(merge: true));
    }
  }

  // ✅ 新增：删除用户数据 (Soft Delete)
  // 注意：这只会删除数据库记录，员工将无法登录 App (被 AuthGate 拦截)，但 Auth 账号本身还在。
  Future<void> deleteUserData(String uid) async {
    try {
      await _db.collection('users').doc(uid).delete();
      debugPrint('User deleted from Firestore');
    } catch (e) {
      debugPrint('Error deleting user: $e');
      rethrow;
    }
  }

}
