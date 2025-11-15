import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_project/provider/pro_login.dart';
import 'package:new_project/provider/lecture_provider.dart';
import 'package:new_project/utils/time.dart';
import 'package:new_project/widgets/sheikh_guard.dart';
import 'dart:convert';

/// Screen that displays a filtered list of lectures for the current sheikh
/// Filter can be "all" (all lectures) or "today" (only today's lectures)
class SheikhLecturesListPage extends StatefulWidget {
  final String filter; // "all" or "today"

  const SheikhLecturesListPage({super.key, required this.filter});

  @override
  State<SheikhLecturesListPage> createState() => _SheikhLecturesListPageState();
}

class _SheikhLecturesListPageState extends State<SheikhLecturesListPage> {
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
    }
    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> _getFilteredLectures() {
    final lectureProvider = Provider.of<LectureProvider>(
      context,
      listen: false,
    );
    final allLectures = lectureProvider.sheikhLectures;

    if (widget.filter == 'today') {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);

      return allLectures.where((lecture) {
        final startTime = safeDateFromDynamic(lecture['startTime']);
        if (startTime == null) return false;

        // Convert to local date for comparison (ignore time)
        final lectureDate = DateTime(
          startTime.year,
          startTime.month,
          startTime.day,
        );

        // Check if lecture start date is on the same calendar day as today
        return lectureDate.year == todayDate.year &&
            lectureDate.month == todayDate.month &&
            lectureDate.day == todayDate.day;
      }).toList();
    } else {
      // Filter "all" - return all lectures
      return allLectures;
    }
  }

  String _getPageTitle() {
    return widget.filter == 'today' ? 'المحاضرات اليوم' : 'إجمالي المحاضرات';
  }

  @override
  Widget build(BuildContext context) {
    return SheikhGuard(
      routeName: '/sheikh/lectures/list',
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFE4E5D3),
          appBar: AppBar(
            title: Text(_getPageTitle()),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
                tooltip: 'تحديث',
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Consumer<LectureProvider>(
                  builder: (context, lectureProvider, child) {
                    final lectures = _getFilteredLectures();

                    if (lectures.isEmpty) {
                      return _buildEmptyState();
                    }

                    return RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: lectures.length,
                        itemBuilder: (context, index) {
                          return _buildLectureCard(lectures[index]);
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'لا توجد محاضرات',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            widget.filter == 'today'
                ? 'لا توجد محاضرات مجدولة لهذا اليوم'
                : 'لم يتم إضافة محاضرات بعد',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildLectureCard(Map<String, dynamic> lecture) {
    final title = lecture['title']?.toString() ?? 'بدون عنوان';
    final section = lecture['section']?.toString() ?? '';
    final categoryName = lecture['categoryName']?.toString() ?? '';
    final startTime = safeDateFromDynamic(lecture['startTime']);
    final location = lecture['location'];
    String? locationLabel;
    if (location != null) {
      if (location is Map) {
        locationLabel = location['label']?.toString();
      } else if (location is String) {
        // If it's a JSON string, try to parse it
        if (location.trim().startsWith('{')) {
          try {
            final decoded = jsonDecode(location);
            if (decoded is Map) {
              locationLabel = decoded['label']?.toString();
            }
          } catch (e) {
            // If parsing fails, use the string as-is
            locationLabel = location;
          }
        } else {
          // If it's a plain string, use it directly
          locationLabel = location;
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),

            // Section and Category
            if (section.isNotEmpty || categoryName.isNotEmpty) ...[
              Row(
                children: [
                  if (section.isNotEmpty) ...[
                    Icon(Icons.category, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _getSectionNameAr(section),
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                  if (section.isNotEmpty && categoryName.isNotEmpty)
                    Text(' • ', style: TextStyle(color: Colors.grey[600])),
                  if (categoryName.isNotEmpty)
                    Text(
                      categoryName,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Date and Time
            if (startTime != null) ...[
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(startTime),
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Location
            if (locationLabel != null && locationLabel.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      locationLabel,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getSectionNameAr(String section) {
    switch (section.toLowerCase()) {
      case 'fiqh':
        return 'الفقه';
      case 'hadith':
        return 'الحديث';
      case 'seerah':
        return 'السيرة';
      case 'tafsir':
        return 'التفسير';
      default:
        return section;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} - ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
