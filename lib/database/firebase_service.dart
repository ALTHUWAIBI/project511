import 'dart:async';
import 'package:new_project/offline/firestore_shims.dart';
import 'package:new_project/repository/local_repository.dart';

/// FirebaseService - Local SQLite implementation
/// Maintains the same public API as the original FirebaseService
/// for backward compatibility while using LocalRepository underneath
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  final LocalRepository _repo = LocalRepository();
  FirebaseService._internal();
  factory FirebaseService() => _instance;

  // ====== Users ======
  Future<Map<String, dynamic>> registerUser({
    required String username,
    required String email,
    required String password,
  }) async {
    return await _repo.registerUser(
      username: username,
      email: email,
      password: password,
    );
  }

  Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    return await _repo.loginUser(email: email, password: password);
  }

  Future<Map<String, dynamic>> loginAdmin({
    required String username,
    required String password,
  }) async {
    return await _repo.loginAdmin(username: username, password: password);
  }

  Future<Map<String, dynamic>> createAdminAccount({
    required String username,
    required String email,
    required String password,
  }) async {
    return await _repo.createAdminAccount(
      username: username,
      email: email,
      password: password,
    );
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    return await _repo.getAllUsers();
  }

  Future<bool> deleteUser(String userId) => _repo.deleteUser(userId);

  Future<Map<String, dynamic>?> getUserProfile(String userId) =>
      _repo.getUserProfile(userId);

  Future<Map<String, dynamic>> updateUserProfile({
    required String userId,
    String? name,
    String? gender,
    String? birthDate,
    String? profileImageUrl,
  }) {
    return _repo.updateUserProfile(
      userId: userId,
      name: name,
      gender: gender,
      birthDate: birthDate,
      profileImageUrl: profileImageUrl,
    );
  }

  Future<Map<String, dynamic>> changeUserPassword({
    required String userId,
    required String oldPassword,
    required String newPassword,
  }) {
    return _repo.changeUserPassword(
      userId: userId,
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  // ====== Subcategories ======
  Future<List<Map<String, dynamic>>> getSubcategoriesBySection(
    String section,
  ) => _repo.getSubcategoriesBySection(section);
  Future<Map<String, dynamic>?> getSubcategory(String id) =>
      _repo.getSubcategory(id);
  Future<Map<String, dynamic>> addSubcategory({
    required String name,
    required String section,
    String? categoryId,
    String? description,
    String? iconName,
  }) => _repo.addSubcategory(
    name: name,
    section: section,
    categoryId: categoryId,
    description: description,
    iconName: iconName,
  );
  Future<Map<String, dynamic>> updateSubcategory({
    required String id,
    required String name,
    String? categoryId,
    String? description,
    String? iconName,
  }) => _repo.updateSubcategory(
    id: id,
    name: name,
    categoryId: categoryId,
    description: description,
    iconName: iconName,
  );
  Future<bool> deleteSubcategory(String subcategoryId) =>
      _repo.deleteSubcategory(subcategoryId);

  // ====== Lectures ======
  Future<Map<String, dynamic>> addLecture({
    required String title,
    required String description,
    String? videoPath,
    required String section,
    String? categoryId,
    String? categoryName,
    String? subcategoryId,
    String? subcategoryName,
  }) => _repo.addLecture(
    title: title,
    description: description,
    videoPath: videoPath,
    section: section,
    categoryId: categoryId,
    categoryName: categoryName,
    subcategoryId: subcategoryId,
    subcategoryName: subcategoryName,
  );
  Future<List<Map<String, dynamic>>> getAllLectures() => _repo.getAllLectures();
  Future<List<Map<String, dynamic>>> getLecturesBySection(String section) =>
      _repo.getLecturesBySection(section);
  Future<List<Map<String, dynamic>>> getLecturesBySubcategory(
    String subcategoryId,
  ) => _repo.getLecturesBySubcategory(subcategoryId);
  Future<Map<String, dynamic>?> getLecture(String id) => _repo.getLecture(id);
  Future<Map<String, dynamic>> updateLecture({
    required String id,
    required String title,
    required String description,
    String? videoPath,
    required String section,
    String? subcategoryId,
  }) => _repo.updateLecture(
    id: id,
    title: title,
    description: description,
    videoPath: videoPath,
    section: section,
    subcategoryId: subcategoryId,
  );
  Future<bool> deleteLecture(String lectureId) =>
      _repo.deleteLecture(lectureId);
  Future<List<Map<String, dynamic>>> searchLectures(String query) =>
      _repo.searchLectures(query);

  // ====== Sheikh lectures ======
  Future<Map<String, dynamic>> addSheikhLecture({
    required String sheikhId,
    required String sheikhName,
    required String section,
    required String categoryId,
    required String categoryName,
    String? subcategoryId,
    String? subcategoryName,
    required String title,
    String? description,
    required Timestamp startTime,
    Timestamp? endTime,
    Map<String, dynamic>? location,
    Map<String, dynamic>? media,
  }) {
    return _repo.addSheikhLecture(
      sheikhId: sheikhId,
      sheikhName: sheikhName,
      section: section,
      categoryId: categoryId,
      categoryName: categoryName,
      subcategoryId: subcategoryId,
      subcategoryName: subcategoryName,
      title: title,
      description: description,
      startTime: startTime.toDate().millisecondsSinceEpoch,
      endTime: endTime?.toDate().millisecondsSinceEpoch,
      location: location,
      media: media,
    );
  }

  Future<List<Map<String, dynamic>>> getLecturesBySheikh(String sheikhId) =>
      _repo.getLecturesBySheikh(sheikhId);

  Future<List<Map<String, dynamic>>> getLecturesBySheikhAndCategory(
    String sheikhId,
    String categoryKey,
  ) => _repo.getLecturesBySheikhAndCategory(sheikhId, categoryKey);

  Future<Map<String, dynamic>> updateSheikhLecture({
    required String lectureId,
    required String sheikhId,
    required String title,
    String? description,
    required Timestamp startTime,
    Timestamp? endTime,
    Map<String, dynamic>? location,
    Map<String, dynamic>? media,
  }) {
    return _repo.updateSheikhLecture(
      lectureId: lectureId,
      sheikhId: sheikhId,
      title: title,
      description: description,
      startTime: startTime.toDate().millisecondsSinceEpoch,
      endTime: endTime?.toDate().millisecondsSinceEpoch,
      location: location,
      media: media,
    );
  }

  Future<Map<String, dynamic>> archiveSheikhLecture({
    required String lectureId,
    required String sheikhId,
  }) => _repo.archiveSheikhLecture(lectureId: lectureId, sheikhId: sheikhId);

  Future<Map<String, dynamic>> deleteSheikhLecture({
    required String lectureId,
    required String sheikhId,
  }) => _repo.deleteSheikhLecture(lectureId: lectureId, sheikhId: sheikhId);

  Future<bool> hasOverlappingLectures({
    required String sheikhId,
    required Timestamp startTime,
    Timestamp? endTime,
    String? excludeLectureId,
  }) => _repo.hasOverlappingLectures(
    sheikhId: sheikhId,
    startTime: startTime.toDate().millisecondsSinceEpoch,
    endTime: endTime?.toDate().millisecondsSinceEpoch,
    excludeLectureId: excludeLectureId,
  );

  Future<Map<String, dynamic>> getSheikhLectureStats(String sheikhId) =>
      _repo.getSheikhLectureStats(sheikhId);

  // ====== Initialization & helpers ======
  Future<void> initializeDefaultSubcategories() =>
      _repo.initializeDefaultSubcategoriesIfEmpty();

  Future<Map<String, dynamic>?> getUserByUniqueId(
    String uniqueId, {
    String role = 'sheikh',
  }) => _repo.getUserByUniqueId(uniqueId, role: role);

  Future<Map<String, dynamic>> deleteSheikhByUniqueId(String uniqueId) async {
    // Normalize uniqueId to exactly 8 digits (no padding, must be exactly 8)
    final normalized = uniqueId.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty || normalized.length != 8) {
      return {'success': false, 'message': 'رقم الشيخ غير صحيح'};
    }
    // Delegate to LocalRepository which handles soft delete and archiving
    return await _repo.deleteSheikhByUniqueId(normalized);
  }

  // Live stream replacement (polling)
  Stream<List<Map<String, dynamic>>> getLecturesForSheikh(
    String sheikhUid,
  ) async* {
    while (true) {
      final rows = await _repo.getLecturesBySheikh(sheikhUid);
      yield rows;
      await Future.delayed(const Duration(seconds: 2));
    }
  }
}
