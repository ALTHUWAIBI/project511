import 'package:flutter/material.dart';
import 'package:new_project/repository/local_repository.dart';
import 'dart:developer' as developer;

class LectureProvider extends ChangeNotifier {
  final LocalRepository _repository = LocalRepository();

  // Limit for "Recently Added" section
  static const int kRecentLecturesLimit = 2;

  List<Map<String, dynamic>> _allLectures = [];
  List<Map<String, dynamic>> _fiqhLectures = [];
  List<Map<String, dynamic>> _hadithLectures = [];
  List<Map<String, dynamic>> _tafsirLectures = [];
  List<Map<String, dynamic>> _seerahLectures = [];

  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get allLectures => _allLectures;
  List<Map<String, dynamic>> get fiqhLectures => _fiqhLectures;
  List<Map<String, dynamic>> get hadithLectures => _hadithLectures;
  List<Map<String, dynamic>> get tafsirLectures => _tafsirLectures;
  List<Map<String, dynamic>> get seerahLectures => _seerahLectures;

  /// Extract timestamp from lecture (prefer createdAt, then updatedAt, then startTime)
  int? _getLectureTimestamp(Map<String, dynamic> lecture) {
    // Try createdAt first
    if (lecture['createdAt'] != null) {
      if (lecture['createdAt'] is int) {
        return lecture['createdAt'] as int;
      }
      if (lecture['createdAt'] is String) {
        return int.tryParse(lecture['createdAt'].toString());
      }
    }

    // Fallback to updatedAt
    if (lecture['updatedAt'] != null) {
      if (lecture['updatedAt'] is int) {
        return lecture['updatedAt'] as int;
      }
      if (lecture['updatedAt'] is String) {
        return int.tryParse(lecture['updatedAt'].toString());
      }
    }

    // Fallback to startTime
    if (lecture['startTime'] != null) {
      if (lecture['startTime'] is int) {
        return lecture['startTime'] as int;
      }
      if (lecture['startTime'] is String) {
        return int.tryParse(lecture['startTime'].toString());
      }
    }

    return null;
  }

