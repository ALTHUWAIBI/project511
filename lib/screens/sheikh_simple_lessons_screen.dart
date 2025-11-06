import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_project/offline/firestore_shims.dart';
import '../provider/sheikh_provider.dart';
import '../provider/pro_login.dart';
import '../provider/chapter_provider.dart';
import '../provider/lecture_provider.dart';

class SheikhSimpleLessonsScreen extends StatefulWidget {
  const SheikhSimpleLessonsScreen({super.key});

  @override
  State<SheikhSimpleLessonsScreen> createState() =>
      _SheikhSimpleLessonsScreenState();
}

class _SheikhSimpleLessonsScreenState extends State<SheikhSimpleLessonsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedChapterId;
  String _selectedStatus = 'الكل';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final sheikhProvider = Provider.of<SheikhProvider>(context, listen: false);
    final chapterProvider = Provider.of<ChapterProvider>(
      context,
      listen: false,
    );
    final lectureProvider = Provider.of<LectureProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (sheikhProvider.currentSheikhCategoryId != null &&
        authProvider.currentUser != null) {
      await Future.wait([
        chapterProvider.loadChapters(
          sheikhProvider.currentSheikhCategoryId ?? '',
          authProvider.currentUid ?? '',
        ),
        lectureProvider.loadAllLectures(),
      ]);
    }
  }

  List<Map<String, dynamic>> _getFilteredLessons(
    List<Map<String, dynamic>> lessons,
  ) {
    List<Map<String, dynamic>> filtered = lessons;

    if (_selectedChapterId != null && _selectedChapterId != 'الكل') {
      filtered = filtered
          .where((lesson) => lesson['chapterId'] == _selectedChapterId)
          .toList();
    }

    if (_selectedStatus != 'الكل') {
      final statusFilter = _selectedStatus == 'منشور' ? 'published' : 'draft';
      filtered = filtered
          .where((lesson) => lesson['status'] == statusFilter)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (lesson) =>
                (lesson['title'] as String?)?.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ??
                false,
          )
          .toList();
    }

    return filtered;
  }

  void _showAddLessonBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              child: _AddLessonForm(
                onSave: () {
                  Navigator.pop(context);
                  _loadData();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditLessonBottomSheet(Map<String, dynamic> lesson) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              child: _AddLessonForm(
                lesson: lesson,
                onSave: () {
                  Navigator.pop(context);
                  _loadData();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> lesson) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: const Text('سيتم حذف هذا الدرس. هل أنت متأكد؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteLesson(lesson);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteLesson(Map<String, dynamic> lesson) async {
    try {
      final lectureProvider = Provider.of<LectureProvider>(
        context,
        listen: false,
      );
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final sheikhProvider = Provider.of<SheikhProvider>(
        context,
        listen: false,
      );

      if (authProvider.currentUser != null &&
          sheikhProvider.currentSheikhCategoryId != null) {
        await lectureProvider.deleteLecture(lesson['id'], 'general');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تم الحذف'),
              action: SnackBarAction(
                label: 'تراجع',
                onPressed: () {
                  // TODO: Implement undo logic
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
      }
    }
  }

  String _getChapterTitle(
    String? chapterId,
    List<Map<String, dynamic>> chapters,
  ) {
    if (chapterId == null) return 'غير محدد';
    final chapter = chapters.firstWhere(
      (c) => c['id'] == chapterId,
      orElse: () => {'title': 'غير محدد'},
    );
    return chapter['title'] ?? 'غير محدد';
  }

  String _formatRelativeTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return 'منذ ${difference.inDays} يوم';
    } else if (difference.inHours > 0) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inMinutes > 0) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<
      SheikhProvider,
      AuthProvider,
      ChapterProvider,
      LectureProvider
    >(
      builder:
          (
            context,
            sheikhProvider,
            authProvider,
            chapterProvider,
            lectureProvider,
            child,
          ) {
            final filteredLessons = _getFilteredLessons(
              lectureProvider.allLectures,
            );

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                appBar: AppBar(
                  title: const Text('الدروس'),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                body: SafeArea(
                  child: Column(
                    children: [
                      // Filters row
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            // Chapter dropdown
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'الفصل',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                value: _selectedChapterId ?? 'الكل',
                                items: [
                                  const DropdownMenuItem(
                                    value: 'الكل',
                                    child: Text('الكل'),
                                  ),
                                  ...chapterProvider.chapters.map(
                                    (chapter) => DropdownMenuItem(
                                      value: chapter['id'],
                                      child: Text(chapter['title']),
                                    ),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _selectedChapterId = value),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Status chips
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                children: ['الكل', 'منشور', 'مسودة'].map((
                                  status,
                                ) {
                                  final isSelected = _selectedStatus == status;
                                  return FilterChip(
                                    label: Text(status),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() => _selectedStatus = status);
                                    },
                                    backgroundColor: isSelected
                                        ? Colors.green.shade100
                                        : null,
                                    selectedColor: Colors.green.shade200,
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Search field
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'البحث في الدروس...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Lessons list
                      Expanded(
                        child: filteredLessons.isEmpty
                            ? const Center(
                                child: Text(
                                  'لا توجد دروس',
                                  style: TextStyle(fontSize: 18),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                itemCount: filteredLessons.length,
                                itemBuilder: (context, index) {
                                  final lesson = filteredLessons[index];
                                  final updatedAt =
                                      lesson['updatedAt'] as Timestamp?;
                                  return Dismissible(
                                    key: Key(lesson['id']),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      color: Colors.red,
                                      child: const Padding(
                                        padding: EdgeInsets.only(right: 20),
                                        child: Icon(
                                          Icons.delete,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    confirmDismiss: (direction) async {
                                      _showDeleteConfirmation(lesson);
                                      return false; // Don't auto-dismiss
                                    },
                                    child: Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        title: Text(
                                          lesson['title'] ?? 'بدون عنوان',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          _getChapterTitle(
                                            lesson['chapterId'],
                                            chapterProvider.chapters,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Chip(
                                              label: Text(
                                                lesson['status'] == 'published'
                                                    ? 'منشور'
                                                    : 'مسودة',
                                                style: TextStyle(
                                                  color:
                                                      lesson['status'] ==
                                                          'published'
                                                      ? Colors.white
                                                      : Colors.black87,
                                                  fontSize: 10,
                                                ),
                                              ),
                                              backgroundColor:
                                                  lesson['status'] ==
                                                      'published'
                                                  ? Colors.green
                                                  : Colors.grey.shade300,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _formatRelativeTime(updatedAt),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                        onTap: () =>
                                            _showEditLessonBottomSheet(lesson),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: _showAddLessonBottomSheet,
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            );
          },
    );
  }
}

class _AddLessonForm extends StatefulWidget {
  final Map<String, dynamic>? lesson;
  final VoidCallback onSave;

  const _AddLessonForm({this.lesson, required this.onSave});

  @override
  State<_AddLessonForm> createState() => _AddLessonFormState();
}

class _AddLessonFormState extends State<_AddLessonForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _abstractController = TextEditingController();
  String? _selectedChapterId;
  String _status = 'draft';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.lesson != null) {
      _titleController.text = widget.lesson?['title'] ?? '';
      _abstractController.text = widget.lesson?['abstract'] ?? '';
      _selectedChapterId = widget.lesson?['chapterId'];
      _status = widget.lesson?['status'] ?? 'draft';
    }
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    final sheikhProvider = Provider.of<SheikhProvider>(context, listen: false);
    final chapterProvider = Provider.of<ChapterProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (sheikhProvider.currentSheikhCategoryId != null &&
        authProvider.currentUser != null) {
      await chapterProvider.loadChapters(
        sheikhProvider.currentSheikhCategoryId ?? '',
        authProvider.currentUid ?? '',
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _abstractController.dispose();
    super.dispose();
  }

  Future<void> _saveLesson() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isLoading = true);

    try {
      final lectureProvider = Provider.of<LectureProvider>(
        context,
        listen: false,
      );
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final sheikhProvider = Provider.of<SheikhProvider>(
        context,
        listen: false,
      );

      if (authProvider.currentUser != null &&
          sheikhProvider.currentSheikhCategoryId != null) {
        final lessonData = {
          'title': _titleController.text,
          'abstract': _abstractController.text,
          'chapterId': _selectedChapterId,
          'status': _status,
        };

        if (widget.lesson == null) {
          final categoryId = sheikhProvider.currentSheikhCategoryId;
          await lectureProvider.addLecture(
            title: lessonData['title']!,
            description: lessonData['abstract'] ?? '',
            section: 'general',
            categoryId: categoryId,
            categoryName: categoryId,
            subcategoryId: _selectedChapterId,
            subcategoryName: _selectedChapterId,
          );
        } else {
          await lectureProvider.updateLecture(
            id: widget.lesson?['id'] ?? '',
            title: lessonData['title']!,
            description: lessonData['abstract'] ?? '',
            section: 'general',
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم الحفظ')));
          widget.onSave();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في الحفظ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChapterProvider>(
      builder: (context, chapterProvider, child) {
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.lesson == null ? 'إضافة درس جديد' : 'تعديل الدرس',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedChapterId,
                decoration: const InputDecoration(
                  labelText: 'الفصل/الباب *',
                  border: OutlineInputBorder(),
                ),
                items: chapterProvider.chapters.map((chapter) {
                  return DropdownMenuItem<String>(
                    value: chapter['id'],
                    child: Text(chapter['title']),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedChapterId = value),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء اختيار فصل/باب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'عنوان الدرس *',
                  border: OutlineInputBorder(),
                ),
                maxLength: 120,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال عنوان الدرس';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _abstractController,
                decoration: const InputDecoration(
                  labelText: 'نبذة (اختياري)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 500,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'الحالة',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'draft', child: Text('مسودة')),
                  DropdownMenuItem(value: 'published', child: Text('منشور')),
                ],
                onChanged: (value) =>
                    setState(() => _status = value ?? 'draft'),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveLesson,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(widget.lesson == null ? 'حفظ' : 'تحديث'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
