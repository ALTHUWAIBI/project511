import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_project/offline/firestore_shims.dart';
import 'package:new_project/provider/lecture_provider.dart';
import 'package:new_project/utils/time.dart';
import '../widgets/app_drawer.dart';

class SubcategoryLecturesPage extends StatefulWidget {
  final String subcategoryId;
  final String subcategoryName;
  final String section;
  final bool isDarkMode;
  final Function(bool)? toggleTheme;

  const SubcategoryLecturesPage({
    super.key,
    required this.subcategoryId,
    required this.subcategoryName,
    required this.section,
    required this.isDarkMode,
    this.toggleTheme,
  });

  @override
  State<SubcategoryLecturesPage> createState() =>
      _SubcategoryLecturesPageState();
}

class _SubcategoryLecturesPageState extends State<SubcategoryLecturesPage> {
  List<Map<String, dynamic>> _lectures = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Load lectures after the build phase to avoid setState during build error
    Future.microtask(() => _loadLectures());
  }

  Future<void> _loadLectures() async {
    setState(() {
      _isLoading = true;
    });

    final lectureProvider = Provider.of<LectureProvider>(
      context,
      listen: false,
    );
    final lectures = await lectureProvider.loadLecturesBySubcategory(
      widget.subcategoryId,
    );

    setState(() {
      _lectures = lectures;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFE4E5D3),
      appBar: AppBar(
        title: Text(widget.subcategoryName),
        centerTitle: true,
        backgroundColor: Colors.green,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLectures),
          if (widget.toggleTheme != null)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
        ],
      ),
      drawer: widget.toggleTheme != null
          ? AppDrawer(toggleTheme: widget.toggleTheme!)
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lectures.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.library_books, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد محاضرات في هذه الفئة',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView.builder(
                itemCount: _lectures.length,
                itemBuilder: (context, index) {
                  final lecture = _lectures[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: widget.isDarkMode
                        ? const Color(0xFF1E1E1E)
                        : Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: Colors.green,
                        radius: 30,
                        child: Icon(
                          _getSectionIcon(widget.section),
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      title: Text(
                        lecture['title'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            lecture['description']?.toString() ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(lecture['created_at']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: lecture['video_path'] != null
                          ? const Icon(Icons.video_library, color: Colors.green)
                          : null,
                      onTap: () {
                        _showLectureDetails(context, lecture);
                      },
                    ),
                  );
                },
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        backgroundColor: widget.isDarkMode
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'الإشعارات',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.popUntil(context, (route) => route.isFirst);
          }
        },
      ),
    );
  }

  IconData _getSectionIcon(String section) {
    switch (section) {
      case 'الفقه':
        return Icons.library_books;
      case 'الحديث':
        return Icons.auto_stories;
      case 'التفسير':
        return Icons.menu_book;
      case 'السيرة':
        return Icons.book;
      default:
        return Icons.library_books;
    }
  }

  String _formatDate(dynamic dateValue) {
    try {
      DateTime date;
      if (dateValue is Timestamp) {
        date = dateValue.toDate();
      } else if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        date = dateValue;
      } else {
        return 'تاريخ غير صالح';
      }
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'تاريخ غير صالح';
    }
  }

  void _showLectureDetails(BuildContext context, Map<String, dynamic> lecture) {
    // Null-safe field extraction
    final title = lecture['title']?.toString() ?? 'بدون عنوان';
    final description = lecture['description']?.toString() ?? '';
    final videoPath = lecture['video_path']?.toString();
    final createdAt = safeDateFromDynamic(
      lecture['createdAt'] ?? lecture['created_at'],
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (description.isNotEmpty) ...[
                const Text(
                  'الوصف:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(description),
                const SizedBox(height: 16),
              ],
              if (videoPath != null && videoPath.isNotEmpty) ...[
                const Text(
                  'يحتوي على فيديو',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (createdAt != null)
                Text(
                  'تاريخ الإضافة: ${_formatDate(createdAt)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