  // Get recent lectures (limited to kRecentLecturesLimit, sorted by createdAt/updatedAt/startTime)
  List<Map<String, dynamic>> get recentLectures {
    if (_allLectures.isEmpty) {
      return [];
    }

    // Sort lectures by timestamp (prefer createdAt, then updatedAt, then startTime)
    final sortedLectures = List<Map<String, dynamic>>.from(_allLectures);
    sortedLectures.sort((a, b) {
      final timestampA = _getLectureTimestamp(a);
      final timestampB = _getLectureTimestamp(b);

      // Sort descending (newest first)
      // If timestamp is null, put it at the end
      if (timestampA == null && timestampB == null) return 0;
      if (timestampA == null) return 1; // a goes to end
      if (timestampB == null) return -1; // b goes to end
      return timestampB.compareTo(timestampA); // Descending order
    });

    // Return only the most recent N lectures
    return sortedLectures.take(kRecentLecturesLimit).toList();
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set error message
  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Load all lectures
  Future<void> loadAllLectures() async {
    _setLoading(true);
    _setError(null);

    try {
      _allLectures = await _repository.getAllLectures();
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في تحميل المحاضرات: $e');
    }
  }

  // Load lectures by section (accepts both canonical keys and Arabic names)
  Future<void> loadLecturesBySection(String section) async {
    _setLoading(true);
    _setError(null);

    try {
      final lectures = await _repository.getLecturesBySection(section);

      // Normalize section to canonical key for assignment
      final normalizedSection = _normalizeSectionKey(section);
      switch (normalizedSection) {
        case 'fiqh':
          _fiqhLectures = lectures;
          break;
        case 'hadith':
          _hadithLectures = lectures;
          break;
        case 'tafsir':
          _tafsirLectures = lectures;
          break;
        case 'seerah':
          _seerahLectures = lectures;
          break;
      }

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في تحميل محاضرات $section: $e');
    }
  }

  // Normalize section key helper
  String _normalizeSectionKey(String section) {
    switch (section.trim()) {
      case 'الفقه':
        return 'fiqh';
      case 'الحديث':
        return 'hadith';
      case 'السيرة':
        return 'seerah';
      case 'التفسير':
        return 'tafsir';
      case 'fiqh':
      case 'hadith':
      case 'seerah':
      case 'tafsir':
        return section.trim();
      default:
        return section.trim().toLowerCase();
    }
  }

  // Load all sections (using canonical keys)
  Future<void> loadAllSections() async {
    _setLoading(true);
    _setError(null);

    try {
      _allLectures = await _repository.getAllLectures();
      _fiqhLectures = await _repository.getLecturesBySection('fiqh');
      _hadithLectures = await _repository.getLecturesBySection('hadith');
      _tafsirLectures = await _repository.getLecturesBySection('tafsir');
      _seerahLectures = await _repository.getLecturesBySection('seerah');

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في تحميل المحاضرات: $e');
    }
  }

  // Load lectures by subcategory
  Future<List<Map<String, dynamic>>> loadLecturesBySubcategory(
    String subcategoryId,
  ) async {
    _setLoading(true);
    _setError(null);

    try {
      final lectures = await _repository.getLecturesBySubcategory(
        subcategoryId,
      );
      _setLoading(false);
      return lectures;
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في تحميل المحاضرات: $e');
      return [];
    }
  }

  // Add lecture
  Future<bool> addLecture({
    required String title,
    required String description,
    String? videoPath,
    required String section,
    String? categoryId,
    String? categoryName,
    String? subcategoryId,
    String? subcategoryName,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      // Normalize section to canonical key
      final normalizedSection = _normalizeSectionKey(section);
      developer.log(
        '[LectureProvider] Adding lecture: section=$normalizedSection, categoryId=$categoryId, subcategoryId=$subcategoryId',
      );

      final result = await _repository.addLecture(
        title: title,
        description: description,
        videoPath: videoPath,
        section: normalizedSection,
        categoryId: categoryId,
        categoryName: categoryName,
        subcategoryId: subcategoryId,
        subcategoryName: subcategoryName,
      );

      if (result['success']) {
        // Reload the specific section and all lectures
        await loadLecturesBySection(normalizedSection);
        await loadAllLectures();
        _setLoading(false);
        return true;
      } else {
        _setLoading(false);
        _setError(result['message']);
        return false;
      }
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في إضافة المحاضرة: $e');
      return false;
    }
  }

  // Update lecture
  Future<bool> updateLecture({
    required String id,
    required String title,
    required String description,
    String? videoPath,
    required String section,
    String? subcategoryId,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final result = await _repository.updateLecture(
        id: id,
        title: title,
        description: description,
        videoPath: videoPath,
        section: section,
        subcategoryId: subcategoryId,
      );

      if (result['success']) {
        // Reload the specific section and all lectures
        await loadLecturesBySection(section);
        await loadAllLectures();
        _setLoading(false);
        return true;
      } else {
        _setLoading(false);
        _setError(result['message']);
        return false;
      }
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في تحديث المحاضرة: $e');
      return false;
    }
  }

  // Delete lecture
  Future<bool> deleteLecture(String lectureId, String section) async {
    _setLoading(true);
    _setError(null);

    try {
      final success = await _repository.deleteLecture(lectureId);

      if (success) {
        // Reload the specific section and all lectures
        await loadLecturesBySection(section);
        await loadAllLectures();
        _setLoading(false);
        return true;
      } else {
        _setLoading(false);
        _setError('فشل في حذف المحاضرة');
        return false;
      }
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في حذف المحاضرة: $e');
      return false;
    }
  }

  // Search lectures
  Future<List<Map<String, dynamic>>> searchLectures(String query) async {
    try {
      return await _repository.searchLectures(query);
    } catch (e) {
      _setError('حدث خطأ في البحث: $e');
      return [];
    }
  }

  // Get lectures by section without loading state change
  List<Map<String, dynamic>> getLecturesBySection(String section) {
    switch (section) {
      case 'الفقه':
        return _fiqhLectures;
      case 'الحديث':
        return _hadithLectures;
      case 'التفسير':
        return _tafsirLectures;
      case 'السيرة':
        return _seerahLectures;
      default:
        return [];
    }
  }

  // ==================== Sheikh Lecture Management ====================

  List<Map<String, dynamic>> _sheikhLectures = [];
  Map<String, dynamic>? _sheikhStats;

  // Getters for sheikh lectures
  List<Map<String, dynamic>> get sheikhLectures => _sheikhLectures;
  Map<String, dynamic>? get sheikhStats => _sheikhStats;

  // Load lectures for current sheikh
  Future<void> loadSheikhLectures(String sheikhId) async {
    _setLoading(true);
    _setError(null);

    try {
      _sheikhLectures = await _repository.getLecturesBySheikh(sheikhId);
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في تحميل محاضرات الشيخ: $e');
    }
  }

  // Load sheikh lecture statistics
  Future<void> loadSheikhStats(String sheikhId) async {
    try {
      _sheikhStats = await _repository.getSheikhLectureStats(sheikhId);
      notifyListeners();
    } catch (e) {
      print('Error loading sheikh stats: $e');
    }
  }

  // Add lecture for sheikh
  Future<bool> addSheikhLecture({
    required String sheikhId,
    required String sheikhName,
    required String section,
    required String categoryId,
    required String categoryName,
    String? subcategoryId,
    String? subcategoryName,
    required String title,
    String? description,
    required DateTime startTime,
    DateTime? endTime,
    Map<String, dynamic>? location,
    Map<String, dynamic>? media,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      // Check for overlapping lectures
      // Conflict exists ONLY when: sameSheikh AND sameCategory AND exact same datetime
      // The datetime includes full precision: year, month, day, hour, minute
      // Converting to UTC milliseconds ensures consistent timezone handling
      final startTimeMillis = startTime.toUtc().millisecondsSinceEpoch;
      final endTimeMillis = endTime?.toUtc().millisecondsSinceEpoch;

      // Log the datetime being checked for diagnostics
      final dateTimeStr =
          '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')} ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      developer.log(
        '[LectureProvider] Checking conflict for: sheikhId=$sheikhId, categoryId=$categoryId, datetime=$dateTimeStr, timestamp=$startTimeMillis',
        name: 'addSheikhLecture',
      );

      final hasOverlap = await _repository.hasOverlappingLectures(
        sheikhId: sheikhId,
        categoryId: categoryId,
        startTime: startTimeMillis,
        endTime: endTimeMillis,
      );

      if (hasOverlap) {
        _setLoading(false);
        _setError('يوجد محاضرة أخرى في نفس الفئة والتاريخ والوقت بالضبط');
        return false;
      }

      // Normalize section to canonical key before saving
      final normalizedSection = _normalizeSectionKey(section);
      developer.log(
        '[LectureProvider] Adding lecture: original section=$section, normalized=$normalizedSection',
      );

      final result = await _repository.addSheikhLecture(
        sheikhId: sheikhId,
        sheikhName: sheikhName,
        section: normalizedSection,
        categoryId: categoryId,
        categoryName: categoryName,
        subcategoryId: subcategoryId,
        subcategoryName: subcategoryName,
        title: title,
        description: description,
        startTime: startTimeMillis,
        endTime: endTimeMillis,
        location: location,
        media: media,
      );

      if (result['success']) {
        // Reload sheikh lectures and stats
        await loadSheikhLectures(sheikhId);
        await loadSheikhStats(sheikhId);
        // Also reload all lectures for home page visibility
        await loadAllLectures();
        // Reload the section's lectures
        await loadLecturesBySection(normalizedSection);
        // Clear home hierarchy cache to force refresh
        // Note: HierarchyProvider will be notified separately if needed
        _setLoading(false);
        return true;
      } else {
        _setLoading(false);
        _setError(result['message']);
        return false;
      }
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في إضافة المحاضرة: $e');
      return false;
    }
  }

  // Update sheikh lecture
  Future<bool> updateSheikhLecture({
    required String lectureId,
    required String sheikhId,
    required String categoryId,
    required String title,
    String? description,
    required DateTime startTime,
    DateTime? endTime,
    Map<String, dynamic>? location,
    Map<String, dynamic>? media,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      // Check for overlapping lectures (excluding current lecture)
      // Conflict exists ONLY when: sameSheikh AND sameCategory AND exact same datetime
      // The datetime includes full precision: year, month, day, hour, minute
      // Converting to UTC milliseconds ensures consistent timezone handling
      final startTimeMillis = startTime.toUtc().millisecondsSinceEpoch;
      final endTimeMillis = endTime?.toUtc().millisecondsSinceEpoch;

      // Log the datetime being checked for diagnostics
      final dateTimeStr =
          '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')} ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      developer.log(
        '[LectureProvider] Checking conflict for update: lectureId=$lectureId, sheikhId=$sheikhId, categoryId=$categoryId, datetime=$dateTimeStr, timestamp=$startTimeMillis',
        name: 'updateSheikhLecture',
      );

      final hasOverlap = await _repository.hasOverlappingLectures(
        sheikhId: sheikhId,
        categoryId: categoryId,
        startTime: startTimeMillis,
        endTime: endTimeMillis,
        excludeLectureId: lectureId,
      );

      if (hasOverlap) {
        _setLoading(false);
        _setError('يوجد محاضرة أخرى في نفس الفئة والتاريخ والوقت بالضبط');
        return false;
      }

      final result = await _repository.updateSheikhLecture(
        lectureId: lectureId,
        sheikhId: sheikhId,
        title: title,
        description: description,
        startTime: startTimeMillis,
        endTime: endTimeMillis,
        location: location,
        media: media,
      );

      if (result['success']) {
        // Reload sheikh lectures and stats
        await loadSheikhLectures(sheikhId);
        await loadSheikhStats(sheikhId);
        // Also reload all lectures for home page visibility
        await loadAllLectures();
        // Reload all sections to ensure UI is updated everywhere
        await loadAllSections();
        _setLoading(false);
        return true;
      } else {
        _setLoading(false);
        _setError(result['message']);
        return false;
      }
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في تحديث المحاضرة: $e');
      return false;
    }
  }

  // Archive sheikh lecture
  Future<bool> archiveSheikhLecture({
    required String lectureId,
    required String sheikhId,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final result = await _repository.archiveSheikhLecture(
        lectureId: lectureId,
        sheikhId: sheikhId,
      );

      if (result['success']) {
        // Reload sheikh lectures and stats
        await loadSheikhLectures(sheikhId);
        await loadSheikhStats(sheikhId);
        _setLoading(false);
        return true;
      } else {
        _setLoading(false);
        _setError(result['message']);
        return false;
      }
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في أرشفة المحاضرة: $e');
      return false;
    }
  }

  // Permanently delete sheikh lecture
  Future<bool> deleteSheikhLecture({
    required String lectureId,
    required String sheikhId,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final result = await _repository.deleteSheikhLecture(
        lectureId: lectureId,
        sheikhId: sheikhId,
      );

      if (result['success']) {
        // Reload sheikh lectures and stats
        await loadSheikhLectures(sheikhId);
        await loadSheikhStats(sheikhId);
        _setLoading(false);
        return true;
      } else {
        _setLoading(false);
        _setError(result['message']);
        return false;
      }
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في حذف المحاضرة: $e');
      return false;
    }
  }

  // Get lectures by sheikh and category
  Future<List<Map<String, dynamic>>> loadSheikhLecturesByCategory(
    String sheikhId,
    String categoryKey,
  ) async {
    _setLoading(true);
    _setError(null);

    try {
      final lectures = await _repository.getLecturesBySheikhAndCategory(
        sheikhId,
        categoryKey,
      );
      _setLoading(false);
      return lectures;
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في تحميل محاضرات الفئة: $e');
      return [];
    }
  }

  // Clear sheikh data
  void clearSheikhData() {
    _sheikhLectures = [];
    _sheikhStats = null;
    notifyListeners();
  }
}
