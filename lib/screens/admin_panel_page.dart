import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_project/database/firebase_service.dart';
import 'package:new_project/provider/lecture_provider.dart';
import 'package:new_project/screens/add_lecture_page.dart';
import 'package:new_project/screens/Edit_Lecture_Page.dart';
import 'package:new_project/screens/Delete_Lecture_Page.dart';
import 'package:new_project/utils/section_utils.dart';
import '../utils/page_transition.dart';

class AdminLectureManagementPage extends StatefulWidget {
  const AdminLectureManagementPage({super.key});

  @override
  State<AdminLectureManagementPage> createState() =>
      _AdminLectureManagementPageState();
}

class _AdminLectureManagementPageState
    extends State<AdminLectureManagementPage> {
  final FirebaseService _firebaseService = FirebaseService();
  Map<String, int> _lectureStats = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final lectures = await _firebaseService.getAllLectures();

      Map<String, int> stats = {
        'الفقه': 0,
        'التفسير': 0,
        'الحديث': 0,
        'السيرة': 0,
      };

      for (var lecture in lectures) {
        // Normalize section key (handles both English keys like "fiqh" and Arabic names)
        final sectionKey = normalizeSectionKey(lecture['section']?.toString());
        // Convert to Arabic name for counting
        final sectionNameAr = getSectionNameAr(sectionKey);
        // Only count if it's a valid section
        if (stats.containsKey(sectionNameAr)) {
          stats[sectionNameAr] = (stats[sectionNameAr] ?? 0) + 1;
        }
      }

      setState(() {
        _lectureStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToAddLecture() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر القسم', textAlign: TextAlign.right),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionButton('الفقه', Icons.menu_book, Colors.blue),
            const SizedBox(height: 8),
            _buildSectionButton('التفسير', Icons.book, Colors.green),
            const SizedBox(height: 8),
            _buildSectionButton('الحديث', Icons.format_quote, Colors.orange),
            const SizedBox(height: 8),
            _buildSectionButton('السيرة', Icons.history_edu, Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionButton(String section, IconData icon, Color color) {
    return ElevatedButton.icon(
      onPressed: () async {
        Navigator.pop(context);
        final result = await SmoothPageTransition.navigateTo(
          context,
          AddLecturePage(section: section),
        );
        if (result == true) {
          _loadStats();
          // Refresh lecture provider
          if (mounted) {
            Provider.of<LectureProvider>(
              context,
              listen: false,
            ).loadAllSections();
          }
        }
      },
      icon: Icon(icon),
      label: Text(section),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  void _navigateToEditLectures() {
    SmoothPageTransition.navigateTo(context, const EditLecturePage()).then((_) {
      _loadStats();
      // Refresh lecture provider
      Provider.of<LectureProvider>(context, listen: false).loadAllSections();
    });
  }

  void _navigateToDeleteLectures() {
    SmoothPageTransition.navigateTo(context, const DeleteLecturePage()).then((
      _,
    ) {
      _loadStats();
      // Refresh lecture provider
      Provider.of<LectureProvider>(context, listen: false).loadAllSections();
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalLectures = _lectureStats.values.fold(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المحاضرات'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'تحديث',
          ),
        ],
      ),
      backgroundColor: const Color(0xFFE4E5D3),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // إحصائيات عامة
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.shade200,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.library_books,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'إجمالي المحاضرات',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              '$totalLectures',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // إحصائيات حسب القسم
                  const Text(
                    'المحاضرات حسب الأقسام',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'الفقه',
                          _lectureStats['الفقه'] ?? 0,
                          Colors.blue,
                          Icons.menu_book,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'التفسير',
                          _lectureStats['التفسير'] ?? 0,
                          Colors.green,
                          Icons.book,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'الحديث',
                          _lectureStats['الحديث'] ?? 0,
                          Colors.orange,
                          Icons.format_quote,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'السيرة',
                          _lectureStats['السيرة'] ?? 0,
                          Colors.purple,
                          Icons.history_edu,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // أزرار الإدارة
                  const Text(
                    'العمليات',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: _navigateToAddLecture,
                    icon: const Icon(Icons.add_circle_outline, size: 28),
                    label: const Text(
                      'إضافة محاضرة جديدة',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: _navigateToEditLectures,
                    icon: const Icon(Icons.edit, size: 28),
                    label: const Text(
                      'تعديل المحاضرات',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: _navigateToDeleteLectures,
                    icon: const Icon(Icons.delete_outline, size: 28),
                    label: const Text(
                      'حذف المحاضرات',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ملاحظة
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'يمكنك إضافة وتعديل وحذف المحاضرات من هنا. المحاضرات مقسمة حسب الأقسام: الفقه، التفسير، الحديث، والسيرة.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
