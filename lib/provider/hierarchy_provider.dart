import 'package:flutter/material.dart';
import 'package:new_project/services/hierarchy_service.dart';
import 'dart:developer' as developer;

class HierarchyProvider extends ChangeNotifier {
  final HierarchyService _hierarchyService = HierarchyService();

  // State variables
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedSection;
  // Store categories per section for persistence
  final Map<String, List<Map<String, dynamic>>> _categoriesBySection = {};
  List<Map<String, dynamic>> _subcategories = [];
  List<Map<String, dynamic>> _lectures = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get selectedSection => _selectedSection;
  // Get categories for currently selected section
  List<Map<String, dynamic>> get categories {
    if (_selectedSection != null) {
      return _categoriesBySection[_selectedSection!] ?? [];
    }
    return [];
  }

  List<Map<String, dynamic>> get subcategories => _subcategories;
  List<Map<String, dynamic>> get lectures => _lectures;

  // Private methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // ==================== Categories Management ====================

  /// Set selected section and load categories
  Future<void> setSelectedSection(String section) async {
    _selectedSection = section;
    _subcategories.clear(); // Clear dependent data
    _lectures.clear();
    notifyListeners();
    await loadCategoriesBySection(section);
  }

  /// Load categories for a section (public reload API)
  /// Sets loading flag, fetches from SQLite, updates in-memory state, notifies listeners
  Future<void> loadCategoriesBySection(String section) async {
    developer.log(
      '[HierarchyProvider] Reloading categories for section: $section',
      name: 'loadCategoriesBySection',
    );
    _setLoading(true);
    _setError(null);
    notifyListeners(); // Notify before fetch

    try {
      final categories = await _hierarchyService.getCategoriesBySection(
        section,
      );
      _categoriesBySection[section] = categories;
      developer.log(
        '[HierarchyProvider] Loaded ${categories.length} categories for section: $section',
        name: 'loadCategoriesBySection',
      );
      _setLoading(false);
    } catch (e) {
      developer.log(
        '[HierarchyProvider] Error loading categories: $e',
        name: 'loadCategoriesBySection',
      );
      _setLoading(false);
      _setError('حدث خطأ في تحميل الفئات: $e');
    }
  }

  /// Reload categories for the currently selected section
  Future<void> reloadCurrentSectionCategories() async {
    if (_selectedSection != null) {
      await loadCategoriesBySection(_selectedSection!);
    }
  }

  /// Add a new category
  Future<bool> addCategory({
    required String section,
    required String name,
    String? description,
    int? order,
    required String createdBy,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final result = await _hierarchyService.addCategory(
        section: section,
        name: name,
        description: description,
        order: order,
        createdBy: createdBy,
      );

      if (result['success']) {
        // Clear home hierarchy cache after adding category
        clearHomeHierarchyCache();
        // Reload categories
        await loadCategoriesBySection(section);
        _setLoading(false);
        return true;
      } else {
        _setLoading(false);
        _setError(result['message']);
        return false;
      }
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في إضافة الفئة: $e');
      return false;
    }
  }

  /// Update category
  Future<bool> updateCategory({
    required String categoryId,
    required String name,
    String? description,
    int? order,
    bool? isActive,
  }) async {
    developer.log(
      '[HierarchyProvider] Updating category: $categoryId',
      name: 'updateCategory',
    );
    _setLoading(true);
    _setError(null);

    try {
      // Get section from existing category before update
      String sectionId = _selectedSection ?? '';
      if (sectionId.isEmpty) {
        // Try to find category in any section
        for (final entry in _categoriesBySection.entries) {
          final found = entry.value.firstWhere(
            (c) => c['id'] == categoryId,
            orElse: () => {},
          );
          if (found.isNotEmpty) {
            sectionId = found['section_id'] as String? ?? entry.key;
            break;
          }
        }
      }

      final result = await _hierarchyService.updateCategory(
        categoryId: categoryId,
        name: name,
        description: description,
        order: order,
        isActive: isActive,
      );

      if (result['success']) {
        // Reload categories for the affected section
        if (sectionId.isNotEmpty) {
          await loadCategoriesBySection(sectionId);
        }
        _setLoading(false);
        return true;
      } else {
        _setLoading(false);
        _setError(result['message']);
        return false;
      }
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في تحديث الفئة: $e');
      return false;
    }
  }

