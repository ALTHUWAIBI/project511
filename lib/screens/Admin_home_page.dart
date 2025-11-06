import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_project/offline/firestore_shims.dart';
import 'package:new_project/database/firebase_service.dart';
import 'package:new_project/screens/admin_panel_page.dart';
import 'package:new_project/screens/admin_sheikh_list_page.dart';
import 'package:new_project/screens/home_page.dart';
import 'package:new_project/services/sheikh_service.dart';
import 'package:new_project/provider/pro_login.dart';
import 'package:new_project/utils/time.dart';
import '../utils/page_transition.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final SheikhService _sheikhService = SheikhService();
  List<Map<String, dynamic>> _users = [];
  int _sheikhCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final users = await _firebaseService.getAllUsers();
      final sheikhCount = await _sheikhService.countSheikhs();
      setState(() {
        _users = users;
        _sheikhCount = sheikhCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorMessage('خطأ في تحميل البيانات: $e');
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _navigateToLectureManagement(BuildContext context) {
    SmoothPageTransition.navigateTo(
      context,
      const AdminLectureManagementPage(),
    );
  }

  void _navigateToDelete(BuildContext context) {
    if (_users.isEmpty) {
      _showErrorMessage('لا توجد مستخدمين للحذف');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف مستخدم'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(user['username']),
                subtitle: Text(user['email']),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteUser(user['id'], user['username']),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(String userId, String username) async {
    Navigator.of(context).pop(); // إغلاق الحوار الأول

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف المستخدم "$username"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _firebaseService.deleteUser(userId);

      if (success) {
        _showSuccessMessage('تم حذف المستخدم "$username" بنجاح');
        _loadData();
      } else {
        _showErrorMessage('فشل في حذف المستخدم');
      }
    }
  }

  void _navigateToEdit(BuildContext context) {
    if (_users.isEmpty) {
      _showErrorMessage('لا توجد مستخدمين للتعديل');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('عرض المستخدمين'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              // Use safe date conversion - handles Timestamp, int (epoch ms), String, DateTime
              final createdAt =
                  safeDateFromDynamic(user['created_at']) ?? DateTime.now();

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade200,
                    child: Text(user['username'][0]),
                  ),
                  title: Text(user['username']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user['email']),
                      Text(
                        'تاريخ التسجيل: ${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  trailing: Icon(
                    Icons.verified_user,
                    color: Colors.green.shade400,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showDeleteSheikhDialog(BuildContext context) {
    final uniqueIdController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AlertDialog(
          title: const Text('حذف شيخ بالمعرّف الفريد'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('أدخل المعرّف الفريد للشيخ:'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: uniqueIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المعرّف الفريد',
                      hintText: '3 أو 00000003',
                      border: OutlineInputBorder(),
                      helperText: 'يمكن إدخال 3 أو 00000003',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'يرجى إدخال المعرّف الفريد';
                      }
                      final normalized = _normalizeUniqueId(value.trim());
                      if (normalized.length != 8) {
                        return 'المعرّف الفريد غير صحيح';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      // Auto-format as user types
                      final normalized = _normalizeUniqueId(value);
                      if (normalized != value && normalized.length <= 8) {
                        uniqueIdController.value = TextEditingValue(
                          text: normalized,
                          selection: TextSelection.collapsed(
                            offset: normalized.length,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.of(context).pop();
              },
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final uniqueId = _normalizeUniqueId(
                  uniqueIdController.text.trim(),
                );
                FocusScope.of(context).unfocus();
                Navigator.of(context).pop();
                await _deleteSheikhByUniqueId(uniqueId);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }

  // Normalize input: trim, digits-only, left-pad to 8; keep as STRING
  String _normalizeUniqueId(String input) {
    // Remove all non-digit characters
    final digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');

    // Left-pad to 8 digits
    return digitsOnly.padLeft(8, '0');
  }

  Future<void> _deleteSheikhByUniqueId(String uniqueId) async {
    try {
      setState(() => _isLoading = true);

      // Check if user is admin
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.role != 'admin') {
        _showErrorMessage('هذه العملية مخصصة للمشرفين فقط');
        return;
      }

      print('[DeleteSheikh] Searching for sheikh with uniqueId: $uniqueId');

      final result = await _firebaseService.deleteSheikhByUniqueId(uniqueId);

      if (result['success'] == true) {
        _showSuccessMessage('تم حذف الشيخ بالمعرّف $uniqueId بنجاح');
        _loadData(); // Refresh the data
      } else {
        final message = result['message'] ?? 'لا يوجد شيخ بهذا المعرّف';
        _showErrorMessage(message);
      }
    } catch (e) {
      print('[DeleteSheikh] Error: $e');
      _showErrorMessage('حدث خطأ في حذف الشيخ: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE4E5D3),
      appBar: AppBar(
        title: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return Text('مرحباً ${authProvider.displayName}');
          },
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'تحديث',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              await authProvider.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HomePage(toggleTheme: (isDark) {}),
                  ),
                  (route) => false,
                );
              }
            },
            tooltip: 'تسجيل خروج',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // معلومات سريعة
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people, color: Colors.green, size: 30),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'إجمالي المستخدمين',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '${_users.length}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sheikh count KPI
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminSheikhListPage(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.school,
                            color: Colors.blue,
                            size: 30,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'إجمالي الشيوخ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                '$_sheikhCount',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.blue.shade400,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // الأزرار الرئيسية
                  ElevatedButton.icon(
                    onPressed: () => _navigateToLectureManagement(context),
                    icon: const Icon(Icons.library_books),
                    label: const Text('إدارة المحاضرات'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/admin/add-sheikh');
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('إضافة شيخ جديد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: () => _navigateToDelete(context),
                    icon: const Icon(Icons.delete),
                    label: const Text('إدارة المستخدمين (حذف)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: () => _navigateToEdit(context),
                    icon: const Icon(Icons.visibility),
                    label: const Text('عرض المستخدمين'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Delete Sheikh by UniqueId Button
                  ElevatedButton.icon(
                    onPressed: () => _showDeleteSheikhDialog(context),
                    icon: const Icon(Icons.person_remove),
                    label: const Text('حذف شيخ بالمعرّف الفريد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // معلومات إضافية
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Consumer<AuthProvider>(
                      builder: (context, authProvider, child) {
                        final adminEmail =
                            authProvider.currentUser?['email'] ?? 'غير محدد';
                        return Text(
                          'مسجل دخول كمشرف: $adminEmail',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
