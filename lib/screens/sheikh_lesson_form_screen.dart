import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_project/offline/firestore_shims.dart';
import 'package:new_project/database/firebase_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../provider/sheikh_provider.dart';
import '../provider/pro_login.dart';
import '../provider/chapter_provider.dart';

class SheikhLessonFormScreen extends StatefulWidget {
  final String? lessonId;
  final Map<String, dynamic>? lessonData;

  const SheikhLessonFormScreen({super.key, this.lessonId, this.lessonData});

  @override
  State<SheikhLessonFormScreen> createState() => _SheikhLessonFormScreenState();
}

class _SheikhLessonFormScreenState extends State<SheikhLessonFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _abstractController = TextEditingController();
  final _tagsController = TextEditingController();

  String? _selectedChapterId;
  String _status = 'draft';
  DateTime? _scheduledAt;
  DateTime? _recordedAt;
  DateTime? _publishAt;

  File? _selectedFile;
  String? _mediaUrl;

  bool _isUploading = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _chapters = [];

  @override
  void initState() {
    super.initState();
    _loadChapters();
    if (widget.lessonData != null) {
      _loadLessonData();
    }
  }

  void _loadLessonData() {
    final data = widget.lessonData ?? {};
    _titleController.text = data['title'] ?? '';
    _abstractController.text = data['abstract'] ?? '';
    _tagsController.text = (data['tags'] as List?)?.join(', ') ?? '';
    _selectedChapterId = data['chapterId'];
    _status = data['status'] ?? 'draft';
    _mediaUrl = data['media']?['url'];

    if (data['dates'] != null) {
      final dates = data['dates'] as Map<String, dynamic>;
      _scheduledAt = dates['scheduledAt']?.toDate();
      _recordedAt = dates['recordedAt']?.toDate();
      _publishAt = dates['publishAt']?.toDate();
    }
  }

  Future<void> _loadChapters() async {
    final sheikhProvider = Provider.of<SheikhProvider>(context, listen: false);
    final chapterProvider = Provider.of<ChapterProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final categoryId = sheikhProvider.currentSheikhCategoryId;
    final currentUid = authProvider.currentUser?['uid'];

    if (categoryId != null && currentUid != null) {
      await chapterProvider.loadChapters(categoryId, currentUid);
      setState(() {
        _chapters = chapterProvider.chapters;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _abstractController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path ?? '');
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في اختيار الملف: $e')));
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) return;

    try {
      setState(() {
        _isUploading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUid = authProvider.currentUser?['uid'];

      if (currentUid == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // For offline mode: Use local file path
      // TODO: Implement local file storage if needed
      final downloadUrl = _selectedFile?.path; // Use local file path

      setState(() {
        _mediaUrl = downloadUrl;
        _isUploading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم رفع الملف بنجاح')));
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في رفع الملف: $e')));
    }
  }

  Future<void> _saveLesson() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final sheikhProvider = Provider.of<SheikhProvider>(
        context,
        listen: false,
      );
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final categoryId = sheikhProvider.currentSheikhCategoryId;
      final currentUid = authProvider.currentUser?['uid'];

      if (categoryId == null || currentUid == null) {
        throw Exception('بيانات الشيخ غير صحيحة');
      }

      final now = DateTime.now();

      // For offline mode: Use LocalRepository via FirebaseService
      final firebaseService = FirebaseService();

      if (widget.lessonId != null) {
        // Update existing lecture
        await firebaseService.updateLecture(
          id: widget.lessonId!,
          title: _titleController.text.trim(),
          description: _abstractController.text.trim(),
          videoPath: _mediaUrl,
          section: 'unknown', // TODO: Get from category
          subcategoryId: _selectedChapterId,
        );
      } else {
        // Create new lecture - use addSheikhLecture if sheikh, otherwise addLecture
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final currentUid = authProvider.currentUid;

        if (currentUid != null && authProvider.isSheikh) {
          final sheikhProvider = Provider.of<SheikhProvider>(
            context,
            listen: false,
          );
          final categoryId = sheikhProvider.currentSheikhCategoryId ?? '';

          await firebaseService.addSheikhLecture(
            sheikhId: currentUid,
            sheikhName: authProvider.currentUser?['name'] ?? 'شيخ',
            section: 'unknown',
            categoryId: categoryId,
            categoryName: categoryId,
            subcategoryId: _selectedChapterId,
            subcategoryName: _selectedChapterId,
            title: _titleController.text.trim(),
            description: _abstractController.text.trim(),
            startTime: Timestamp.fromDate(now),
            endTime: _scheduledAt != null
                ? Timestamp.fromDate(_scheduledAt!)
                : null,
            media: _mediaUrl != null ? {'videoUrl': _mediaUrl} : null,
          );
        } else {
          final sheikhProvider = Provider.of<SheikhProvider>(
            context,
            listen: false,
          );
          final categoryId = sheikhProvider.currentSheikhCategoryId;
          await firebaseService.addLecture(
            title: _titleController.text.trim(),
            description: _abstractController.text.trim(),
            videoPath: _mediaUrl,
            section: 'unknown',
            categoryId: categoryId,
            categoryName: categoryId,
            subcategoryId: _selectedChapterId,
            subcategoryName: _selectedChapterId,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ الدرس')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في حفظ الدرس: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lessonId != null ? 'تحرير الدرس' : 'إضافة درس جديد'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveLesson,
            child: Text(
              'حفظ',
              style: TextStyle(
                color: _isLoading ? Colors.grey : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chapter Field
                DropdownButtonFormField<String>(
                  value: _selectedChapterId,
                  decoration: const InputDecoration(
                    labelText: 'الفصل/الباب *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.folder),
                  ),
                  items: _chapters.map<DropdownMenuItem<String>>((chapter) {
                    return DropdownMenuItem<String>(
                      value: chapter['id'],
                      child: Text(chapter['title']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedChapterId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الفصل مطلوب';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Title Field
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الدرس *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  maxLength: 120,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'عنوان الدرس مطلوب';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Abstract Field
                TextFormField(
                  controller: _abstractController,
                  decoration: const InputDecoration(
                    labelText: 'نبذة',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                  maxLength: 500,
                ),
                const SizedBox(height: 16),

                // Tags Field
                TextFormField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'وسوم (مفصولة بفواصل)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag),
                    hintText: 'فقه، حديث، تفسير',
                  ),
                ),
                const SizedBox(height: 16),

                // Status Field
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'الحالة',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.visibility),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('مسودة')),
                    DropdownMenuItem(value: 'published', child: Text('منشور')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _status = value ?? 'draft';
                      if (value == 'published' && _publishAt == null) {
                        _publishAt = DateTime.now();
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Media Upload Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'رفع مقطع صوتي/فيديو',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_selectedFile != null && !_isUploading) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.attach_file,
                                  color: Colors.green[700],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedFile?.path.split('/').last ??
                                        'unknown',
                                    style: TextStyle(color: Colors.green[700]),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _uploadFile,
                                  icon: const Icon(Icons.upload),
                                  color: Colors.green,
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedFile = null;
                                    });
                                  },
                                  icon: const Icon(Icons.close),
                                  color: Colors.red,
                                ),
                              ],
                            ),
                          ),
                        ] else if (_isUploading) ...[
                          const LinearProgressIndicator(),
                          const SizedBox(height: 8),
                          const Text('جاري الرفع...'),
                        ] else if (_mediaUrl != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.blue[700],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'تم رفع الملف بنجاح',
                                    style: TextStyle(color: Colors.blue[700]),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _mediaUrl = null;
                                      _selectedFile = null;
                                    });
                                  },
                                  icon: const Icon(Icons.close),
                                  color: Colors.red,
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          ElevatedButton.icon(
                            onPressed: _pickFile,
                            icon: const Icon(Icons.attach_file),
                            label: const Text('اختيار ملف'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Date Fields
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'التواريخ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(Icons.schedule),
                          title: const Text('تاريخ الجدولة'),
                          subtitle: Text(
                            _scheduledAt != null
                                ? '${_scheduledAt?.day ?? 0}/${_scheduledAt?.month ?? 0}/${_scheduledAt?.year ?? 0}'
                                : 'لم يتم تحديده',
                          ),
                          trailing: IconButton(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _scheduledAt ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (date != null) {
                                setState(() {
                                  _scheduledAt = date;
                                });
                              }
                            },
                            icon: const Icon(Icons.calendar_today),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.video_call),
                          title: const Text('تاريخ التسجيل'),
                          subtitle: Text(
                            _recordedAt != null
                                ? '${_recordedAt?.day ?? 0}/${_recordedAt?.month ?? 0}/${_recordedAt?.year ?? 0}'
                                : 'لم يتم تحديده',
                          ),
                          trailing: IconButton(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _recordedAt ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() {
                                  _recordedAt = date;
                                });
                              }
                            },
                            icon: const Icon(Icons.calendar_today),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.publish),
                          title: const Text('تاريخ النشر'),
                          subtitle: Text(
                            _publishAt != null
                                ? '${_publishAt?.day ?? 0}/${_publishAt?.month ?? 0}/${_publishAt?.year ?? 0}'
                                : 'لم يتم تحديده',
                          ),
                          trailing: IconButton(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _publishAt ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (date != null) {
                                setState(() {
                                  _publishAt = date;
                                });
                              }
                            },
                            icon: const Icon(Icons.calendar_today),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveLesson,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            widget.lessonId != null
                                ? 'تحديث الدرس'
                                : 'إضافة الدرس',
                            style: const TextStyle(fontSize: 16),
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
}
