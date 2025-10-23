import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hotel_reservation_app/services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  final AuthService _authService = AuthService();

  // 提交表单的方法
  Future<void> _submit() async {
    // 1. 检查表单验证是否通过
    if (!_formKey.currentState!.validate()) return;

    // 2. 进入加载状态
    setState(() => _isLoading = true);

    try {
      // 3. 调用我们更新后的注册方法
      await _authService.registerWithEmailAndPassword(
        _emailController.text,
        _passwordController.text,
        _firstNameController.text,
        _lastNameController.text,
        _phoneController.text,
      );

      // 4. 注册成功后，AuthGate 会自动处理跳转，
      //    但由于我们是 PUSH 进来的，最好是 pop 回去
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      // 5. 处理 Firebase Auth 异常
      String message = 'Registration failed';
      if (e.code == 'email-already-in-use') {
        message = 'This email is already in use.';
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      // 6. 处理其他异常
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('An unknown error occurred: $e')));
    }

    // 7. 结束加载状态
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0), // 与登录页一致的边距
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- Logo ---
                Icon(
                  Icons.hotel, // 使用酒店图标
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

                // --- First Name 输入框 ---
                TextFormField(
                  controller: _firstNameController,
                  decoration: InputDecoration(
                    hintText: 'First Name',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                  ),
                  validator: (val) =>
                      val!.isEmpty ? 'Please enter your first name' : null,
                ),
                const SizedBox(height: 16), // 调整间距

                // --- Last Name 输入框 ---
                TextFormField(
                  controller: _lastNameController,
                  decoration: InputDecoration(
                    hintText: 'Last Name',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                  ),
                  validator: (val) =>
                      val!.isEmpty ? 'Please enter your last name' : null,
                ),
                const SizedBox(height: 16),

                // --- Phone Number 输入框 ---
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    hintText: 'Phone Number',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (val) =>
                      val!.isEmpty ? 'Please enter your phone number' : null,
                ),
                const SizedBox(height: 16),

                // --- Email 输入框 ---
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: 'Email',
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
                  validator: (val) => (val!.isEmpty || !val.contains('@'))
                      ? 'Please enter a valid email'
                      : null,
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
                    //
                    // ✅ 重点改进：添加 helperText 
                    //
                    helperText:
                        'Must be 8+ characters, with uppercase, lowercase, and a number.',
                    helperMaxLines:
                        2, // 允许帮助文本换行，防止溢出
                    helperStyle: TextStyle(
                        color: Colors.grey[600]), // 给帮助文本一个柔和的颜色
                  ),
                  obscureText: true,
                  //
                  // ✅ 重点：验证逻辑保持不变，它会在提交时检查所有规则
                  //
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please enter a password'; // 提示1：空的
                    }
                    if (val.length < 8) {
                      return 'Password must be 8+ characters'; // 提示2：长度
                    }
                    if (!val.contains(RegExp(r'[A-Z]'))) {
                      return 'Must include an uppercase letter'; // S 提示3：大写
                    }
                    if (!val.contains(RegExp(r'[a-z]'))) {
                      return 'Must include a lowercase letter'; // 提示4：小写
                    }
                    if (!val.contains(RegExp(r'\d'))) {
                      return 'Must include one number'; // 提示5：数字
                    }
                    return null; // 全部通过
                  },
                ),
                const SizedBox(height: 32), // 调整间距

                // --- 注册按钮 ---
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black, // 黑色背景
                      foregroundColor: Colors.white, // 白色文字
                      minimumSize: const Size(double.infinity, 50), // 撑满宽度
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    child: const Text('Register',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),

                const SizedBox(height: 20),

                // --- 返回登录页按钮 ---
                TextButton(
                  onPressed: () {
                    // 关闭注册页，返回上一页（即登录页）
                    Navigator.pop(context);
                  },
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                      children: const <TextSpan>[
                        TextSpan(
                          text: 'Already have an account? ',
                        ),
                        TextSpan(
                          text: 'Login',
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

