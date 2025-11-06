import 'package:flutter/material.dart';
import 'package:new_project/repository/local_repository.dart';

class SubcategoryProvider extends ChangeNotifier {
  final LocalRepository _repository = LocalRepository();

  Map<String, List<Map<String, dynamic>>> _subcategoriesBySection = {};
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Map<String, dynamic>> getSubcategoriesBySection(String section) {
    return _subcategoriesBySection[section] ?? [];
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

  // Load subcategories by section
  Future<void> loadSubcategoriesBySection(String section) async {
    _setLoading(true);
    _setError(null);

    try {
      final subcategories = await _repository.getSubcategoriesBySection(
        section,
      );
      _subcategoriesBySection[section] = subcategories;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في تحميل الفئات الفرعية: $e');
    }
  }

  // Load all subcategories for all sections
  Future<void> loadAllSubcategories() async {
    _setLoading(true);
    _setError(null);

    try {
      final sections = ['الفقه', 'الحديث', 'التفسير', 'السيرة'];

      for (String section in sections) {
        final subcategories = await _repository.getSubcategoriesBySection(
          section,
        );
        _subcategoriesBySection[section] = subcategories;
      }

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في تحميل الفئات الفرعية: $e');
    }
  }

  // Add subcategory
  Future<bool> addSubcategory({
    required String name,
    required String section,
    required String categoryId,
    String? description,
    String? iconName,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final result = await _repository.addSubcategory(
        name: name,
        section: section,
        categoryId: categoryId,
        description: description,
        iconName: iconName,
      );

      if (result['success']) {
        await loadSubcategoriesBySection(section);
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

  // Update subcategory
  Future<bool> updateSubcategory({
    required String id,
    required String name,
    required String section,
    String? description,
    String? iconName,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final result = await _repository.updateSubcategory(
        id: id,
        name: name,
        description: description,
        iconName: iconName,
      );

      if (result['success']) {
        await loadSubcategoriesBySection(section);
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

  // Delete subcategory
  Future<bool> deleteSubcategory(String id, String section) async {
    _setLoading(true);
    _setError(null);

    try {
      final success = await _repository.deleteSubcategory(id);

      if (success) {
        await loadSubcategoriesBySection(section);
        _setLoading(false);
        return true;
      } else {
        _setLoading(false);
        _setError('فشل في حذف الفئة الفرعية');
        return false;
      }
    } catch (e) {
      _setLoading(false);
      _setError('حدث خطأ في حذف الفئة الفرعية: $e');
      return false;
    }
  }
}
