import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hotel_reservation_app/pages/preference_page.dart';
import 'package:hotel_reservation_app/services/database_service.dart'; // 👈 记得加这一行

// 1. 确认导入 'services' 文件夹中的 'auth_service.dart'
import 'package:hotel_reservation_app/services/auth_service.dart';

// 2. 确认导入 'pages' 文件夹中的 'register_page.dart'
import 'package:hotel_reservation_app/pages/register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // GlobalKey 用于表单验证
  final _formKey = GlobalKey<FormState>();

  // 控制器用于获取输入框内容
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  final AuthService _authService = AuthService(); // 实例化 AuthService
  int currentIndex = 0;

  // --- 登录逻辑 ---
  Future<void> _submit() async {
    // 1. 表单验证
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // 2. 执行 Firebase 登录
      await _authService.signInWithEmailAndPassword(
        _emailController.text,
        _passwordController.text,
      );

      // 3. 获取当前登录的用户对象
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // ✅ 4. 获取用户角色
        // DatabaseService().getUserRole 内部逻辑是：如果有 role 字段则返回 role，如果没有或报错则返回 'customer'
        // 这完美符合你“旧用户没有字段视为 customer”的要求
        String role = await DatabaseService().getUserRole(user.uid);

        // ✅ 5. 核心逻辑：检查“当前选中的按钮”与“实际角色”是否匹配
        bool isAllowed = false;
        String errorMsg = '';

        if (currentIndex == 0) {
          // --- User 按钮 (index 0) ---
          // 允许：角色是 customer (或 null/不存在)
          if (role == 'customer') {
            isAllowed = true;
          } else {
            // 如果是 Admin 或 Staff 试图从 User 入口登录，拒绝
            errorMsg = 'Current account is $role. Please login from the ${role[0].toUpperCase()}${role.substring(1)} tab.';
          }
        } else if (currentIndex == 1) {
          // --- Staff 按钮 (index 1) ---
          if (role == 'staff') {
            isAllowed = true;
          } else {
            errorMsg = 'Access Denied: This portal is for Staff only.';
          }
        } else if (currentIndex == 2) {
          // --- Admin 按钮 (index 2) ---
          if (role == 'admin') {
            isAllowed = true;
          } else {
            errorMsg = 'Access Denied: This portal is for Admins only.';
          }
        }

        // ✅ 6. 如果不匹配：强制登出并报错
        if (!isAllowed) {
          await _authService.signOut(); // 关键：立刻踢下线，防止 AuthGate 跳转
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMsg),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
            setState(() => _isLoading = false);
          }
          return; // ⛔️ 终止后续代码执行
        }

        // --- 验证通过，继续原有的逻辑 ---

        // 7. 检查是否首次登录 (保持你原有的逻辑不变)
        final creationTime = user.metadata.creationTime;
        final lastSignInTime = user.metadata.lastSignInTime;

        if (creationTime != null && lastSignInTime != null) {
          // 容错处理：由于中间查了一次数据库，时间戳可能有微小差异，这里判断相等即可
          // 通常刚注册完第一次登录这两个时间是完全一样的
          final isFirstLogin = creationTime == lastSignInTime;
          
          if (isFirstLogin && mounted) {
            // 首次登录 → 跳转偏好页
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const PreferencePage()),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      // 处理 Firebase 认证异常
      String message = 'Login failed';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Incorrect email or password.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      // 处理其他异常
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // --- 忘记密码逻辑 (Dialog) ---
  Future<void> _showForgotPasswordDialog() async {
    final TextEditingController resetEmailController = TextEditingController();

    // 显示一个 Alert Dialog
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: TextField(
            controller: resetEmailController,
            decoration: const InputDecoration(hintText: 'Enter your email'),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Send'),
              onPressed: () {
                final email = resetEmailController.text.trim();
                if (email.isNotEmpty && email.contains('@')) {
                  // 在 Dialog 内部调用 AuthService
                  _sendResetEmail(email);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid email.'),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // --- 忘记密码逻辑 (调用 Service) ---
  Future<void> _sendResetEmail(String email) async {
    try {
      // 调用 AuthService 中你确认过的方法
      await _authService.sendPasswordResetEmail(email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Error sending email.';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('An unknown error occurred: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Card(
              elevation: 8.0,
              color: const Color(0xFFF5F5F5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Container(
                margin: EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- Logo ---
                    Icon(Icons.hotel, size: 60, color: Colors.black87),
                    Text(
                      'HotelEase',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 让三个按钮均匀分布，不用手写 Spacer 了
                      children: [
                        // --- 1. User 按钮 ---
                        GestureDetector(
                          onTap: () => setState(() => currentIndex = 0),
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              // 选中变深蓝灰，未选中透明
                              color: currentIndex == 0 ? const Color(0xFF313B53) : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF313B53), // 边框颜色统一
                                width: 2.0,
                              ),
                              // 选中时添加一点阴影，更有质感
                              boxShadow: currentIndex == 0
                                  ? [BoxShadow(color: const Color(0xFF313B53).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                                  : [],
                            ),
                            child: Center(
                              child: Text(
                                'User',
                                style: TextStyle(
                                  // 选中文字变白，未选中文字深蓝灰
                                  color: currentIndex == 0 ? Colors.white : const Color(0xFF313B53),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // --- 2. Staff 按钮 ---
                        GestureDetector(
                          onTap: () => setState(() => currentIndex = 1),
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: currentIndex == 1 ? const Color(0xFF313B53) : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF313B53), width: 2.0),
                              boxShadow: currentIndex == 1
                                  ? [BoxShadow(color: const Color(0xFF313B53).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                                  : [],
                            ),
                            child: Center(
                              child: Text(
                                'Staff',
                                style: TextStyle(
                                  color: currentIndex == 1 ? Colors.white : const Color(0xFF313B53),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // --- 3. Admin 按钮 ---
                        GestureDetector(
                          onTap: () => setState(() => currentIndex = 2),
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: currentIndex == 2 ? const Color(0xFF313B53) : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF313B53), width: 2.0),
                              boxShadow: currentIndex == 2
                                  ? [BoxShadow(color: const Color(0xFF313B53).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                                  : [],
                            ),
                            child: Center(
                              child: Text(
                                'Admin',
                                style: TextStyle(
                                  color: currentIndex == 2 ? Colors.white : const Color(0xFF313B53),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // --- Email 输入框 ---
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        hintText: 'Email/Phone No',
                        // 图片上的提示
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 16.0,
                          horizontal: 20.0,
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty ||
                            !value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // --- Password 输入框 ---
                    TextFormField(
                      controller: _passwordController,
                      // ✅ 绑定状态变量
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16.0,
                          horizontal: 20.0,
                        ),
                        // ✅ 新增：后缀图标（眼睛）
                        suffixIcon: IconButton(
                          icon: Icon(
                            // 根据状态显示不同的图标（睁眼/闭眼）
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            // 点击时切换状态
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // --- Login 按钮 ---
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton(
                        onPressed: _submit, // 调用登录逻辑
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // --- Forgot Password? 按钮 ---
                    TextButton(
                      onPressed: _showForgotPasswordDialog, // 调用弹窗
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // --- Register 按钮 ---
                    Container(
                      height: 40,
                      child: Visibility(
                        // 🔴 原代码: visible: currentIndex != 2, 
                        // ✅ 修改为: 只在 User (index 0) 界面显示
                        visible: currentIndex == 0, 
                        
                        child: TextButton(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterPage(),
                              ),
                            );
                            // 从注册页返回后，重置表单（清除错误提示）
                            if (mounted) {
                              _formKey.currentState?.reset();
                            }
                          },
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                              children: const <TextSpan>[
                                TextSpan(text: 'New to HotelEase? '),
                                TextSpan(
                                  text: 'Register',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
