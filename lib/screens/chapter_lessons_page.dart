import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_project/provider/pro_login.dart';
import 'package:new_project/services/subcategory_service.dart';
import 'package:new_project/utils/auth_guard.dart';
import 'package:new_project/utils/youtube_utils.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:new_project/offline/firestore_shims.dart';
import 'package:new_project/repository/local_repository.dart';
import '../widgets/app_drawer.dart';

class ChapterLessonsPage extends StatefulWidget {
  final String subcategoryId;
  final String subcategoryName;
  final String sheikhUid;
  final String sheikhName;
  final String chapterId;
  final String chapterTitle;
  final String section;
  final bool isDarkMode;
  final Function(bool)? toggleTheme;

  const ChapterLessonsPage({
    super.key,
    required this.subcategoryId,
    required this.subcategoryName,
    required this.sheikhUid,
    required this.sheikhName,
    required this.chapterId,
    required this.chapterTitle,
    required this.section,
    required this.isDarkMode,
    this.toggleTheme,
  });

  @override
  State<ChapterLessonsPage> createState() => _ChapterLessonsPageState();
}

class _ChapterLessonsPageState extends State<ChapterLessonsPage> {
  final SubcategoryService _service = SubcategoryService();
  final LocalRepository _repository = LocalRepository();

  @override
  void initState() {
    super.initState();
    // No need to call _loadLessons() as we'll use StreamBuilder
  }

  // Get real-time stream of Sheikh lectures (polling for offline mode)
  Stream<List<Map<String, dynamic>>> _getSheikhLecturesStream() {
    // For offline mode: Poll every 2 seconds
    return Stream.periodic(const Duration(seconds: 2), (_) async {
      final lectures = await _repository.getLecturesBySheikh(widget.sheikhUid);
      // Filter published only and sort by createdAt desc
      return lectures
          .where(
            (lecture) =>
                (lecture['isPublished'] as int? ?? 0) == 1 &&
                lecture['status'] != 'archived' &&
                lecture['status'] != 'deleted',
          )
          .toList()
        ..sort((a, b) {
          final aTime = a['createdAt'] as int? ?? 0;
          final bTime = b['createdAt'] as int? ?? 0;
          return bTime.compareTo(aTime);
        });
    }).asyncMap((future) => future);
  }

  Future<void> _addLesson() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Check authentication
    final authenticated = await AuthGuard.requireAuth(
      context,
      onLoginSuccess: () => _addLesson(),
    );
    if (!authenticated) return;

    // Check if current user is the assigned sheikh
    if (authProvider.currentUid != widget.sheikhUid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ليس لديك صلاحية لإضافة محتوى في هذا الباب.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Show add lesson dialog
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final mediaUrlController = TextEditingController();
    final durationController = TextEditingController();
    final orderController = TextEditingController(text: '1');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إضافة درس جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الدرس',
                    border: OutlineInputBorder(),
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'الوصف',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mediaUrlController,
                  decoration: const InputDecoration(
                    labelText: 'رابط الفيديو (يوتيوب)',
                    hintText: 'أدخل رابط فيديو يوتيوب',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.videocam),
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durationController,
                  decoration: const InputDecoration(
                    labelText: 'المدة بالدقائق (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: orderController,
                  decoration: const InputDecoration(
                    labelText: 'الترتيب',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) return;

    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال عنوان الدرس'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Prepare lesson data
      Map<String, dynamic> lessonData = {
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'duration': durationController.text.trim().isEmpty
            ? null
            : int.tryParse(durationController.text),
        'order': int.tryParse(orderController.text) ?? 0,
      };

      // Handle media URL and extract videoId if it's a YouTube URL
      final mediaUrl = mediaUrlController.text.trim();
      if (mediaUrl.isNotEmpty) {
        lessonData['mediaUrl'] = mediaUrl;

        // Extract videoId for YouTube URLs
        final videoId = YouTubeUtils.extractVideoId(mediaUrl);
        if (videoId != null) {
          lessonData['videoId'] = videoId;
        }
      }

      await _service.createLesson(
        widget.subcategoryId,
        widget.sheikhUid,
        widget.chapterId,
        authProvider.currentUid ?? '',
        lessonData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة الدرس بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        // StreamBuilder will automatically refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildVideoPlayer(Map<String, dynamic> lesson) {
    final mediaUrl = lesson['mediaUrl'] as String?;
    if (mediaUrl == null || mediaUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    // Try to get videoId from lesson data first, then extract from URL
    String? videoId = lesson['videoId'] as String?;
    if (videoId == null || videoId.isEmpty) {
      videoId = YouTubeUtils.extractVideoId(mediaUrl);
    }

    if (videoId == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[200] ?? Colors.orange),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[600], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'رابط الفيديو غير مدعوم أو غير صحيح',
                style: TextStyle(color: Colors.orange[700]),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الفيديو:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300] ?? Colors.grey),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: YoutubePlayer(
              controller: YoutubePlayerController(
                initialVideoId: videoId,
                flags: const YoutubePlayerFlags(
                  autoPlay: false,
                  mute: false,
                  isLive: false,
                  forceHD: true,
                  enableCaption: true,
                ),
              ),
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.green,
              onReady: () {
                // Video is ready to play
              },
              onEnded: (data) {
                // Video ended
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final canEdit =
        authProvider.isAuthenticated &&
        authProvider.currentUid == widget.sheikhUid;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: widget.isDarkMode
            ? const Color(0xFF121212)
            : const Color(0xFFE4E5D3),
        appBar: AppBar(
          title: Text(widget.chapterTitle),
          centerTitle: true,
          backgroundColor: Colors.green,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
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
          stream: _getSheikhLecturesStream(),
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
                    if (canEdit) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _addLesson,
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة درس'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
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
                    'محاضرات ${widget.chapterTitle}',
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
                        return _buildLectureCard(lecture, canEdit);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        floatingActionButton: canEdit
            ? FloatingActionButton.extended(
                onPressed: _addLesson,
                icon: const Icon(Icons.add),
                label: const Text('إضافة درس'),
                backgroundColor: Colors.green,
              )
            : null,
      ),
    );
  }

  // Build lecture card for Sheikh lectures
  Widget _buildLectureCard(Map<String, dynamic> lecture, bool canEdit) {
    final mediaUrl = lecture['media']?['videoUrl'] ?? '';
    final hasVideo =
        mediaUrl.isNotEmpty && YouTubeUtils.extractVideoId(mediaUrl) != null;

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

  // Show lecture details with video player
  void _showLectureDetails(Map<String, dynamic> lecture) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          lecture['title'] ?? 'بدون عنوان',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (lecture['description'] != null &&
                            lecture['description'].toString().isNotEmpty) ...[
                          const Text(
                            'الوصف:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lecture['description']?.toString() ?? '',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (lecture['startTime'] != null) ...[
                          const Text(
                            'وقت البداية:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatDateTime(lecture['startTime']),
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (lecture['endTime'] != null) ...[
                          const Text(
                            'وقت النهاية:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatDateTime(lecture['endTime']),
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (lecture['location'] != null) ...[
                          const Text(
                            'الموقع:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (lecture['location']
                                        as Map<String, dynamic>?)?['label']
                                    ?.toString() ??
                                'غير محدد',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                        ],
                        // Video player
                        if (lecture['media']?['videoUrl'] != null) ...[
                          const Text(
                            'الفيديو:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildVideoPlayer(lecture),
                        ],
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

  // Format DateTime for display
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
}
