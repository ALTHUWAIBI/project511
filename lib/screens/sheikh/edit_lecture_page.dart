import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_project/provider/pro_login.dart';
import 'package:new_project/provider/lecture_provider.dart';
import 'package:new_project/provider/hierarchy_provider.dart';
import 'package:new_project/widgets/sheikh_guard.dart';
import 'package:new_project/utils/time.dart';
import 'package:new_project/utils/youtube_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';

class EditLecturePage extends StatefulWidget {
  const EditLecturePage({super.key});

  @override
  State<EditLecturePage> createState() => _EditLecturePageState();
}

class _EditLecturePageState extends State<EditLecturePage> {
  List<Map<String, dynamic>> _lectures = [];
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

    if (authProvider.currentUid != null) {
      await lectureProvider.loadSheikhLectures(authProvider.currentUid ?? '');
      setState(() {
        _lectures = lectureProvider.sheikhLectures
            .where(
              (lecture) =>
                  lecture['status'] != 'archived' &&
                  lecture['status'] != 'deleted',
            )
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
      routeName: '/sheikh/edit',
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFE4E5D3),
          appBar: AppBar(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            title: const Text('تعديل المحاضرات'),
            iconTheme: const IconThemeData(color: Colors.white),
            centerTitle: true,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? _buildErrorWidget()
              : _lectures.isEmpty
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
            'لا توجد محاضرات للتعديل',
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
              Icon(Icons.edit, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'اختر المحاضرة للتعديل',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _lectures.length,
            itemBuilder: (context, index) {
              final lecture = _lectures[index];
              return _buildLectureCard(lecture);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLectureCard(Map<String, dynamic> lecture) {
    final title = lecture['title'] ?? 'بدون عنوان';
    final categoryName = lecture['categoryNameAr'] ?? '';
    // Use safe date conversion - handles Timestamp, int (epoch ms), String, DateTime
    final startTime = safeDateFromDynamic(lecture['startTime']);
    final status = lecture['status'] ?? 'draft';
    final description = lecture['description'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToEditForm(lecture),
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
                  Icon(Icons.edit, color: Colors.blue[600], size: 20),
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
                  Icon(Icons.touch_app, size: 16, color: Colors.blue[600]),
                  const SizedBox(width: 4),
                  Text(
                    'اضغط للتعديل',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[600],
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

  void _navigateToEditForm(Map<String, dynamic> lecture) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditLectureForm(lecture: lecture),
      ),
    );
  }
}

class EditLectureForm extends StatefulWidget {
  final Map<String, dynamic> lecture;

  const EditLectureForm({super.key, required this.lecture});

  @override
  State<EditLectureForm> createState() => _EditLectureFormState();
}

class _EditLectureFormState extends State<EditLectureForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _locationUrlController = TextEditingController();
  final _audioUrlController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _pdfUrlController = TextEditingController();

  // PDF attachment state
  File? _selectedPdfFile;
  String? _pdfFileName;

  DateTime? _selectedStartDate;
  TimeOfDay? _selectedStartTime;
  DateTime? _selectedEndDate;
  TimeOfDay? _selectedEndTime;
  bool _hasEndTime = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  /// Safely parse a value that could be a Map, JSON string, or null into a Map
  Map<String, dynamic>? _safeParseMap(dynamic value) {
    if (value == null) {
      return null;
    }

    // If it's already a Map, return it directly
    if (value is Map<String, dynamic>) {
      return value;
    }

    // If it's a Map but not typed, try to cast it
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (e) {
        return null;
      }
    }

    // If it's a String, try to parse it as JSON
    if (value is String) {
      if (value.isEmpty || value == 'null') {
        return null;
      }
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
        return null;
      } catch (e) {
        // JSON parsing failed, return null
        return null;
      }
    }

    // Unknown type, return null
    return null;
  }

  void _initializeForm() {
    _titleController.text = widget.lecture['title'] ?? '';
    _descriptionController.text = widget.lecture['description'] ?? '';

    // Safely parse location - could be Map, JSON string, or null
    final location = _safeParseMap(widget.lecture['location']);
    if (location != null && location.isNotEmpty) {
      _locationController.text = location['label']?.toString() ?? '';
      _locationUrlController.text =
          location['url']?.toString() ??
          location['locationUrl']?.toString() ??
          location['googleMapsUrl']?.toString() ??
          '';
    }

    // Load media URLs - safely parse media (could be Map, JSON string, or null)
    final media = _safeParseMap(widget.lecture['media']);
    if (media != null && media.isNotEmpty) {
      _audioUrlController.text = media['audioUrl']?.toString() ?? '';
      // Check videoUrl in media, or video_path, or construct from videoId
      _videoUrlController.text =
          media['videoUrl']?.toString() ??
          widget.lecture['video_path']?.toString() ??
          (widget.lecture['videoId'] != null
              ? YouTubeUtils.getWatchUrl(widget.lecture['videoId'].toString())
              : '');

      // Load PDF data from media object
      final pdfUrl = media['pdfUrl']?.toString();
      final pdfType = media['pdfType']?.toString();
      if (pdfUrl != null && pdfUrl.isNotEmpty) {
        if (pdfType == 'file') {
          // For local files, set the file path and name
          _selectedPdfFile = File(pdfUrl);
          _pdfFileName =
              media['pdfFileName']?.toString() ?? pdfUrl.split('/').last;
        } else {
          // For URLs, set the URL controller
          _pdfUrlController.text = pdfUrl;
        }
      }
    } else {
      // If no media object, check direct fields
      _videoUrlController.text =
          widget.lecture['video_path']?.toString() ??
          (widget.lecture['videoId'] != null
              ? YouTubeUtils.getWatchUrl(widget.lecture['videoId'].toString())
              : '');

      // Check for PDF in direct lecture fields (from database columns)
      final pdfUrl = widget.lecture['pdfUrl']?.toString();
      final pdfType = widget.lecture['pdfType']?.toString();
      if (pdfUrl != null && pdfUrl.isNotEmpty) {
        if (pdfType == 'file') {
          _selectedPdfFile = File(pdfUrl);
          _pdfFileName =
              widget.lecture['pdfFileName']?.toString() ??
              pdfUrl.split('/').last;
        } else {
          _pdfUrlController.text = pdfUrl;
        }
      }
    }

    // Use safe date conversion - handles Timestamp, int (epoch ms), String, DateTime
    final startDateTime = safeDateFromDynamic(widget.lecture['startTime']);
    if (startDateTime != null) {
      _selectedStartDate = startDateTime;
      _selectedStartTime = TimeOfDay.fromDateTime(startDateTime);
    }

    final endDateTime = safeDateFromDynamic(widget.lecture['endTime']);
    if (endDateTime != null) {
      _selectedEndDate = endDateTime;
      _selectedEndTime = TimeOfDay.fromDateTime(endDateTime);
      _hasEndTime = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _locationUrlController.dispose();
    _audioUrlController.dispose();
    _videoUrlController.dispose();
    _pdfUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheikhGuard(
      routeName: '/sheikh/edit',
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFE4E5D3),
          appBar: AppBar(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            title: const Text('تعديل المحاضرة'),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              Consumer<LectureProvider>(
                builder: (context, lectureProvider, child) {
                  return TextButton(
                    onPressed: lectureProvider.isLoading
                        ? null
                        : _updateLecture,
                    child: lectureProvider.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'حفظ التعديلات',
                            style: TextStyle(color: Colors.white),
                          ),
                  );
                },
              ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lecture Info Card
                  _buildLectureInfoCard(),
                  const SizedBox(height: 24),

                  // Basic Information
                  _buildSectionTitle('المعلومات الأساسية'),
                  const SizedBox(height: 12),
                  _buildTitleField(),
                  const SizedBox(height: 16),
                  _buildDescriptionField(),
                  const SizedBox(height: 24),

                  // Time Information
                  _buildSectionTitle('معلومات الوقت'),
                  const SizedBox(height: 12),
                  _buildStartTimeField(),
                  const SizedBox(height: 16),
                  _buildEndTimeToggle(),
                  if (_hasEndTime) ...[
                    const SizedBox(height: 16),
                    _buildEndTimeField(),
                  ],
                  const SizedBox(height: 24),

                  // Location Information
                  _buildSectionTitle('معلومات الموقع (اختياري)'),
                  const SizedBox(height: 12),
                  _buildLocationField(),
                  const SizedBox(height: 16),
                  _buildLocationUrlField(),
                  const SizedBox(height: 24),

                  // Media Information
                  _buildSectionTitle('الملفات المرفقة (اختياري)'),
                  const SizedBox(height: 12),
                  _buildAudioUrlField(),
                  const SizedBox(height: 16),
                  _buildVideoUrlField(),
                  const SizedBox(height: 16),
                  _buildPdfField(),
                  const SizedBox(height: 32),

                  // Error Message
                  Consumer<LectureProvider>(
                    builder: (context, lectureProvider, child) {
                      if (lectureProvider.errorMessage != null) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red[200] ?? Colors.red,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error,
                                color: Colors.red[600],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  lectureProvider.errorMessage ??
                                      'خطأ غير معروف',
                                  style: TextStyle(color: Colors.red[700]),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLectureInfoCard() {
    final categoryName = widget.lecture['categoryNameAr'] ?? '';
    final status = widget.lecture['status'] ?? 'draft';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.edit, color: Colors.blue.shade700, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تعديل المحاضرة',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  Text(
                    categoryName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.blue.shade700,
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: InputDecoration(
        labelText: 'عنوان المحاضرة *',
        hintText: 'أدخل عنوان المحاضرة',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.title),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'عنوان المحاضرة مطلوب';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'وصف المحاضرة',
        hintText: 'أدخل وصف المحاضرة (اختياري)',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.description),
      ),
    );
  }

  Widget _buildStartTimeField() {
    return InkWell(
      onTap: _selectStartDateTime,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300] ?? Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'وقت البداية *',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    _selectedStartDate != null && _selectedStartTime != null
                        ? '${_formatDate(_selectedStartDate ?? DateTime.now())} - ${_formatTime(_selectedStartTime ?? TimeOfDay.now())}'
                        : 'اختر وقت البداية',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _buildEndTimeToggle() {
    return Row(
      children: [
        Checkbox(
          value: _hasEndTime,
          onChanged: (value) {
            setState(() {
              _hasEndTime = value ?? false;
            });
          },
        ),
        const Text('تحديد وقت انتهاء'),
      ],
    );
  }

  Widget _buildEndTimeField() {
    return InkWell(
      onTap: _selectEndDateTime,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300] ?? Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'وقت الانتهاء',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    _selectedEndDate != null && _selectedEndTime != null
                        ? '${_formatDate(_selectedEndDate ?? DateTime.now())} - ${_formatTime(_selectedEndTime ?? TimeOfDay.now())}'
                        : 'اختر وقت الانتهاء',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationField() {
    return TextFormField(
      controller: _locationController,
      decoration: InputDecoration(
        labelText: 'اسم الموقع',
        hintText: 'أدخل اسم موقع المحاضرة',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.location_on),
      ),
    );
  }

  Widget _buildLocationUrlField() {
    return TextFormField(
      controller: _locationUrlController,
      decoration: InputDecoration(
        labelText: 'رابط الخريطة (Google Maps)',
        hintText: 'أدخل رابط Google Maps أو الإحداثيات',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.map),
        helperText:
            'يمكنك إدخال رابط Google Maps أو الإحداثيات (مثل: 24.7136,46.6753)',
        helperMaxLines: 2,
      ),
      validator: (value) {
        if (value != null &&
            value.isNotEmpty &&
            !_isValidUrl(value) &&
            !_isValidCoordinates(value)) {
          return 'رابط غير صحيح أو إحداثيات غير صحيحة';
        }
        return null;
      },
    );
  }

  bool _isValidCoordinates(String value) {
    // Check if it's in format: lat,lng or lat, lng
    final coordPattern = RegExp(r'^-?\d+\.?\d*,\s*-?\d+\.?\d*$');
    return coordPattern.hasMatch(value.trim());
  }

  Widget _buildAudioUrlField() {
    return TextFormField(
      controller: _audioUrlController,
      decoration: InputDecoration(
        labelText: 'رابط الصوت',
        hintText: 'أدخل رابط الملف الصوتي',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.audiotrack),
      ),
      validator: (value) {
        if (value != null && value.isNotEmpty && !_isValidUrl(value)) {
          return 'رابط غير صحيح';
        }
        return null;
      },
    );
  }

  Widget _buildVideoUrlField() {
    return TextFormField(
      controller: _videoUrlController,
      decoration: InputDecoration(
        labelText: 'رابط الفيديو',
        hintText: 'أدخل رابط الفيديو',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.videocam),
      ),
      validator: (value) {
        if (value != null && value.isNotEmpty && !_isValidUrl(value)) {
          return 'رابط غير صحيح';
        }
        return null;
      },
    );
  }

  Widget _buildPdfField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _pdfUrlController,
          decoration: InputDecoration(
            labelText: 'رابط PDF (اختياري)',
            hintText: 'أدخل رابط ملف PDF',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.picture_as_pdf),
            suffixIcon: _pdfUrlController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _pdfUrlController.clear();
                      });
                    },
                  )
                : null,
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty && !_isValidUrl(value)) {
              return 'رابط غير صحيح';
            }
            return null;
          },
          onChanged: (value) {
            setState(() {
              // Clear file selection if URL is entered
              if (value.isNotEmpty) {
                _selectedPdfFile = null;
                _pdfFileName = null;
              }
            });
          },
        ),
        const SizedBox(height: 12),
        // File upload option
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickPdfFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('رفع ملف PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_selectedPdfFile != null || _pdfFileName != null) ...[
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.picture_as_pdf,
                        color: Colors.green[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _pdfFileName ??
                              _selectedPdfFile?.path.split('/').last ??
                              'ملف PDF',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: Colors.red,
                        onPressed: () {
                          setState(() {
                            _selectedPdfFile = null;
                            _pdfFileName = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        if (_selectedPdfFile != null || _pdfFileName != null) ...[
          const SizedBox(height: 8),
          Text(
            'ملاحظة: سيتم استخدام الملف المرفوع بدلاً من الرابط',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedPdfFile = File(result.files.single.path ?? '');
          _pdfFileName = result.files.single.name;
          // Clear URL if file is selected
          _pdfUrlController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في اختيار الملف: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectStartDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _selectedStartTime ?? TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _selectedStartDate = date;
          _selectedStartTime = time;
        });
      }
    }
  }

  Future<void> _selectEndDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate ?? (_selectedStartDate ?? DateTime.now()),
      firstDate: _selectedStartDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _selectedEndTime ?? TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _selectedEndDate = date;
          _selectedEndTime = time;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  bool _isValidUrl(String url) {
    return Uri.tryParse(url)?.hasAbsolutePath == true;
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

  Future<void> _updateLecture() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    if (_selectedStartDate == null || _selectedStartTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد وقت البداية'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final lectureProvider = Provider.of<LectureProvider>(
      context,
      listen: false,
    );

    // Create DateTime with full date-time precision (year, month, day, hour, minute)
    // Set seconds and milliseconds to 0 for exact matching
    final startDateTime = DateTime(
      _selectedStartDate?.year ?? DateTime.now().year,
      _selectedStartDate?.month ?? DateTime.now().month,
      _selectedStartDate?.day ?? DateTime.now().day,
      _selectedStartTime?.hour ?? TimeOfDay.now().hour,
      _selectedStartTime?.minute ?? TimeOfDay.now().minute,
      0, // seconds = 0
      0, // milliseconds = 0
    );

    DateTime? endDateTime;
    if (_hasEndTime && _selectedEndDate != null && _selectedEndTime != null) {
      // Create DateTime with full date-time precision (year, month, day, hour, minute)
      // Set seconds and milliseconds to 0 for exact matching
      endDateTime = DateTime(
        _selectedEndDate?.year ?? DateTime.now().year,
        _selectedEndDate?.month ?? DateTime.now().month,
        _selectedEndDate?.day ?? DateTime.now().day,
        _selectedEndTime?.hour ?? TimeOfDay.now().hour,
        _selectedEndTime?.minute ?? TimeOfDay.now().minute,
        0, // seconds = 0
        0, // milliseconds = 0
      );
    }

    // Prepare media data with videoId extraction and PDF support
    // Always create media map to ensure we can clear fields if needed
    Map<String, dynamic> media = {};
    if (_audioUrlController.text.isNotEmpty) {
      media['audioUrl'] = _audioUrlController.text.trim();
    }
    if (_videoUrlController.text.isNotEmpty) {
      final videoUrl = _videoUrlController.text.trim();
      media['videoUrl'] = videoUrl;
      // Extract videoId from URL
      final videoId = YouTubeUtils.extractVideoId(videoUrl);
      if (videoId != null) {
        media['videoId'] = videoId;
      }
    }
    // Add PDF attachment (prefer file over URL)
    if (_selectedPdfFile != null) {
      // Store file path for local storage
      media['pdfUrl'] = _selectedPdfFile!.path;
      media['pdfFileName'] = _pdfFileName;
      media['pdfType'] = 'file';
    } else if (_pdfUrlController.text.isNotEmpty) {
      final pdfUrl = _pdfUrlController.text.trim();
      if (!_isValidUrl(pdfUrl)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('صيغة رابط PDF غير صحيحة'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      media['pdfUrl'] = pdfUrl;
      media['pdfType'] = 'url';
    }

    // Prepare location data - always create map to ensure we can clear if needed
    Map<String, dynamic> location = {};
    if (_locationController.text.isNotEmpty) {
      location['label'] = _locationController.text.trim();
    }
    if (_locationUrlController.text.isNotEmpty) {
      location['url'] = _locationUrlController.text.trim();
      // Also store as locationUrl for backward compatibility
      location['locationUrl'] = _locationUrlController.text.trim();
    }

    // Get categoryId from lecture (required for conflict check)
    final categoryId = widget.lecture['categoryId']?.toString() ?? '';
    if (categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطأ: لا يمكن تحديد الفئة للمحاضرة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final success = await lectureProvider.updateSheikhLecture(
      lectureId: widget.lecture['id'],
      sheikhId: authProvider.currentUid ?? '',
      categoryId: categoryId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      startTime: startDateTime,
      endTime: endDateTime,
      location: location,
      media: media,
    );

    if (success) {
      // Refresh home hierarchy after successful update
      final hierarchyProvider = Provider.of<HierarchyProvider>(
        context,
        listen: false,
      );
      hierarchyProvider.clearHomeHierarchyCache();
      hierarchyProvider.loadHomeHierarchy(forceRefresh: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث المحاضرة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        // Pop with refresh=true to trigger reload in parent screen
        Navigator.pop(context, true);
      }
    } else {
      // Error is already set in LectureProvider, and will be shown in the UI
      // via the Consumer widget that displays errorMessage
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lectureProvider.errorMessage ?? 'حدث خطأ أثناء تحديث المحاضرة',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
