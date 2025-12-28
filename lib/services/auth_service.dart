import 'package:firebase_auth/firebase_auth.dart';
// 1. 导入 DatabaseService (使用 'services' 路径)
import 'package:hotel_reservation_app/services/database_service.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // 2. 实例化 DatabaseService
  final DatabaseService _db = DatabaseService();

  // 获取用户认证状态的 Stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 登录方法
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print(e.toString());
      rethrow;
    }
  }

  // 注册方法
  Future<User?> registerWithEmailAndPassword(
    String email,
    String password,
    String firstName,
    String lastName,
    String phoneNumber,
  ) async {
    try {
      // 第一步：在 Auth 中创建用户
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        // 第二步：在 Firestore 中创建用户数据
        await _db.createUserData(
          user.uid,
          email,
          firstName,
          lastName,
          phoneNumber,
        );
        
        // (可选) 更新 Auth 用户的显示名称
        await user.updateDisplayName('$firstName $lastName');
      }
      return user;
    } catch (e) {
      print(e.toString());
      rethrow;
    }
  }

  // --- 3. 新增：发送重置密码邮件的方法 ---
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print(e.toString());
      rethrow; // 抛出异常，让 UI 层去处理
    }
  }

  // 登出方法
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ✅ 新增：管理员添加员工账号 (不登出当前管理员)
  Future<void> createStaffAccount(
    String email,
    String password,
    String firstName,
    String lastName,
    String phone,
  ) async {
    FirebaseApp? secondaryApp;
    try {
      // 1. 初始化一个次级 Firebase App 实例
      secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: Firebase.app().options,
      );

      // 2. 使用这个次级实例的 Auth 来创建用户
      UserCredential userCredential = await FirebaseAuth.instanceFor(app: secondaryApp)
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 3. 将用户信息写入数据库 (Role = staff)
      if (userCredential.user != null) {
        await _db.createUserData(
          userCredential.user!.uid,
          email,
          firstName,
          lastName,
          phone,
          role: 'staff', // 👈 关键：标记为员工
        );
      }
      
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code}');
      rethrow;
    } finally {
      // 4. 用完必须删除这个临时实例，否则会报错
      await secondaryApp?.delete();
    }
  }


}