  /// Delete category
  Future<bool> deleteCategory(String categoryId) async {
    developer.log(
      '[HierarchyProvider] Deleting category: $categoryId',
      name: 'deleteCategory',
    );
    _setLoading(true);
    _setError(null);

    try {
      // Get section from existing category before delete
      String sectionId = _selectedSection ?? '';
      if (sectionId.isEmpty) {
        // Try to find category in any section
        for (final entry in _categoriesBySection.entries) {
          final found = entry.value.firstWhere(
            (c) => c['id'] == categoryId,
            orElse: () => {},
          );
          if (found.isNotEmpty) {
            sectionId = found['section_id'] as String? ?? entry.key;
            break;
          }
        }
      }

      final result = await _hierarchyService.deleteCategory(categoryId);

      if (result['success']) {
        // Clear home hierarchy cache after deleting category
        clearHomeHierarchyCache();
        // Reload categories for the affected section
        if (sectionId.isNotEmpty) {
          await loadCategoriesBySection(sectionId);
        }
        _setLoading(false);
        return true;
      } else {
        _setLoading(false);
        _setError(result['message']);
        return false;
      }
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في حذف الفئة: $e');
      return false;
    }
  }

  // ==================== Subcategories Management ====================

  /// Load subcategories for a category
  Future<void> loadSubcategoriesByCategory(String categoryId) async {
    _setLoading(true);
    _setError(null);

    try {
      _subcategories = await _hierarchyService.getSubcategoriesByCategory(
        categoryId,
      );
      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في تحميل الفئات الفرعية: $e');
    }
  }

  /// Add a new subcategory
  Future<bool> addSubcategory({
    required String section,
    required String categoryId,
    required String categoryName,
    required String name,
    String? description,
    int? order,
    required String createdBy,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final result = await _hierarchyService.addSubcategory(
        section: section,
        categoryId: categoryId,
        categoryName: categoryName,
        name: name,
        description: description,
        order: order,
        createdBy: createdBy,
      );

      if (result['success']) {
        // Reload subcategories
        await loadSubcategoriesByCategory(categoryId);
        _setLoading(false);
        return true;
      } else {
        _setLoading(false);
        _setError(result['message']);
        return false;
      }
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في إضافة الفئة الفرعية: $e');
      return false;
    }
  }

  /// Update subcategory
  Future<bool> updateSubcategory({
    required String subcategoryId,
    required String name,
    String? categoryId,
    String? description,
    int? order,
    bool? isActive,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final result = await _hierarchyService.updateSubcategory(
        subcategoryId: subcategoryId,
        name: name,
        categoryId: categoryId,
        description: description,
        order: order,
        isActive: isActive,
      );

      if (result['success']) {
        // Clear home hierarchy cache after update
        clearHomeHierarchyCache();
        _setLoading(false);
        return true;
      } else {
        _setLoading(false);
        _setError(result['message']);
        return false;
      }
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في تحديث الفئة الفرعية: $e');
      return false;
    }
  }

  /// Soft delete subcategory and its lectures
  Future<Map<String, dynamic>> softDeleteSubcategory(
    String subcategoryId,
    String? userId,
  ) async {
    _setLoading(true);
    _setError(null);

    try {
      // Audit log
      developer.log(
        '[HierarchyProvider] Soft deleting subcategory: $subcategoryId by user: ${userId ?? "unknown"}',
        name: 'softDeleteSubcategory',
      );

      final result = await _hierarchyService.softDeleteSubcategory(
        subcategoryId,
      );

      if (result['success']) {
        // Clear home hierarchy cache after deleting subcategory
        clearHomeHierarchyCache();
        _setLoading(false);
        return result;
      } else {
        _setLoading(false);
        _setError(result['message']);
        return result;
      }
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في حذف الفئة الفرعية: $e');
      return {'success': false, 'message': 'حدث خطأ في حذف الفئة الفرعية: $e'};
    }
  }

