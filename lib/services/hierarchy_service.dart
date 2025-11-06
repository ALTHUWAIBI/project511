import 'package:new_project/repository/local_repository.dart';

/// HierarchyService - Local SQLite implementation
/// Provides category and subcategory hierarchy management
class HierarchyService {
  final LocalRepository _repository = LocalRepository();

  // Categories Collection
  static const String categoriesCollection = 'categories';
  static const String subcategoriesCollection = 'subcategories';
  static const String lecturesCollection = 'lectures';

  // ==================== Categories Management ====================

  /// Add a new category
  Future<Map<String, dynamic>> addCategory({
    required String section,
    required String name,
    String? description,
    int? order,
    required String createdBy,
  }) async {
    try {
      return await _repository.addCategory(
        sectionId: section,
        name: name,
        description: description,
        order: order ?? 0,
      );
    } catch (e) {
      return {
        'success': false,
        'message': 'حدث خطأ في إضافة الفئة: $e',
        'categoryId': '',
      };
    }
  }

  /// Update category
  Future<Map<String, dynamic>> updateCategory({
    required String categoryId,
    required String name,
    String? description,
    int? order,
    bool? isActive,
  }) async {
    try {
      return await _repository.updateCategory(
        categoryId: categoryId,
        name: name,
        description: description,
        order: order,
      );
    } catch (e) {
      return {'success': false, 'message': 'حدث خطأ في تحديث الفئة: $e'};
    }
  }

  /// Delete category
  Future<Map<String, dynamic>> deleteCategory(String categoryId) async {
    try {
      return await _repository.deleteCategory(categoryId);
    } catch (e) {
      return {'success': false, 'message': 'حدث خطأ في حذف الفئة: $e'};
    }
  }

  /// Get categories for a section
  Future<List<Map<String, dynamic>>> getCategoriesBySection(
    String section,
  ) async {
    try {
      return await _repository.getCategoriesBySection(section);
    } catch (e) {
      print('Error loading categories by section: $e');
      return [];
    }
  }

  /// Get real-time stream of categories for a section
  /// For offline: Return a single-value stream
  Stream<List<Map<String, dynamic>>> getCategoriesStream(String section) {
    // Return empty stream for offline mode
    return Stream.value([]);
  }

  // ==================== Subcategories Management ====================

  /// Add a new subcategory
  Future<Map<String, dynamic>> addSubcategory({
    required String section,
    required String categoryId,
    required String categoryName,
    required String name,
    String? description,
    int? order,
    required String createdBy,
  }) async {
    return await _repository.addSubcategory(
      name: name,
      section: section,
      description: description,
      iconName: null,
    );
  }

  /// Update subcategory
  Future<Map<String, dynamic>> updateSubcategory({
    required String subcategoryId,
    required String name,
    String? description,
    int? order,
    bool? isActive,
  }) async {
    return await _repository.updateSubcategory(
      id: subcategoryId,
      name: name,
      description: description,
      iconName: null,
    );
  }

  /// Delete subcategory
  Future<Map<String, dynamic>> deleteSubcategory(String subcategoryId) async {
    final success = await _repository.deleteSubcategory(subcategoryId);
    return {
      'success': success,
      'message': success
          ? 'تم حذف الفئة الفرعية بنجاح'
          : 'فشل حذف الفئة الفرعية',
    };
  }

  /// Get subcategories for a category
  Future<List<Map<String, dynamic>>> getSubcategoriesByCategory(
    String categoryId,
  ) async {
    // For offline-only: Get by section instead
    // This is a limitation - we'd need category mapping
    return [];
  }

  /// Get real-time stream of subcategories for a category
  Stream<List<Map<String, dynamic>>> getSubcategoriesStream(String categoryId) {
    // Return empty stream for offline mode
    return Stream.value([]);
  }

  // ==================== Lectures with Hierarchy ====================

  /// Get lectures with hierarchy filtering
  Future<List<Map<String, dynamic>>> getLecturesWithHierarchy({
    required String section,
    String? categoryId,
    String? subcategoryId,
  }) async {
    try {
      if (subcategoryId != null) {
        return await _repository.getLecturesBySubcategory(subcategoryId);
      } else {
        return await _repository.getLecturesBySection(section);
      }
    } catch (e) {
      print('Error loading lectures with hierarchy: $e');
      return [];
    }
  }

  /// Get real-time stream of lectures with hierarchy filtering
  Stream<List<Map<String, dynamic>>> getLecturesStream({
    required String section,
    String? categoryId,
    String? subcategoryId,
  }) {
    // For offline: Poll every 2 seconds
    return Stream.periodic(const Duration(seconds: 2), (_) async {
      if (subcategoryId != null) {
        return await _repository.getLecturesBySubcategory(subcategoryId);
      } else {
        return await _repository.getLecturesBySection(section);
      }
    }).asyncMap((future) => future);
  }

  // ==================== Helper Methods ====================

  /// Get section name in Arabic
  String getSectionNameAr(String section) {
    switch (section) {
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

  /// Get section key from Arabic name
  String getSectionKey(String sectionNameAr) {
    switch (sectionNameAr) {
      case 'الفقه':
        return 'fiqh';
      case 'الحديث':
        return 'hadith';
      case 'السيرة':
        return 'seerah';
      case 'التفسير':
        return 'tafsir';
      default:
        return sectionNameAr.toLowerCase();
    }
  }
}
