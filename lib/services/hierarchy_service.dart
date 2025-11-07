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
    // Log category_id being passed
    print(
      '[HierarchyService] Adding subcategory: name=$name, section=$section, categoryId=$categoryId',
    );

    final result = await _repository.addSubcategory(
      name: name,
      section: section,
      categoryId: categoryId,
      description: description,
      iconName: null,
    );

    // Log final category_id saved
    if (result['success']) {
      print(
        '[HierarchyService] Subcategory added: id=${result['subcategory_id']}, categoryId=$categoryId',
      );
    }

    return result;
  }

  /// Update subcategory
  Future<Map<String, dynamic>> updateSubcategory({
    required String subcategoryId,
    required String name,
    String? categoryId,
    String? description,
    int? order,
    bool? isActive,
  }) async {
    // Log category_id update if provided
    if (categoryId != null) {
      print(
        '[HierarchyService] Updating subcategory: id=$subcategoryId, categoryId=$categoryId',
      );
    }

    return await _repository.updateSubcategory(
      id: subcategoryId,
      name: name,
      categoryId: categoryId,
      description: description,
      iconName: null,
    );
  }

  /// Soft delete subcategory and its lectures
  Future<Map<String, dynamic>> softDeleteSubcategory(
    String subcategoryId,
  ) async {
    try {
      return await _repository.softDeleteSubcategory(subcategoryId);
    } catch (e) {
      return {'success': false, 'message': 'حدث خطأ في حذف الفئة الفرعية: $e'};
    }
  }

  /// Move lectures from one subcategory to another, then soft delete source
  Future<Map<String, dynamic>> moveLecturesToSubcategory(
    String fromSubcategoryId,
    String toSubcategoryId,
  ) async {
    try {
      return await _repository.moveLecturesToSubcategory(
        fromSubcategoryId,
        toSubcategoryId,
      );
    } catch (e) {
      return {'success': false, 'message': 'حدث خطأ في نقل المحاضرات: $e'};
    }
  }

  /// Delete subcategory (legacy - now uses soft delete)
  @Deprecated('Use softDeleteSubcategory or moveLecturesToSubcategory instead')
  Future<Map<String, dynamic>> deleteSubcategory(String subcategoryId) async {
    return await softDeleteSubcategory(subcategoryId);
  }

  /// Get subcategories for a category
  Future<List<Map<String, dynamic>>> getSubcategoriesByCategory(
    String categoryId,
  ) async {
    try {
      return await _repository.getSubcategoriesByCategory(categoryId);
    } catch (e) {
      print('Error loading subcategories by category: $e');
      return [];
    }
  }

  /// Get real-time stream of subcategories for a category
  Stream<List<Map<String, dynamic>>> getSubcategoriesStream(String categoryId) {
    // Return empty stream for offline mode
    return Stream.value([]);
  }

  // ==================== Lectures with Hierarchy ====================

  /// Get full home hierarchy: Section → Category → Subcategory → Lectures
  /// Single source of truth for Home screen
  Future<Map<String, dynamic>> getHomeHierarchy() async {
    try {
      return await _repository.getHomeHierarchy();
    } catch (e) {
      print('Error loading home hierarchy: $e');
      return {};
    }
  }

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
  /// Filtering precedence:
  /// 1. If subcategoryId present → filter by subcategory
  /// 2. Else if categoryId present → filter by category
  /// 3. Else → filter by section
  Stream<List<Map<String, dynamic>>> getLecturesStream({
    required String section,
    String? categoryId,
    String? subcategoryId,
  }) {
    // For offline: Poll every 2 seconds
    return Stream.periodic(const Duration(seconds: 2), (_) async {
      if (subcategoryId != null) {
        return await _repository.getLecturesBySubcategory(subcategoryId);
      } else if (categoryId != null) {
        return await _repository.getLecturesByCategory(categoryId);
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
