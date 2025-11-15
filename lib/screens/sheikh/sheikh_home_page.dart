import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_project/provider/pro_login.dart';
import 'package:new_project/provider/lecture_provider.dart';
import 'package:new_project/screens/sheikh/add_lecture_form.dart';
import 'package:new_project/screens/sheikh/edit_lecture_page.dart';
import 'package:new_project/screens/sheikh/delete_lecture_page.dart';
import 'package:new_project/screens/sheikh/sheikh_hierarchy_manage_screen.dart';
import 'package:new_project/widgets/sheikh_guard.dart';
import 'package:new_project/widgets/section_selection_dialog.dart';

class SheikhHomePage extends StatefulWidget {
  const SheikhHomePage({super.key});

  @override
  State<SheikhHomePage> createState() => _SheikhHomePageState();
}

class _SheikhHomePageState extends State<SheikhHomePage> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final lectureProvider = Provider.of<LectureProvider>(
      context,
      listen: false,
    );

    final currentUid = authProvider.currentUid;
    if (currentUid != null) {
      await lectureProvider.loadSheikhLectures(currentUid);
      await lectureProvider.loadSheikhStats(currentUid);
    }
    setState(() => _isLoading = false);
  }

  void _navigateToAdd() async {
    // Show dialog for section selection instead of navigating to full-screen page
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const SectionSelectionDialog(),
    );

    // If a section was selected (result == true), navigate to AddLectureForm
    if (result == true && mounted) {
      final addResult = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddLectureForm()),
      );

      // Reload data if lecture was added successfully
      if (addResult == true && mounted) {
        await _loadData();
      }
    }
  }

  void _navigateToEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditLecturePage()),
    );

    // Reload data if lecture was edited successfully
    if (result == true && mounted) {
      await _loadData();
    }
  }

  void _navigateToDelete() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DeleteLecturePage()),
    );

    // Reload data if lecture was deleted successfully
    if (result == true && mounted) {
      await _loadData();
    }
  }

  void _navigateToHierarchyManage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SheikhHierarchyManageScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SheikhGuard(
      routeName: '/sheikh/home',
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFE4E5D3),
          appBar: AppBar(
            title: Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return Column(
                  children: [
                    Text('مرحباً الشيخ ${authProvider.displayName}'),
                    if (authProvider.currentUser?['categoryId'] != null)
                      Chip(
                        label: Text(
                          'القسم: ${_getCategoryName(authProvider.currentUser?['categoryId'])}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: const Color(0xFFC5A300),
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                  ],
                );
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
                  await authProvider.signOut();
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/guest',
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
                      Consumer<LectureProvider>(
                        builder: (context, lectureProvider, child) {
                          final stats = lectureProvider.sheikhStats;
                          final totalLectures = stats?['totalLectures'] ?? 0;

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.library_books,
                                  color: Colors.green,
                                  size: 30,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'إجمالي المحاضرات',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      '$totalLectures',
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
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Sheikh stats KPI
                      Consumer<LectureProvider>(
                        builder: (context, lectureProvider, child) {
                          final stats = lectureProvider.sheikhStats;
                          final upcomingToday = stats?['upcomingToday'] ?? 0;

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.today,
                                  color: Colors.blue,
                                  size: 30,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'المحاضرات اليوم',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      '$upcomingToday',
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
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // الأزرار الرئيسية
                      ElevatedButton.icon(
                        onPressed: _navigateToAdd,
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة'),
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
                        onPressed: _navigateToEdit,
                        icon: const Icon(Icons.edit),
                        label: const Text('تعديل'),
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
                        onPressed: _navigateToDelete,
                        icon: const Icon(Icons.delete),
                        label: const Text('إزالة'),
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
                        onPressed: _navigateToHierarchyManage,
                        icon: const Icon(Icons.category),
                        label: const Text('إدارة التصنيفات'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // معلومات إضافية
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, child) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'مسجل دخول كشيخ: ${authProvider.currentUser?['email'] ?? 'غير محدد'}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  String _getCategoryName(String? categoryId) {
    // Map category IDs to Arabic names
    switch (categoryId) {
      case 'fiqh':
        return 'الفقه';
      case 'seerah':
        return 'السيرة';
      case 'tafsir':
        return 'التفسير';
      case 'hadith':
        return 'الحديث';
      default:
        return 'غير محدد';
    }
  }
}
