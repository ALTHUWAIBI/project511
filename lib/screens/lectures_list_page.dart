import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_project/provider/hierarchy_provider.dart';
import 'package:new_project/utils/youtube_utils.dart';
import 'package:new_project/screens/lecture_detail_screen.dart';
import 'package:new_project/offline/firestore_shims.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import '../widgets/app_drawer.dart';

class LecturesListPage extends StatefulWidget {
  final String section;
  final String sectionNameAr;
  final String categoryId;
  final String categoryName;
  final String? subcategoryId;
  final String? subcategoryName;
  final bool isDarkMode;
  final Function(bool)? toggleTheme;

  const LecturesListPage({
    super.key,
    required this.section,
    required this.sectionNameAr,
    required this.categoryId,
    required this.categoryName,
    this.subcategoryId,
    this.subcategoryName,
    required this.isDarkMode,
    this.toggleTheme,
  });

  @override
  State<LecturesListPage> createState() => _LecturesListPageState();
}

class _LecturesListPageState extends State<LecturesListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFE4E5D3),
      appBar: AppBar(
        title: Text(widget.subcategoryName ?? widget.categoryName),
        centerTitle: true,
        backgroundColor: Colors.green,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
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
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Provider.of<HierarchyProvider>(context, listen: false)
            .getLecturesStream(
              section: widget.section,
              categoryId: widget.categoryId,
              subcategoryId: widget.subcategoryId,
            ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    'خطأ في تحميل المحاضرات',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(fontSize: 14, color: Colors.red[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {});
                    },
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          final lectures = snapshot.data ?? [];

          if (lectures.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد محاضرات متاحة',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سيتم عرض المحاضرات هنا عند إضافتها',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'محاضرات ${widget.subcategoryName ?? widget.categoryName}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: lectures.length,
                    itemBuilder: (context, index) {
                      final lecture = lectures[index];
                      return _buildLectureCard(lecture);
                    },
                  ),
                ),
              ],
            ),
          );
        },
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

  Widget _buildLectureCard(Map<String, dynamic> lecture) {
    // Check for videoId - only show video icon if videoId exists
    final videoId = lecture['videoId']?.toString();
    final videoUrl =
        lecture['video_path']?.toString() ??
        lecture['media']?['videoUrl']?.toString();
    final hasVideo =
        (videoId != null && videoId.isNotEmpty) ||
        (videoUrl != null &&
            videoUrl.isNotEmpty &&
            YouTubeUtils.extractVideoId(videoUrl) != null);

    // Check for PDF attachment
    final pdfUrl = lecture['pdfUrl']?.toString();
    final hasPdf = pdfUrl != null && pdfUrl.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.green,
          radius: 24,
          child: const Icon(Icons.video_library, color: Colors.white, size: 20),
        ),
        title: Text(
          lecture['title'] ?? 'بدون عنوان',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sheikh name
            if (_getSheikhName(lecture) != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'الشيخ: ${_getSheikhName(lecture)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
            if (lecture['description'] != null &&
                lecture['description'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  lecture['description']?.toString() ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),
            if (lecture['startTime'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'وقت البداية: ${_formatDateTime(lecture['startTime'])}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasPdf)
              GestureDetector(
                onTap: () => _openPdf(lecture),
                child: const Icon(
                  Icons.picture_as_pdf,
                  color: Colors.red,
                  size: 24,
                ),
              ),
            if (hasPdf) const SizedBox(width: 8),
            if (hasVideo)
              const Icon(Icons.play_circle_filled, color: Colors.red, size: 24)
            else
              const Icon(Icons.video_library, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, color: Colors.green, size: 16),
          ],
        ),
        onTap: () => _showLectureDetails(lecture),
      ),
    );
  }

  void _showLectureDetails(Map<String, dynamic> lecture) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LectureDetailScreen(lecture: lecture),
      ),
    );
  }

  String? _getSheikhName(Map<String, dynamic> lecture) {
    // First try sheikhName field (stored with lecture)
    final sheikhName = lecture['sheikhName']?.toString();
    if (sheikhName != null && sheikhName.isNotEmpty && sheikhName != 'null') {
      return sheikhName;
    }
    // Fallback: return null to hide the label (backward compatibility)
    return null;
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'غير محدد';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is DateTime) {
        dateTime = timestamp;
      } else {
        return 'غير محدد';
      }

      return '${dateTime.day}/${dateTime.month}/${dateTime.year} - ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'غير محدد';
    }
  }

  Future<void> _openPdf(Map<String, dynamic> lecture) async {
    final pdfUrl = lecture['pdfUrl']?.toString();
    final pdfType = lecture['pdfType']?.toString();

    if (pdfUrl == null || pdfUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد ملف PDF متاح'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      if (pdfType == 'file') {
        // For local files, use open_filex to avoid FileUriExposedException on Android 7+
        final file = File(pdfUrl);
        if (await file.exists()) {
          final result = await OpenFilex.open(pdfUrl);
          if (result.type != ResultType.done) {
            throw Exception('Cannot open PDF file: ${result.message}');
          }
        } else {
          throw Exception('PDF file not found');
        }
      } else {
        // For URLs, use url_launcher
        final uri = Uri.parse(pdfUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Cannot launch URL');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء فتح ملف PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
