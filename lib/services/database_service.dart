// lib/database_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. 创建用户数据
  //    当用户注册时，我们会调用此方法
  Future<void> createUserData(String uid, String email, String firstName,
      String lastName, String phoneNumber) async {
    // 创建一个指向 'users' 集合中新文档的引用，ID 为 uid
    DocumentReference userDoc = _db.collection('users').doc(uid);
    
    await userDoc.set({
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 2. 获取用户数据 (Stream)
  //    ProfilePage 将使用它来实时显示用户名
  Stream<DocumentSnapshot> getUserDataStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  // 3. (为你的下一步准备) 添加预订
  Future<void> addBooking(String uid, String hotelName, String date) async {
    // ... 我们稍后会实现这个 ...
  }

  // 4. (为你的下一步准备) 获取预订
  Stream<QuerySnapshot> getBookingsStream(String uid) {
    // ... 我们稍后会实现这个 ...
    return _db.collection('bookings').where('userId', isEqualTo: uid).snapshots();
  }
}