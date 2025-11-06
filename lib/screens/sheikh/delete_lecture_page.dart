import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_project/provider/pro_login.dart';
import 'package:new_project/provider/lecture_provider.dart';
import 'package:new_project/provider/hierarchy_provider.dart';
import 'package:new_project/widgets/sheikh_guard.dart';
import 'package:new_project/utils/time.dart';

class DeleteLecturePage extends StatefulWidget {
  const DeleteLecturePage({super.key});

  @override
  State<DeleteLecturePage> createState() => _DeleteLecturePageState();
}

class _DeleteLecturePageState extends State<DeleteLecturePage> {
  List<Map<String, dynamic>> _lectures = [];
  List<Map<String, dynamic>> _archivedLectures = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLectures();
  }

  Future<void> _loadLectures() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final lectureProvider = Provider.of<LectureProvider>(
      context,
      listen: false,
    );

    final currentUid = authProvider.currentUid;
    if (currentUid != null) {
      await lectureProvider.loadSheikhLectures(currentUid);
      setState(() {
        _lectures = lectureProvider.sheikhLectures
            .where(
              (lecture) =>
                  lecture['status'] != 'deleted' &&
                  lecture['status'] != 'archived',
            )
            .toList();
        _archivedLectures = lectureProvider.sheikhLectures
            .where((lecture) => lecture['status'] == 'archived')
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'غير مصرح بالوصول';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheikhGuard(
      routeName: '/sheikh/delete',
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFE4E5D3),
          appBar: AppBar(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            title: const Text('حذف المحاضرات'),
            iconTheme: const IconThemeData(color: Colors.white),
            centerTitle: true,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? _buildErrorWidget()
              : _lectures.isEmpty && _archivedLectures.isEmpty
              ? _buildEmptyWidget()
              : _buildLecturesList(),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'خطأ غير معروف',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadLectures,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'لا توجد محاضرات للحذف',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'قم بإضافة محاضرات جديدة أولاً',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildLecturesList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red[700]),
              const SizedBox(width: 8),
              Text(
                'اختر المحاضرة للحذف',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Active lectures section
              if (_lectures.isNotEmpty) ...[
                _buildSectionHeader(
                  'المحاضرات النشطة',
                  Colors.red[700] ?? Colors.red,
                ),
                const SizedBox(height: 8),
                ..._lectures.map(
                  (lecture) => _buildLectureCard(lecture, false),
                ),
                const SizedBox(height: 24),
              ],
              // Archived lectures section
              if (_archivedLectures.isNotEmpty) ...[
                _buildSectionHeader(
                  'المحاضرات المؤرشفة',
                  Colors.orange[700] ?? Colors.orange,
                ),
                const SizedBox(height: 8),
                ..._archivedLectures.map(
                  (lecture) => _buildLectureCard(lecture, true),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.folder, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLectureCard(Map<String, dynamic> lecture, bool isArchived) {
    // Null-safe field extraction
    final title = lecture['title']?.toString() ?? 'بدون عنوان';
    final categoryName =
        lecture['categoryName']?.toString() ??
        lecture['categoryNameAr']?.toString() ??
        'غير محدد';
    // Use safe date conversion - handles Timestamp, int (epoch ms), String, DateTime
    final startTime = safeDateFromDynamic(lecture['startTime']);
    final status = lecture['status']?.toString() ?? 'draft';
    final description = lecture['description']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => isArchived
            ? _showPermanentDeleteDialog(lecture)
            : _showDeleteDialog(lecture),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.delete, color: Colors.red[600], size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (categoryName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.category, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      categoryName,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
              if (startTime != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'الوقت: ${_formatDateTime(startTime)}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    isArchived ? Icons.delete_forever : Icons.touch_app,
                    size: 16,
                    color: isArchived ? Colors.red[600] : Colors.red[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isArchived ? 'اضغط للحذف النهائي' : 'اضغط للحذف',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'published':
        return Colors.green;
      case 'draft':
        return Colors.orange;
      case 'archived':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'published':
        return 'منشور';
      case 'draft':
        return 'مسودة';
      case 'archived':
        return 'مؤرشف';
      default:
        return 'غير محدد';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showDeleteDialog(Map<String, dynamic> lecture) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('هل أنت متأكد من حذف المحاضرة:'),
              const SizedBox(height: 8),
              Text(
                lecture['title']?.toString() ?? 'بدون عنوان',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange[200] ?? Colors.orange,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سيتم أرشفة المحاضرة أولاً. يمكنك حذفها نهائياً لاحقاً.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _archiveLecture(lecture);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('أرشفة'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showPermanentDeleteDialog(lecture);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('حذف نهائي'),
            ),
          ],
        );
      },
    );
  }

  void _showPermanentDeleteDialog(Map<String, dynamic> lecture) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('حذف نهائي'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('هل أنت متأكد من الحذف النهائي للمحاضرة:'),
              const SizedBox(height: 8),
              Text(
                lecture['title']?.toString() ?? 'بدون عنوان',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200] ?? Colors.red),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تحذير: لا يمكن التراجع عن هذا الإجراء!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _permanentlyDeleteLecture(lecture);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('حذف نهائي'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _archiveLecture(Map<String, dynamic> lecture) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final lectureProvider = Provider.of<LectureProvider>(
      context,
      listen: false,
    );

    final currentUid = authProvider.currentUid;
    if (currentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطأ: لم يتم العثور على معرف المستخدم')),
      );
      return;
    }

    final lectureId = lecture['id']?.toString();
    if (lectureId == null || lectureId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطأ: معرف المحاضرة غير صحيح')),
      );
      return;
    }

    final success = await lectureProvider.archiveSheikhLecture(
      lectureId: lectureId,
      sheikhId: currentUid,
    );

    if (success) {
      // Refresh home hierarchy after successful archive
      final hierarchyProvider = Provider.of<HierarchyProvider>(
        context,
        listen: false,
      );
      hierarchyProvider.clearHomeHierarchyCache();
      hierarchyProvider.loadHomeHierarchy(forceRefresh: true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم أرشفة المحاضرة بنجاح'),
          backgroundColor: Colors.orange,
        ),
      );
      _loadLectures(); // Reload the list
      // Pop with refresh=true if this was the last lecture
      if (_lectures.length <= 1 && _archivedLectures.isEmpty) {
        Navigator.pop(context, true);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lectureProvider.errorMessage ?? 'حدث خطأ في أرشفة المحاضرة',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _permanentlyDeleteLecture(Map<String, dynamic> lecture) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final lectureProvider = Provider.of<LectureProvider>(
      context,
      listen: false,
    );

    final currentUid = authProvider.currentUid;
    if (currentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطأ: لم يتم العثور على معرف المستخدم')),
      );
      return;
    }

    final lectureId = lecture['id']?.toString();
    if (lectureId == null || lectureId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطأ: معرف المحاضرة غير صحيح')),
      );
      return;
    }

    final success = await lectureProvider.deleteSheikhLecture(
      lectureId: lectureId,
      sheikhId: currentUid,
    );

    if (success) {
      // Refresh home hierarchy after successful delete
      final hierarchyProvider = Provider.of<HierarchyProvider>(
        context,
        listen: false,
      );
      hierarchyProvider.clearHomeHierarchyCache();
      hierarchyProvider.loadHomeHierarchy(forceRefresh: true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف المحاضرة نهائياً'),
          backgroundColor: Colors.red,
        ),
      );
      _loadLectures(); // Reload the list
      // Pop with refresh=true if this was the last lecture
      if (_lectures.isEmpty && _archivedLectures.length <= 1) {
        Navigator.pop(context, true);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lectureProvider.errorMessage ?? 'حدث خطأ في حذف المحاضرة',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
