import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hotel_reservation_app/services/auth_service.dart';
import 'package:hotel_reservation_app/services/database_service.dart';

class ManageEmployeesPage extends StatefulWidget {
  const ManageEmployeesPage({super.key});

  @override
  State<ManageEmployeesPage> createState() => _ManageEmployeesPageState();
}

class _ManageEmployeesPageState extends State<ManageEmployeesPage> {
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();

  // ✅ 定义统一的品牌色 (深蓝灰)
  final Color brandColor = const Color(0xFF313B53);

  // --- 添加员工对话框逻辑 ---
  void _showAddEmployeeDialog() {
    final _formKey = GlobalKey<FormState>();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final fNameCtrl = TextEditingController();
    final lNameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    
    // 状态变量定义在 StatefulBuilder 外部
    bool isLoading = false;
    bool obscurePassword = true; 

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // 使用 StatefulBuilder 来局部刷新弹窗内的状态
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add New Employee'),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: fNameCtrl,
                      decoration: const InputDecoration(labelText: 'First Name'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: lNameCtrl,
                      decoration: const InputDecoration(labelText: 'Last Name'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email (Login ID)'),
                      validator: (v) => v!.contains('@') ? null : 'Invalid email',
                    ),
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone Number'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    // 带眼睛开关的密码输入框
                    TextFormField(
                      controller: passCtrl,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        // 添加后缀图标
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword 
                                ? Icons.visibility_off 
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: obscurePassword, 
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        // 正则表达式验证：8位，大小写，数字
                        String pattern = r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d).{8,}$';
                        RegExp regex = RegExp(pattern);
                        
                        if (!regex.hasMatch(value)) {
                          return 'Min 8 chars, 1 Upper, 1 Lower, 1 Number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                // 按钮颜色也可以统一一下
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (_formKey.currentState!.validate()) {
                          setState(() => isLoading = true);
                          try {
                            await _authService.createStaffAccount(
                              emailCtrl.text.trim(),
                              passCtrl.text.trim(),
                              fNameCtrl.text.trim(),
                              lNameCtrl.text.trim(),
                              phoneCtrl.text.trim(),
                            );
                            if (mounted) {
                              Navigator.pop(context); // 关闭弹窗
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Staff added successfully!'),
                                    backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            setState(() => isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Add Staff'),
              ),
            ],
          );
        });
      },
    );
  }

  // --- 删除员工逻辑 ---
  void _confirmDelete(String uid, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Are you sure you want to remove $name? They will no longer be able to login.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await _dbService.deleteUserData(uid);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Manage Employees'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
          onPressed: () => Navigator.maybePop(context),
        ),
        centerTitle: true,
        // ✅ 1. 修改顶栏背景色
        backgroundColor: brandColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Add Employee',
            onPressed: _showAddEmployeeDialog,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'staff') 
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No staff members found.',
                  style: TextStyle(fontSize: 18, color: Colors.grey)),
            );
          }

          final employees = snapshot.data!.docs;

          return ListView.builder(
            itemCount: employees.length,
            padding: const EdgeInsets.only(top: 10),
            itemBuilder: (context, index) {
              final data = employees[index].data() as Map<String, dynamic>;
              final String firstName = data['firstName'] ?? '';
              final String lastName = data['lastName'] ?? '';
              final String fullName = '$firstName $lastName';
              final String email = data['email'] ?? 'No Email';
              final String phone = data['phoneNumber'] ?? 'No Phone';
              final String uid = data['uid'];

              final isMe = FirebaseAuth.instance.currentUser?.uid == uid;

              return Container(
                decoration: BoxDecoration(
                  // ✅ 2. 修改卡片背景色
                  color: brandColor, 
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                        style: TextStyle(
                            // ✅ 3. 修改头像文字颜色，与背景呼应
                            color: brandColor, 
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fullName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          Text('Email: $email',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                          Text('Phone: $phone',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (!isMe)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.white),
                        onPressed: () => _confirmDelete(uid, fullName),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}