  /// Move lectures from one subcategory to another, then soft delete source
  Future<Map<String, dynamic>> moveLecturesToSubcategory(
    String fromSubcategoryId,
    String toSubcategoryId,
    String? userId,
  ) async {
    _setLoading(true);
    _setError(null);

    try {
      // Audit log
      developer.log(
        '[HierarchyProvider] Moving lectures from subcategory: $fromSubcategoryId to: $toSubcategoryId by user: ${userId ?? "unknown"}',
        name: 'moveLecturesToSubcategory',
      );

      final result = await _hierarchyService.moveLecturesToSubcategory(
        fromSubcategoryId,
        toSubcategoryId,
      );

      if (result['success']) {
        // Clear home hierarchy cache after moving lectures
        clearHomeHierarchyCache();
        _setLoading(false);
        return result;
      } else {
        _setLoading(false);
        _setError(result['message']);
        return result;
      }
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في نقل المحاضرات: $e');
      return {'success': false, 'message': 'حدث خطأ في نقل المحاضرات: $e'};
    }
  }

  /// Delete subcategory (legacy - now uses soft delete)
  @Deprecated('Use softDeleteSubcategory or moveLecturesToSubcategory instead')
  Future<bool> deleteSubcategory(String subcategoryId) async {
    final result = await softDeleteSubcategory(subcategoryId, null);
    return result['success'] == true;
  }

  // ==================== Lectures Management ====================

  // Home hierarchy cache
  Map<String, dynamic>? _homeHierarchy;
  DateTime? _homeHierarchyLastUpdated;

  /// Get home hierarchy (cached)
  Map<String, dynamic>? get homeHierarchy => _homeHierarchy;

  /// Get hierarchy for a specific section (no DB calls, just returns cached data)
  Map<String, dynamic>? getSectionHierarchy(String section) {
    if (_homeHierarchy == null) return null;
    final sectionData = _homeHierarchy![section] as Map<String, dynamic>?;
    return sectionData ??
        <String, dynamic>{
          'categories': <List<dynamic>>[],
          'uncategorizedLectures': <List<dynamic>>[],
        };
  }

