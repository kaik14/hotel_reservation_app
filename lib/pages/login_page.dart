import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final AuthService _authService = AuthService(); // 实例化 AuthService

  // --- 登录逻辑 ---
  Future<void> _submit() async {
    // 检查表单验证是否通过
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // 调用 AuthService 的登录方法
      await _authService.signInWithEmailAndPassword(
        _emailController.text,
        _passwordController.text,
      );
      // 登录成功后，AuthGate 会自动处理页面跳转
    } on FirebaseAuthException catch (e) {
      // 处理 Firebase 认证异常
      String message = 'Login failed';
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        message = 'Incorrect email or password.';
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      // 处理其他异常
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('An unknown error occurred: $e')));
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // --- 忘记密码逻辑 (Dialog) ---
  Future<void> _showForgotPasswordDialog() async {
    final TextEditingController _resetEmailController = TextEditingController();
    
    // 显示一个 Alert Dialog
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: TextField(
            controller: _resetEmailController,
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
                final email = _resetEmailController.text.trim();
                if (email.isNotEmpty && email.contains('@')) {
                  // 在 Dialog 内部调用 AuthService
                  _sendResetEmail(email);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid email.')),
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
        const SnackBar(content: Text('Password reset email sent. Check your inbox.')),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Error sending email.';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('An unknown error occurred: $e')));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- Logo ---
                Icon(
                  Icons.hotel,
                  size: 60,
                  color: Colors.black87,
                ),
                Text(
                  'HotelEase',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 48),

                // --- Email 输入框 ---
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: 'Email/Phone No', // 图片上的提示
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
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
                  decoration: InputDecoration(
                    hintText: 'Password',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                  ),
                  obscureText: true,
                  validator: (value) {
                    // 登录时不检查复杂性，只检查非空
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
                    child: const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                TextButton(
                  onPressed: () async {
                    // 异步跳转
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const RegisterPage()),
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
                        TextSpan(
                          text: 'New to HotelEase? ',
                        ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