  /// Load full home hierarchy: Section → Category → Subcategory → Lectures
  /// Single source of truth for Home screen
  Future<void> loadHomeHierarchy({bool forceRefresh = false}) async {
    // Return cached data if fresh (within 5 seconds) and not forcing refresh
    if (!forceRefresh &&
        _homeHierarchy != null &&
        _homeHierarchyLastUpdated != null) {
      final age = DateTime.now().difference(_homeHierarchyLastUpdated!);
      if (age.inSeconds < 5) {
        developer.log(
          '[HierarchyProvider] Using cached home hierarchy (age: ${age.inSeconds}s)',
        );
        return;
      }
    }

    developer.log(
      '[HierarchyProvider] Loading home hierarchy (forceRefresh=$forceRefresh)',
    );
    _setLoading(true);
    _setError(null);
    notifyListeners(); // Notify before fetch

    try {
      final startTime = DateTime.now();
      _homeHierarchy = await _hierarchyService.getHomeHierarchy();
      _homeHierarchyLastUpdated = DateTime.now();
      final loadTime = DateTime.now().difference(startTime);

      developer.log(
        '[HierarchyProvider] Home hierarchy loaded in ${loadTime.inMilliseconds}ms',
      );

      // DIAGNOSTIC: Log hierarchy structure size and keys
      developer.log(
        '[HierarchyProvider] Hierarchy structure keys: ${_homeHierarchy?.keys.toList()}',
      );
      developer.log(
        '[HierarchyProvider] Hierarchy structure size: ${_homeHierarchy?.length ?? 0} sections',
      );

      // Log counts with detailed breakdown
      final sections = ['fiqh', 'hadith', 'tafsir', 'seerah'];
      for (final section in sections) {
        final sectionData = _homeHierarchy?[section] as Map<String, dynamic>?;
        if (sectionData != null) {
          final categories = sectionData['categories'] as List? ?? [];
          final uncategorizedLectures =
              sectionData['uncategorizedLectures'] as List? ?? [];
          int totalLectures = uncategorizedLectures.length;
          int totalSubcategories = 0;

          // DIAGNOSTIC: Log per-category breakdown
          for (final catData in categories) {
            final cat = catData['category'] as Map<String, dynamic>?;
            final catName = cat?['name']?.toString() ?? 'unknown';
            final subcategories = catData['subcategories'] as List? ?? [];
            totalSubcategories += subcategories.length;
            int catLectureCount = 0;
            for (final subcatData in subcategories) {
              final subcat = subcatData['subcategory'] as Map<String, dynamic>?;
              final subcatName = subcat?['name']?.toString() ?? 'unknown';
              final lectures = subcatData['lectures'] as List? ?? [];
              catLectureCount += lectures.length;
              developer.log(
                '[HierarchyProvider] Section $section → Category $catName → Subcategory $subcatName: ${lectures.length} lectures',
              );
            }
            developer.log(
              '[HierarchyProvider] Section $section → Category $catName: ${subcategories.length} subcategories, $catLectureCount lectures',
            );
          }

          developer.log(
            '[HierarchyProvider] Section $section: ${categories.length} categories, $totalSubcategories subcategories, $totalLectures lectures (${uncategorizedLectures.length} uncategorized)',
          );
        } else {
          developer.log(
            '[HierarchyProvider] Section $section: NO DATA (sectionData is null)',
          );
        }
      }

      _setLoading(false);
    } catch (e) {
      developer.log('[HierarchyProvider] Error loading home hierarchy: $e');
      _setLoading(false);
      _setError('حدث خطأ في تحميل البيانات: $e');
    }
  }

  /// Clear home hierarchy cache (call after CRUD operations)
  void clearHomeHierarchyCache() {
    developer.log(
      '[HierarchyProvider] clearHomeHierarchyCache called - invalidating cache',
    );
    _homeHierarchy = null;
    _homeHierarchyLastUpdated = null;
    notifyListeners();
  }

  /// Load lectures with hierarchy filtering
  Future<void> loadLecturesWithHierarchy({
    required String section,
    String? categoryId,
    String? subcategoryId,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      _lectures = await _hierarchyService.getLecturesWithHierarchy(
        section: section,
        categoryId: categoryId,
        subcategoryId: subcategoryId,
      );
      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في تحميل المحاضرات: $e');
    }
  }

  // ==================== Stream Methods ====================

  /// Get categories stream for a section
  Stream<List<Map<String, dynamic>>> getCategoriesStream(String section) {
    return _hierarchyService.getCategoriesStream(section);
  }

  /// Get subcategories stream for a category
  Stream<List<Map<String, dynamic>>> getSubcategoriesStream(String categoryId) {
    return _hierarchyService.getSubcategoriesStream(categoryId);
  }

  /// Get lectures stream with hierarchy filtering
  Stream<List<Map<String, dynamic>>> getLecturesStream({
    required String section,
    String? categoryId,
    String? subcategoryId,
  }) {
    return _hierarchyService.getLecturesStream(
      section: section,
      categoryId: categoryId,
      subcategoryId: subcategoryId,
    );
  }

  // ==================== Helper Methods ====================

  /// Get section name in Arabic
  String getSectionNameAr(String section) {
    return _hierarchyService.getSectionNameAr(section);
  }

  /// Get section key from Arabic name
  String getSectionKey(String sectionNameAr) {
    return _hierarchyService.getSectionKey(sectionNameAr);
  }

  /// Clear all data
  void clearData() {
    _categoriesBySection.clear();
    _subcategories.clear();
    _lectures.clear();
    _errorMessage = null;
    notifyListeners();
  }
}
