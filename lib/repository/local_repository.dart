import 'package:sqflite/sqflite.dart';
import 'package:new_project/database/app_database.dart';
import 'package:new_project/utils/time.dart';
import 'package:new_project/utils/hash.dart';
import 'package:new_project/utils/uuid.dart';
import 'package:new_project/utils/youtube_utils.dart';
import 'dart:developer' as developer;
import 'dart:convert';

/// Local Repository - SQLite-only implementation
/// Replaces FirebaseService with offline-only local database
/// Uses AppDatabase with defensive retry for crash-proof operations
class LocalRepository {
  /// Helper method to deserialize location JSON from database row
  Map<String, dynamic>? _deserializeLocation(dynamic locationData) {
    if (locationData == null) return null;

    final locationStr = locationData.toString();
    if (locationStr.isEmpty || locationStr == 'null') return null;

    try {
      final locationMap = jsonDecode(locationStr) as Map<String, dynamic>;
      return locationMap;
    } catch (e) {
      developer.log(
        '[LocalRepository] Error deserializing location: $e, data: $locationStr',
        name: '_deserializeLocation',
      );
      return null;
    }
  }

  final AppDatabase _dbService = AppDatabase();

  /// Helper to execute database operations with defensive retry
  Future<T> _withRetry<T>(
    Future<T> Function(Database) operation,
    String operationName,
  ) async {
    return await _dbService.withRetry(() async {
      final db = await _dbService.database;
      return await operation(db);
    }, operationName: operationName);
  }

  // ==================== User Management ====================

  /// Register a new user
  Future<Map<String, dynamic>> registerUser({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      return await _withRetry((db) async {
        // Check if email or username already exists
        final emailCheck = await db.query(
          'users',
          where: 'email = ?',
          whereArgs: [email],
          limit: 1,
        );

        if (emailCheck.isNotEmpty) {
          return {'success': false, 'message': 'الإيميل موجود مسبقاً'};
        }

        final usernameCheck = await db.query(
          'users',
          where: 'username = ?',
          whereArgs: [username],
          limit: 1,
        );

        if (usernameCheck.isNotEmpty) {
          return {'success': false, 'message': 'اسم المستخدم موجود مسبقاً'};
        }

        // Create new user
        final userId = generateUUID();
        final passwordHash = sha256Hex(password);
        final now = nowMillis();

        await db.insert('users', {
          'id': userId,
          'username': username,
          'email': email,
          'password_hash': passwordHash,
          'is_admin': 0,
          'created_at': now,
          'updated_at': now,
        });

        return {
          'success': true,
          'message': 'تم إنشاء الحساب بنجاح',
          'user_id': userId,
        };
      }, 'registerUser');
    } catch (e) {
      developer.log('Register user error: $e', name: 'LocalRepository');
      return {'success': false, 'message': 'حدث خطأ أثناء إنشاء الحساب: $e'};
    }
  }

  /// User login
  Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      return await _withRetry((db) async {
        final passwordHash = sha256Hex(password);

        final results = await db.query(
          'users',
          where: 'email = ? AND password_hash = ?',
          whereArgs: [email, passwordHash],
          limit: 1,
        );

        if (results.isEmpty) {
          return {
            'success': false,
            'message': 'الإيميل أو كلمة المرور غير صحيحة',
          };
        }

        final user = results.first;

        return {
          'success': true,
          'message': 'تم تسجيل الدخول بنجاح',
          'user': {
            'id': user['id'],
            'username': user['username'],
            'email': user['email'],
            'is_admin': (user['is_admin'] as int) == 1,
          },
        };
      }, 'loginUser');
    } catch (e) {
      developer.log('Login user error: $e', name: 'LocalRepository');
      return {'success': false, 'message': 'حدث خطأ أثناء تسجيل الدخول: $e'};
    }
  }

  /// Admin login
  Future<Map<String, dynamic>> loginAdmin({
    required String username,
    required String password,
  }) async {
    try {
      return await _withRetry((db) async {
        final passwordHash = sha256Hex(password);

        // Try username first
        var results = await db.query(
          'users',
          where: 'username = ? AND password_hash = ? AND is_admin = ?',
          whereArgs: [username, passwordHash, 1],
          limit: 1,
        );

        // If not found, try email
        if (results.isEmpty) {
          results = await db.query(
            'users',
            where: 'email = ? AND password_hash = ? AND is_admin = ?',
            whereArgs: [username, passwordHash, 1],
            limit: 1,
          );
        }

        if (results.isEmpty) {
          return {'success': false, 'message': 'بيانات المشرف غير صحيحة'};
        }

        final admin = results.first;

        return {
          'success': true,
          'message': 'مرحباً بك أيها المشرف',
          'admin': {
            'id': admin['id'],
            'username': admin['username'],
            'email': admin['email'],
            'is_admin': true,
          },
        };
      }, 'loginAdmin');
    } catch (e) {
      developer.log('Login admin error: $e', name: 'LocalRepository');
      return {
        'success': false,
        'message': 'حدث خطأ أثناء تسجيل دخول المشرف: $e',
      };
    }
  }

  /// Create admin account
  Future<Map<String, dynamic>> createAdminAccount({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      return await _withRetry((db) async {
        // Check if email exists
        final emailCheck = await db.query(
          'users',
          where: 'email = ?',
          whereArgs: [email],
          limit: 1,
        );

        if (emailCheck.isNotEmpty) {
          return {'success': false, 'message': 'الإيميل موجود مسبقاً'};
        }

        // Check if username exists
        final usernameCheck = await db.query(
          'users',
          where: 'username = ?',
          whereArgs: [username],
          limit: 1,
        );

        if (usernameCheck.isNotEmpty) {
          return {'success': false, 'message': 'اسم المستخدم موجود مسبقاً'};
        }

        // Create admin user
        final adminId = generateUUID();
        final passwordHash = sha256Hex(password);
        final now = nowMillis();

        await db.insert('users', {
          'id': adminId,
          'username': username,
          'email': email,
          'password_hash': passwordHash,
          'is_admin': 1,
          'created_at': now,
          'updated_at': now,
        });

        return {
          'success': true,
          'message': 'تم إنشاء حساب المشرف بنجاح',
          'admin_id': adminId,
        };
      }, 'createAdminAccount');
    } catch (e) {
      developer.log('Create admin error: $e', name: 'LocalRepository');
      return {
        'success': false,
        'message': 'حدث خطأ أثناء إنشاء حساب المشرف: $e',
      };
    }
  }

  /// Get all users (non-admin)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      return await _withRetry((db) async {
        final results = await db.query(
          'users',
          where: 'is_admin = ?',
          whereArgs: [0],
          orderBy: 'created_at DESC',
        );

        return results.map((row) {
          final user = Map<String, dynamic>.from(row);
          user['is_admin'] = (user['is_admin'] as int) == 1;
          user.remove('password_hash'); // Never return password hash
          return user;
        }).toList();
      }, 'getAllUsers');
    } catch (e) {
      developer.log('Get all users error: $e', name: 'LocalRepository');
      return [];
    }
  }

  /// Delete user
  Future<bool> deleteUser(String userId) async {
    try {
      return await _withRetry((db) async {
        await db.delete('users', where: 'id = ?', whereArgs: [userId]);
        return true;
      }, 'deleteUser');
    } catch (e) {
      developer.log('Delete user error: $e', name: 'LocalRepository');
      return false;
    }
  }

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      return await _withRetry((db) async {
        final results = await db.query(
          'users',
          where: 'id = ?',
          whereArgs: [userId],
          limit: 1,
        );

        if (results.isEmpty) return null;

        final user = Map<String, dynamic>.from(results.first);
        user['is_admin'] = (user['is_admin'] as int) == 1;
        user.remove('password_hash');
        return user;
      }, 'getUserProfile');
    } catch (e) {
      developer.log('Get user profile error: $e', name: 'LocalRepository');
      return null;
    }
  }

  /// Update user profile
  Future<Map<String, dynamic>> updateUserProfile({
    required String userId,
    String? name,
    String? gender,
    String? birthDate,
    String? profileImageUrl,
  }) async {
    try {
      return await _withRetry((db) async {
        final Map<String, dynamic> updateData = {'updated_at': nowMillis()};

        if (name != null) updateData['name'] = name;
        if (gender != null) updateData['gender'] = gender;
        if (birthDate != null) updateData['birth_date'] = birthDate;
        if (profileImageUrl != null) {
          updateData['profile_image_url'] = profileImageUrl;
        }

        await db.update(
          'users',
          updateData,
          where: 'id = ?',
          whereArgs: [userId],
        );

        return {'success': true, 'message': 'تم تحديث الملف الشخصي بنجاح'};
      }, 'updateUserProfile');
    } catch (e) {
      developer.log('Update user profile error: $e', name: 'LocalRepository');
      return {
        'success': false,
        'message': 'حدث خطأ أثناء تحديث الملف الشخصي: $e',
      };
    }
  }

  /// Change user password
  Future<Map<String, dynamic>> changeUserPassword({
    required String userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      // Verify old password
      final user = await getUserProfile(userId);
      if (user == null) {
        return {'success': false, 'message': 'المستخدم غير موجود'};
      }

      return await _withRetry((db) async {
        final results = await db.query(
          'users',
          columns: ['password_hash'],
          where: 'id = ?',
          whereArgs: [userId],
          limit: 1,
        );

        if (results.isEmpty) {
          return {'success': false, 'message': 'المستخدم غير موجود'};
        }

        final storedHash = results.first['password_hash'] as String;
        final oldPasswordHash = sha256Hex(oldPassword);

        if (storedHash != oldPasswordHash) {
          return {'success': false, 'message': 'كلمة المرور القديمة غير صحيحة'};
        }

        // Update password
        final newPasswordHash = sha256Hex(newPassword);
        await db.update(
          'users',
          {'password_hash': newPasswordHash, 'updated_at': nowMillis()},
          where: 'id = ?',
          whereArgs: [userId],
        );

        return {'success': true, 'message': 'تم تغيير كلمة المرور بنجاح'};
      }, 'changeUserPassword');
    } catch (e) {
      developer.log('Change password error: $e', name: 'LocalRepository');
      return {
        'success': false,
        'message': 'حدث خطأ أثناء تغيير كلمة المرور: $e',
      };
    }
  }

  // ==================== Subcategory Management ====================

  /// Get subcategories by section
  Future<List<Map<String, dynamic>>> getSubcategoriesBySection(
    String section,
  ) async {
    try {
      return await _withRetry((db) async {
        final results = await db.query(
          'subcategories',
          where: 'section = ?',
          whereArgs: [section],
          orderBy: 'created_at ASC',
        );
        return results;
      }, 'getSubcategoriesBySection');
    } catch (e) {
      developer.log(
        'Get subcategories by section error: $e',
        name: 'LocalRepository',
      );
      return [];
    }
  }

  /// Get subcategories by category (only non-deleted)
  Future<List<Map<String, dynamic>>> getSubcategoriesByCategory(
    String categoryId,
  ) async {
    try {
      return await _withRetry((db) async {
        final results = await db.query(
          'subcategories',
          where: 'category_id = ?',
          whereArgs: [categoryId],
          orderBy: 'created_at ASC',
        );

        developer.log(
          '[LocalRepository] getSubcategoriesByCategory: categoryId=$categoryId, found ${results.length} subcategories',
          name: 'getSubcategoriesByCategory',
        );

        return results;
      }, 'getSubcategoriesByCategory');
    } catch (e) {
      developer.log(
        'Get subcategories by category error: $e',
        name: 'LocalRepository',
      );
      return [];
    }
  }

  /// Get a single subcategory
  Future<Map<String, dynamic>?> getSubcategory(String id) async {
    try {
      return await _withRetry((db) async {
        final results = await db.query(
          'subcategories',
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        return results.isEmpty ? null : results.first;
      }, 'getSubcategory');
    } catch (e) {
      developer.log('Get subcategory error: $e', name: 'LocalRepository');
      return null;
    }
  }

  /// Add subcategory
  Future<Map<String, dynamic>> addSubcategory({
    required String name,
    required String section,
    String? categoryId,
    String? description,
    String? iconName,
  }) async {
    try {
      return await _withRetry((db) async {
        // Validate category_id is provided
        if (categoryId == null || categoryId.isEmpty) {
          developer.log(
            '[LocalRepository] ERROR: addSubcategory called without categoryId - this will create an orphaned subcategory',
            name: 'addSubcategory',
          );
          return {
            'success': false,
            'message': 'يجب تحديد الفئة الرئيسية للفئة الفرعية',
          };
        }

        // Verify category exists
        final categoryCheck = await db.query(
          'categories',
          where: 'id = ? AND isDeleted = ?',
          whereArgs: [categoryId, 0],
          limit: 1,
        );

        if (categoryCheck.isEmpty) {
          developer.log(
            '[LocalRepository] ERROR: Category not found: $categoryId',
            name: 'addSubcategory',
          );
          return {'success': false, 'message': 'الفئة الرئيسية غير موجودة'};
        }

        final subcatId = generateUUID();
        final now = nowMillis();

        // Log category_id being persisted
        developer.log(
          '[LocalRepository] Adding subcategory: name=$name, section=$section, categoryId=$categoryId',
          name: 'addSubcategory',
        );

        await db.insert('subcategories', {
          'id': subcatId,
          'name': name,
          'section': section,
          'category_id': categoryId,
          'description': description,
          'icon_name': iconName,
          'created_at': now,
        });

        developer.log(
          '[LocalRepository] Added subcategory: id=$subcatId, categoryId=$categoryId',
          name: 'addSubcategory',
        );

        return {
          'success': true,
          'message': 'تم إضافة الفئة الفرعية بنجاح',
          'subcategory_id': subcatId,
        };
      }, 'addSubcategory');
    } catch (e) {
      developer.log('Add subcategory error: $e', name: 'LocalRepository');
      return {
        'success': false,
        'message': 'حدث خطأ أثناء إضافة الفئة الفرعية: $e',
      };
    }
  }

  /// Update subcategory
  Future<Map<String, dynamic>> updateSubcategory({
    required String id,
    required String name,
    String? categoryId,
    String? description,
    String? iconName,
  }) async {
    try {
      return await _withRetry((db) async {
        final Map<String, dynamic> updateData = {'name': name};

        if (categoryId != null) {
          updateData['category_id'] = categoryId;
          developer.log(
            '[LocalRepository] Updating subcategory: id=$id, categoryId=$categoryId',
            name: 'updateSubcategory',
          );
        }
        if (description != null) updateData['description'] = description;
        if (iconName != null) updateData['icon_name'] = iconName;

        await db.update(
          'subcategories',
          updateData,
          where: 'id = ?',
          whereArgs: [id],
        );

        return {'success': true, 'message': 'تم تحديث الفئة الفرعية بنجاح'};
      }, 'updateSubcategory');
    } catch (e) {
      developer.log('Update subcategory error: $e', name: 'LocalRepository');
      return {
        'success': false,
        'message': 'حدث خطأ أثناء تحديث الفئة الفرعية: $e',
      };
    }
  }

  /// Delete subcategory
  Future<bool> deleteSubcategory(String subcategoryId) async {
    try {
      return await _withRetry((db) async {
        await db.delete(
          'subcategories',
          where: 'id = ?',
          whereArgs: [subcategoryId],
        );
        return true;
      }, 'deleteSubcategory');
    } catch (e) {
      developer.log('Delete subcategory error: $e', name: 'LocalRepository');
      return false;
    }
  }

  // ==================== Lecture Management ====================

  /// Add lecture
  Future<Map<String, dynamic>> addLecture({
    required String title,
    required String description,
    String? videoPath,
    required String section,
    String? categoryId,
    String? categoryName,
    String? subcategoryId,
    String? subcategoryName,
  }) async {
    try {
      return await _withRetry((db) async {
        final lectureId = generateUUID();
        final now = nowMillis();

        // Normalize section to canonical key
        final normalizedSection = _normalizeSectionKey(section);

        // If subcategoryId is provided but categoryId is not, try to get it from subcategory
        String? resolvedCategoryId = categoryId;
        String? resolvedCategoryName = categoryName;
        if (subcategoryId != null &&
            subcategoryId.isNotEmpty &&
            (categoryId == null || categoryId.isEmpty)) {
          final subcat = await db.query(
            'subcategories',
            where: 'id = ?',
            whereArgs: [subcategoryId],
            limit: 1,
          );
          if (subcat.isNotEmpty) {
            resolvedCategoryId = subcat.first['category_id']?.toString();
            if (resolvedCategoryId != null && resolvedCategoryId.isNotEmpty) {
              // Get category name
              final cat = await db.query(
                'categories',
                where: 'id = ? AND isDeleted = ?',
                whereArgs: [resolvedCategoryId, 0],
                limit: 1,
              );
              if (cat.isNotEmpty) {
                resolvedCategoryName = cat.first['name']?.toString();
              }
            }
          }
        }

        // Log the values being persisted for diagnostics
        developer.log(
          '[LocalRepository] Adding lecture: section=$normalizedSection (original=$section), categoryId=$resolvedCategoryId, subcategoryId=$subcategoryId, isPublished=1, status=published',
          name: 'addLecture',
        );

        await db.insert('lectures', {
          'id': lectureId,
          'title': title,
          'description': description ?? '',
          'video_path': videoPath ?? '',
          'section': normalizedSection,
          'categoryId': resolvedCategoryId ?? '',
          'categoryName': resolvedCategoryName ?? '',
          'subcategory_id': subcategoryId ?? '',
          'subcategoryName': subcategoryName ?? '',
          'status': 'published',
          'isPublished': 1,
          'isDeleted': 0,
          'createdAt': now,
          'updatedAt': now,
        });

        // Log for diagnostics
        developer.log(
          '[LocalRepository] Added lecture: id=$lectureId, section=$normalizedSection, categoryId=$resolvedCategoryId, subcategoryId=$subcategoryId, isPublished=1, status=published, isDeleted=0',
          name: 'addLecture',
        );

        return {
          'success': true,
          'message': 'تم إضافة المحاضرة بنجاح',
          'lecture_id': lectureId,
        };
      }, 'addLecture');
    } catch (e) {
      developer.log('Add lecture error: $e', name: 'LocalRepository');
      return {'success': false, 'message': 'حدث خطأ أثناء إضافة المحاضرة: $e'};
    }
  }

  /// Get all lectures (only published and not deleted)
  /// Filters: isDeleted=0 AND isPublished=1
  Future<List<Map<String, dynamic>>> getAllLectures() async {
    try {
      return await _withRetry((db) async {
        final results = await db.query(
          'lectures',
          where: 'isDeleted = ? AND isPublished = ?',
          whereArgs: [0, 1],
          orderBy: 'createdAt DESC',
        );

        return results.map((row) {
          final lecture = Map<String, dynamic>.from(row);
          // Ensure all string fields have defaults
          lecture['title'] = lecture['title']?.toString() ?? '';
          lecture['description'] = lecture['description']?.toString() ?? '';
          lecture['video_path'] = lecture['video_path']?.toString() ?? '';
          lecture['section'] = lecture['section']?.toString() ?? 'unknown';
          lecture['categoryName'] = lecture['categoryName']?.toString() ?? '';
          lecture['subcategoryName'] =
              lecture['subcategoryName']?.toString() ?? '';
          lecture['sheikhName'] = lecture['sheikhName']?.toString() ?? '';
          lecture['isPublished'] = (lecture['isPublished'] as int) == 1;

          // Deserialize location JSON if present
          lecture['location'] = _deserializeLocation(lecture['location']);

          return lecture;
        }).toList();
      }, 'getAllLectures');
    } catch (e) {
      developer.log('Get all lectures error: $e', name: 'LocalRepository');
      return [];
    }
  }

  /// Get lectures by section (only published and not deleted)
  /// Accepts both canonical keys (fiqh) and Arabic names (الفقه)
  Future<List<Map<String, dynamic>>> getLecturesBySection(
    String section,
  ) async {
    try {
      return await _withRetry((db) async {
        // Normalize section to canonical key for query
        final normalizedSection = _normalizeSectionKey(section);

        final results = await db.query(
          'lectures',
          where: 'section = ? AND isDeleted = ? AND isPublished = ?',
          whereArgs: [normalizedSection, 0, 1],
          orderBy: 'startTime DESC, createdAt DESC',
        );

        return results.map((row) {
          final lecture = Map<String, dynamic>.from(row);
          // Ensure all string fields have defaults
          lecture['title'] = lecture['title']?.toString() ?? '';
          lecture['description'] = lecture['description']?.toString() ?? '';
          lecture['video_path'] = lecture['video_path']?.toString() ?? '';
          lecture['section'] = lecture['section']?.toString() ?? 'unknown';
          lecture['categoryName'] = lecture['categoryName']?.toString() ?? '';
          lecture['subcategoryName'] =
              lecture['subcategoryName']?.toString() ?? '';
          lecture['sheikhName'] = lecture['sheikhName']?.toString() ?? '';
          lecture['isPublished'] = (lecture['isPublished'] as int) == 1;

          // Deserialize location JSON if present
          lecture['location'] = _deserializeLocation(lecture['location']);

          return lecture;
        }).toList();
      }, 'getLecturesBySection');
    } catch (e) {
      developer.log(
        'Get lectures by section error: $e',
        name: 'LocalRepository',
      );
      return [];
    }
  }

  /// Get full home hierarchy: Section → Category → Subcategory → Lectures
  /// Returns structure: {section: {categories: [{category: {...}, subcategories: [{subcategory: {...}, lectures: [...]}]}], uncategorizedLectures: [...]}}
  /// Only includes published, non-deleted lectures
  Future<Map<String, dynamic>> getHomeHierarchy() async {
    try {
      return await _withRetry((db) async {
        final startTime = DateTime.now().millisecondsSinceEpoch;
        final hierarchy = <String, dynamic>{};
        final sections = ['fiqh', 'hadith', 'tafsir', 'seerah'];

        for (final section in sections) {
          // Get categories for this section
          final categories = await db.query(
            'categories',
            where: 'section_id = ? AND isDeleted = ?',
            whereArgs: [section, 0],
            orderBy: 'sortOrder ASC, id ASC',
          );

          // Get subcategories for this section (will be grouped by category_id)
          final subcategories = await db.query(
            'subcategories',
            where: 'section = ?',
            whereArgs: [section],
            orderBy: 'created_at ASC',
          );

          // Get published, non-deleted lectures for this section
          final lectures = await db.query(
            'lectures',
            where: 'section = ? AND isDeleted = ? AND isPublished = ?',
            whereArgs: [section, 0, 1],
            orderBy: 'startTime DESC, createdAt DESC',
          );

          // DIAGNOSTIC: Log raw SQL query results
          developer.log(
            '[LocalRepository] getHomeHierarchy - Section $section: Found ${lectures.length} lectures, ${categories.length} categories, ${subcategories.length} subcategories',
            name: 'getHomeHierarchy',
          );

          // DIAGNOSTIC: Log sample lecture data to verify fields
          if (lectures.isNotEmpty) {
            final sampleLecture = lectures.first;
            developer.log(
              '[LocalRepository] Sample lecture: id=${sampleLecture['id']}, title=${sampleLecture['title']}, section=${sampleLecture['section']}, categoryId=${sampleLecture['categoryId']}, subcategory_id=${sampleLecture['subcategory_id']}, isPublished=${sampleLecture['isPublished']}, isDeleted=${sampleLecture['isDeleted']}',
              name: 'getHomeHierarchy',
            );
          }

          // Build category structure with subcategories and lectures
          final categoryList = <Map<String, dynamic>>[];
          final subcategoryMap = <String, List<Map<String, dynamic>>>{};

          // Group subcategories by category (if categoryId exists in lecture)
          for (final subcat in subcategories) {
            final subcatId = subcat['id'] as String?;
            if (subcatId == null) continue;

            // Find lectures for this subcategory
            final subcatLectures = lectures.where((lecture) {
              final lectureSubcatId = lecture['subcategory_id']?.toString();
              return lectureSubcatId == subcatId;
            }).toList();

            // Only include subcategory if it has lectures or if we want to show empty ones
            if (subcatLectures.isNotEmpty) {
              subcategoryMap[subcatId] = subcatLectures;
            }
          }

          // Build category structure using category_id from subcategories
          for (final category in categories) {
            final categoryId = category['id'] as String?;
            if (categoryId == null) continue;

            // Find subcategories that belong to this category (using category_id column)
            final categorySubcategories = <Map<String, dynamic>>[];
            final subcatsForCategory = subcategories.where((subcat) {
              final subcatCategoryId = subcat['category_id']?.toString();
              return subcatCategoryId == categoryId;
            }).toList();

            for (final subcat in subcatsForCategory) {
              final subcatId = subcat['id'] as String?;
              if (subcatId == null) continue;

              // Find lectures for this subcategory
              // Match by subcategory_id only - the subcategory already belongs to this category
              final subcatLectures = lectures.where((l) {
                final lectureSubcatId = l['subcategory_id']?.toString();
                return lectureSubcatId == subcatId;
              }).toList();

              // Null-safe mapping
              final mappedLectures = subcatLectures.map((l) {
                final lecture = Map<String, dynamic>.from(l);
                lecture['title'] = lecture['title']?.toString() ?? '';
                lecture['description'] =
                    lecture['description']?.toString() ?? '';
                lecture['video_path'] = lecture['video_path']?.toString() ?? '';
                lecture['section'] =
                    lecture['section']?.toString() ?? 'unknown';
                lecture['categoryName'] =
                    lecture['categoryName']?.toString() ?? '';
                lecture['subcategoryName'] =
                    lecture['subcategoryName']?.toString() ?? '';
                lecture['sheikhName'] = lecture['sheikhName']?.toString() ?? '';
                lecture['isPublished'] = (lecture['isPublished'] as int) == 1;

                // Deserialize location JSON if present
                lecture['location'] = _deserializeLocation(lecture['location']);

                return lecture;
              }).toList();

              categorySubcategories.add({
                'subcategory': subcat,
                'lectures': mappedLectures,
              });
            }

            // Add category - show even if empty (for proper UI structure)
            // Always include category if it exists, even with no subcategories/lectures
            categoryList.add({
              'category': category,
              'subcategories': categorySubcategories,
            });
          }

          // Find uncategorized lectures (no categoryId or subcategory_id)
          final uncategorizedLectures = lectures
              .where((lecture) {
                final categoryId = lecture['categoryId']?.toString();
                final subcatId = lecture['subcategory_id']?.toString();
                return (categoryId == null || categoryId.isEmpty) &&
                    (subcatId == null || subcatId.isEmpty);
              })
              .map((l) {
                final lecture = Map<String, dynamic>.from(l);
                lecture['title'] = lecture['title']?.toString() ?? '';
                lecture['description'] =
                    lecture['description']?.toString() ?? '';
                lecture['video_path'] = lecture['video_path']?.toString() ?? '';
                lecture['section'] =
                    lecture['section']?.toString() ?? 'unknown';
                lecture['categoryName'] =
                    lecture['categoryName']?.toString() ?? '';
                lecture['subcategoryName'] =
                    lecture['subcategoryName']?.toString() ?? '';
                lecture['sheikhName'] = lecture['sheikhName']?.toString() ?? '';
                lecture['isPublished'] = (lecture['isPublished'] as int) == 1;

                // Deserialize location JSON if present
                lecture['location'] = _deserializeLocation(lecture['location']);

                return lecture;
              })
              .toList();

          // Build section data with proper structure for Home
          // Structure: {categories: [{category: {...}, subcategories: [{subcategory: {...}, lectures: [...]}]}], uncategorizedLectures: [...]}
          // NOTE: Do NOT include 'subcategories' at section level - UI must read via categories → subcategories
          final sectionData = <String, dynamic>{
            'categories': categoryList,
            'uncategorizedLectures': uncategorizedLectures,
          };

          hierarchy[section] = sectionData;
        }

        final loadTime = DateTime.now().millisecondsSinceEpoch - startTime;
        developer.log(
          '[LocalRepository] getHomeHierarchy: loaded in ${loadTime}ms',
          name: 'getHomeHierarchy',
        );

        // Log counts per section with detailed breakdown
        for (final section in sections) {
          final sectionData = hierarchy[section] as Map<String, dynamic>?;
          if (sectionData != null) {
            final categories = sectionData['categories'] as List? ?? [];
            final uncategorizedLectures =
                sectionData['uncategorizedLectures'] as List? ?? [];
            int totalLectures = uncategorizedLectures.length;
            int totalSubcategories = 0;
            for (final catData in categories) {
              final subcategories = catData['subcategories'] as List? ?? [];
              totalSubcategories += subcategories.length;
              for (final subcatData in subcategories) {
                final lectures = subcatData['lectures'] as List? ?? [];
                totalLectures += lectures.length;
              }
            }

            // Check for orphaned subcategories (missing category_id)
            final allSubcats = await db.query(
              'subcategories',
              where: 'section = ?',
              whereArgs: [section],
            );
            final orphanedSubcats = allSubcats.where((subcat) {
              final categoryId = subcat['category_id']?.toString();
              return categoryId == null || categoryId.isEmpty;
            }).toList();

            if (orphanedSubcats.isNotEmpty) {
              developer.log(
                '[LocalRepository] WARNING: Found ${orphanedSubcats.length} orphaned subcategories in section $section (missing category_id)',
                name: 'getHomeHierarchy',
              );
            }

            // DIAGNOSTIC: Log detailed breakdown per category
            for (final catData in categories) {
              final cat = catData['category'] as Map<String, dynamic>?;
              if (cat != null) {
                final catId = cat['id']?.toString() ?? 'unknown';
                final catName = cat['name']?.toString() ?? 'unknown';
                final subcats = catData['subcategories'] as List? ?? [];
                int catLectureCount = 0;
                for (final subcatData in subcats) {
                  final subcatLectures = subcatData['lectures'] as List? ?? [];
                  catLectureCount += subcatLectures.length;
                }
                developer.log(
                  '[LocalRepository] Category $catName (id=$catId): ${subcats.length} subcategories, $catLectureCount lectures',
                  name: 'getHomeHierarchy',
                );
              }
            }

            developer.log(
              '[LocalRepository] Section $section: ${categories.length} categories, $totalSubcategories subcategories, $totalLectures lectures${orphanedSubcats.isNotEmpty ? ", ${orphanedSubcats.length} orphaned" : ""}',
              name: 'getHomeHierarchy',
            );
          }
        }

        return hierarchy;
      }, 'getHomeHierarchy');
    } catch (e) {
      developer.log('Get home hierarchy error: $e', name: 'LocalRepository');
      return {};
    }
  }

  /// Get lectures by category (only published and not deleted)
  Future<List<Map<String, dynamic>>> getLecturesByCategory(
    String categoryId,
  ) async {
    try {
      return await _withRetry((db) async {
        final results = await db.query(
          'lectures',
          where: 'categoryId = ? AND isDeleted = ? AND isPublished = ?',
          whereArgs: [categoryId, 0, 1],
          orderBy: 'createdAt DESC',
        );

        return results.map((row) {
          final lecture = Map<String, dynamic>.from(row);
          // Ensure all string fields have defaults
          lecture['title'] = lecture['title']?.toString() ?? '';
          lecture['description'] = lecture['description']?.toString() ?? '';
          lecture['video_path'] = lecture['video_path']?.toString() ?? '';
          lecture['section'] = lecture['section']?.toString() ?? 'unknown';
          lecture['categoryName'] = lecture['categoryName']?.toString() ?? '';
          lecture['subcategoryName'] =
              lecture['subcategoryName']?.toString() ?? '';
          lecture['sheikhName'] = lecture['sheikhName']?.toString() ?? '';
          lecture['isPublished'] = (lecture['isPublished'] as int) == 1;

          // Deserialize location JSON if present
          lecture['location'] = _deserializeLocation(lecture['location']);

          return lecture;
        }).toList();
      }, 'getLecturesByCategory');
    } catch (e) {
      developer.log(
        'Get lectures by category error: $e',
        name: 'LocalRepository',
      );
      return [];
    }
  }

  /// Get lectures by subcategory (only published and not deleted)
  Future<List<Map<String, dynamic>>> getLecturesBySubcategory(
    String subcategoryId,
  ) async {
    try {
      return await _withRetry((db) async {
        final results = await db.query(
          'lectures',
          where: 'subcategory_id = ? AND isDeleted = ? AND isPublished = ?',
          whereArgs: [subcategoryId, 0, 1],
          orderBy: 'createdAt DESC',
        );

        return results.map((row) {
          final lecture = Map<String, dynamic>.from(row);
          // Ensure all string fields have defaults
          lecture['title'] = lecture['title']?.toString() ?? '';
          lecture['description'] = lecture['description']?.toString() ?? '';
          lecture['video_path'] = lecture['video_path']?.toString() ?? '';
          lecture['section'] = lecture['section']?.toString() ?? 'unknown';
          lecture['categoryName'] = lecture['categoryName']?.toString() ?? '';
          lecture['subcategoryName'] =
              lecture['subcategoryName']?.toString() ?? '';
          lecture['sheikhName'] = lecture['sheikhName']?.toString() ?? '';
          lecture['isPublished'] = (lecture['isPublished'] as int) == 1;

          // Deserialize location JSON if present
          lecture['location'] = _deserializeLocation(lecture['location']);

          return lecture;
        }).toList();
      }, 'getLecturesBySubcategory');
    } catch (e) {
      developer.log(
        'Get lectures by subcategory error: $e',
        name: 'LocalRepository',
      );
      return [];
    }
  }

  /// Get a single lecture
  Future<Map<String, dynamic>?> getLecture(String id) async {
    try {
      return await _withRetry((db) async {
        final results = await db.query(
          'lectures',
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );

        if (results.isEmpty) return null;

        final lecture = Map<String, dynamic>.from(results.first);
        lecture['isPublished'] = (lecture['isPublished'] as int) == 1;

        // Deserialize location JSON if present
        lecture['location'] = _deserializeLocation(lecture['location']);

        return lecture;
      }, 'getLecture');
    } catch (e) {
      developer.log('Get lecture error: $e', name: 'LocalRepository');
      return null;
    }
  }

  /// Update lecture
  Future<Map<String, dynamic>> updateLecture({
    required String id,
    required String title,
    required String description,
    String? videoPath,
    required String section,
    String? subcategoryId,
  }) async {
    try {
      return await _withRetry((db) async {
        final Map<String, dynamic> updateData = {
          'title': title,
          'description': description,
          'section': section,
          'updatedAt': nowMillis(),
        };

        if (videoPath != null) updateData['video_path'] = videoPath;
        if (subcategoryId != null) updateData['subcategory_id'] = subcategoryId;

        await db.update(
          'lectures',
          updateData,
          where: 'id = ?',
          whereArgs: [id],
        );

        return {'success': true, 'message': 'تم تحديث المحاضرة بنجاح'};
      }, 'updateLecture');
    } catch (e) {
      developer.log('Update lecture error: $e', name: 'LocalRepository');
      return {'success': false, 'message': 'حدث خطأ أثناء تحديث المحاضرة: $e'};
    }
  }

  /// Delete lecture (soft delete - set status to 'deleted')
  Future<bool> deleteLecture(String lectureId) async {
    try {
      return await _withRetry((db) async {
        await db.update(
          'lectures',
          {'status': 'deleted', 'updatedAt': nowMillis()},
          where: 'id = ?',
          whereArgs: [lectureId],
        );
        return true;
      }, 'deleteLecture');
    } catch (e) {
      developer.log('Delete lecture error: $e', name: 'LocalRepository');
      return false;
    }
  }

  /// Search lectures
  Future<List<Map<String, dynamic>>> searchLectures(String query) async {
    try {
      final fts5Available = await _dbService.isFts5Available();
      return await _withRetry((db) async {
        List<Map<String, dynamic>> results;

        if (fts5Available) {
          // Use FTS5 MATCH for full-text search (better performance)
          try {
            // Escape query for FTS5 (basic escaping - wrap in quotes and escape quotes)
            final escapedQuery = query.replaceAll("'", "''");
            final ftsQuery = "'$escapedQuery'";
            // FTS5 MATCH query: join lectures_fts with lectures using rowid
            results = await db.rawQuery('''
              SELECT l.* FROM lectures l
              JOIN lectures_fts fts ON l.rowid = fts.rowid
              WHERE fts MATCH $ftsQuery
                AND l.isDeleted = 0 AND l.isPublished = 1
              ORDER BY l.createdAt DESC
            ''', []);
            developer.log('Using FTS5 search', name: 'LocalRepository');
          } catch (e) {
            developer.log(
              'FTS5 search failed, falling back to LIKE: $e',
              name: 'LocalRepository',
            );
            // Fall back to LIKE if FTS5 query fails
            final searchPattern = '%$query%';
            results = await db.query(
              'lectures',
              where:
                  '(title LIKE ? OR description LIKE ?) AND isDeleted = ? AND isPublished = ?',
              whereArgs: [searchPattern, searchPattern, 0, 1],
              orderBy: 'createdAt DESC',
            );
          }
        } else {
          // Use LIKE search (fallback when FTS5 not available)
          final searchPattern = '%$query%';
          results = await db.query(
            'lectures',
            where:
                '(title LIKE ? OR description LIKE ?) AND status NOT IN (?, ?)',
            whereArgs: [searchPattern, searchPattern, 'archived', 'deleted'],
            orderBy: 'createdAt DESC',
          );
          developer.log(
            'Using LIKE search (FTS5 not available)',
            name: 'LocalRepository',
          );
        }

        return results.map((row) {
          final lecture = Map<String, dynamic>.from(row);
          lecture['isPublished'] = (lecture['isPublished'] as int) == 1;
          return lecture;
        }).toList();
      }, 'searchLectures');
    } catch (e) {
      developer.log('Search lectures error: $e', name: 'LocalRepository');
      return [];
    }
  }

  // ==================== Categories Management ====================

  /// Get categories by section (only non-deleted)
  Future<List<Map<String, dynamic>>> getCategoriesBySection(
    String section,
  ) async {
    try {
      return await _withRetry((db) async {
        // Normalize section to canonical key
        final normalizedSection = _normalizeSectionKey(section);

        final results = await db.query(
          'categories',
          where: 'section_id = ? AND isDeleted = ?',
          whereArgs: [normalizedSection, 0],
          orderBy: 'sortOrder ASC, id ASC',
        );

        // Log for diagnostics
        developer.log(
          '[LocalRepository] getCategoriesBySection: section=$normalizedSection, found ${results.length} categories',
          name: 'getCategoriesBySection',
        );

        return results;
      }, 'getCategoriesBySection');
    } catch (e) {
      developer.log(
        'Get categories by section error: $e',
        name: 'LocalRepository',
      );
      return [];
    }
  }

  /// Add a new category
  Future<Map<String, dynamic>> addCategory({
    required String sectionId,
    required String name,
    String? description,
    int order = 0,
  }) async {
    try {
      return await _withRetry((db) async {
        // Normalize inputs
        final normalizedName = (name ?? '').trim();
        if (normalizedName.isEmpty) {
          throw Exception('Category name cannot be empty');
        }

        final normalizedSection = _normalizeSectionKey(sectionId);
        final normalizedDesc = description?.trim();

        final categoryId = generateUUID();
        final now = nowMillis();

        // Log for diagnostics
        final dbPath = await _dbService.getDatabasePath();
        developer.log(
          '[LocalRepository] addCategory: section=$normalizedSection, name=$normalizedName, dbPath=$dbPath',
          name: 'addCategory',
        );

        await db.insert('categories', {
          'id': categoryId,
          'section_id': normalizedSection,
          'name': normalizedName,
          'description': normalizedDesc,
          'sortOrder': order,
          'isDeleted': 0,
          'createdAt': now,
          'updatedAt': now,
        });

        // Log row count after insert
        final countResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM categories WHERE section_id = ? AND isDeleted = 0',
          [normalizedSection],
        );
        final count = Sqflite.firstIntValue(countResult) ?? 0;
        developer.log(
          '[LocalRepository] Categories count for section $normalizedSection: $count',
          name: 'addCategory',
        );

        return {
          'success': true,
          'message': 'تم إضافة الفئة بنجاح',
          'category_id': categoryId,
        };
      }, 'addCategory');
    } catch (e) {
      developer.log('Add category error: $e', name: 'LocalRepository');
      return {'success': false, 'message': 'حدث خطأ أثناء إضافة الفئة: $e'};
    }
  }

  /// Update category
  Future<Map<String, dynamic>> updateCategory({
    required String categoryId,
    String? name,
    String? description,
    int? order,
  }) async {
    try {
      return await _withRetry((db) async {
        final updates = <String, dynamic>{'updatedAt': nowMillis()};

        if (name != null) {
          final normalizedName = (name ?? '').trim();
          if (normalizedName.isEmpty) {
            throw Exception('Category name cannot be empty');
          }
          updates['name'] = normalizedName;
        }

        if (description != null) {
          updates['description'] = (description ?? '').trim();
        }

        if (order != null) {
          updates['sortOrder'] = order;
        }

        final rowsAffected = await db.update(
          'categories',
          updates,
          where: 'id = ? AND isDeleted = 0',
          whereArgs: [categoryId],
        );

        if (rowsAffected == 0) {
          return {'success': false, 'message': 'الفئة غير موجودة أو تم حذفها'};
        }

        return {'success': true, 'message': 'تم تحديث الفئة بنجاح'};
      }, 'updateCategory');
    } catch (e) {
      developer.log('Update category error: $e', name: 'LocalRepository');
      return {'success': false, 'message': 'حدث خطأ أثناء تحديث الفئة: $e'};
    }
  }

  /// Delete category (soft delete)
  Future<Map<String, dynamic>> deleteCategory(String categoryId) async {
    try {
      return await _withRetry((db) async {
        final rowsAffected = await db.update(
          'categories',
          {'isDeleted': 1, 'updatedAt': nowMillis()},
          where: 'id = ? AND isDeleted = 0',
          whereArgs: [categoryId],
        );

        if (rowsAffected == 0) {
          return {
            'success': false,
            'message': 'الفئة غير موجودة أو تم حذفها مسبقاً',
          };
        }

        return {'success': true, 'message': 'تم حذف الفئة بنجاح'};
      }, 'deleteCategory');
    } catch (e) {
      developer.log('Delete category error: $e', name: 'LocalRepository');
      return {'success': false, 'message': 'حدث خطأ أثناء حذف الفئة: $e'};
    }
  }

  // ==================== Sheikh Lecture Management ====================

  /// Add sheikh lecture
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
    required int startTime,
    int? endTime,
    Map<String, dynamic>? location,
    Map<String, dynamic>? media,
  }) async {
    try {
      return await _withRetry((db) async {
        final lectureId = generateUUID();
        final now = nowMillis();

        // Extract video path and videoId from media if provided
        String? videoPath;
        String? videoId;
        if (media != null) {
          videoPath =
              media['videoPath']?.toString() ?? media['video_path']?.toString();
          videoId = media['videoId']?.toString();
          // Also extract from videoUrl if videoId not directly provided
          if ((videoId == null || videoId.isEmpty) &&
              videoPath != null &&
              videoPath.isNotEmpty) {
            // Try to extract from video_path if it's a YouTube URL
            videoId = YouTubeUtils.extractVideoId(videoPath);
          }
          // Also check videoUrl field
          if (videoId == null || videoId.isEmpty) {
            final videoUrl = media['videoUrl']?.toString();
            if (videoUrl != null && videoUrl.isNotEmpty) {
              videoId = YouTubeUtils.extractVideoId(videoUrl);
            }
          }
        }

        // Normalize section to canonical key (e.g., 'الفقه' -> 'fiqh')
        final normalizedSection = _normalizeSectionKey(section);

        // Serialize location to JSON if provided
        String? locationJson;
        if (location != null && location.isNotEmpty) {
          try {
            locationJson = jsonEncode(location);
            developer.log(
              '[LocalRepository] Serializing location: $locationJson',
              name: 'addSheikhLecture',
            );
          } catch (e) {
            developer.log(
              '[LocalRepository] Error serializing location: $e',
              name: 'addSheikhLecture',
            );
          }
        }

        // Log the values being persisted for diagnostics
        developer.log(
          '[LocalRepository] Adding lecture: section=$normalizedSection (original=$section), isPublished=1, status=published, location=${location != null ? "provided" : "null"}',
          name: 'addSheikhLecture',
        );

        await db.insert('lectures', {
          'id': lectureId,
          'title': title,
          'description': description ?? '',
          'video_path': videoPath ?? '',
          'videoId': videoId ?? '',
          'section': normalizedSection,
          'subcategory_id': subcategoryId ?? '',
          'sheikhId': sheikhId,
          'sheikhName': sheikhName,
          'categoryId': categoryId,
          'categoryName': categoryName,
          'subcategoryName': subcategoryName,
          'startTime': startTime,
          'endTime': endTime,
          'location': locationJson,
          'status': 'published',
          'isPublished': 1,
          'isDeleted': 0,
          'createdAt': now,
          'updatedAt': now,
        });

        // Log for diagnostics
        developer.log(
          '[LocalRepository] Added lecture: id=$lectureId, section=$normalizedSection, isPublished=1, status=published, isDeleted=0, categoryId=$categoryId',
          name: 'addSheikhLecture',
        );

        return {
          'success': true,
          'message': 'تم إضافة المحاضرة بنجاح',
          'lecture_id': lectureId,
        };
      }, 'addSheikhLecture');
    } catch (e) {
      developer.log('Add sheikh lecture error: $e', name: 'LocalRepository');
      return {'success': false, 'message': 'حدث خطأ أثناء إضافة المحاضرة: $e'};
    }
  }

  /// Normalize section key (helper method)
  String _normalizeSectionKey(String? section) {
    if (section == null || section.isEmpty) {
      return 'unknown';
    }

    // Map Arabic names to canonical keys
    switch (section.trim()) {
      case 'الفقه':
        return 'fiqh';
      case 'الحديث':
        return 'hadith';
      case 'السيرة':
        return 'seerah';
      case 'التفسير':
        return 'tafsir';
      // If already a canonical key, return as-is
      case 'fiqh':
      case 'hadith':
      case 'seerah':
      case 'tafsir':
        return section.trim();
      // Default: lowercase and return
      default:
        return section.trim().toLowerCase();
    }
  }

  /// Get lectures by sheikh
  Future<List<Map<String, dynamic>>> getLecturesBySheikh(
    String sheikhId,
  ) async {
    try {
      return await _withRetry((db) async {
        // Sheikh queries: show all non-deleted lectures (including archived)
        final results = await db.query(
          'lectures',
          where: 'sheikhId = ? AND isDeleted = ?',
          whereArgs: [sheikhId, 0],
          orderBy: 'startTime DESC',
        );

        return results.map((row) {
          final lecture = Map<String, dynamic>.from(row);
          lecture['isPublished'] = (lecture['isPublished'] as int) == 1;
          return lecture;
        }).toList();
      }, 'getLecturesBySheikh');
    } catch (e) {
      developer.log(
        'Get lectures by sheikh error: $e',
        name: 'LocalRepository',
      );
      return [];
    }
  }

  /// Get lectures by sheikh and category
  Future<List<Map<String, dynamic>>> getLecturesBySheikhAndCategory(
    String sheikhId,
    String categoryId,
  ) async {
    try {
      return await _withRetry((db) async {
        final results = await db.query(
          'lectures',
          where: 'sheikhId = ? AND categoryId = ? AND isDeleted = ?',
          whereArgs: [sheikhId, categoryId, 0],
          orderBy: 'startTime DESC',
        );

        return results.map((row) {
          final lecture = Map<String, dynamic>.from(row);
          lecture['isPublished'] = (lecture['isPublished'] as int) == 1;

          // Deserialize location JSON if present
          lecture['location'] = _deserializeLocation(lecture['location']);

          return lecture;
        }).toList();
      }, 'getLecturesBySheikhAndCategory');
    } catch (e) {
      developer.log(
        'Get lectures by sheikh and category error: $e',
        name: 'LocalRepository',
      );
      return [];
    }
  }

  /// Update sheikh lecture
  Future<Map<String, dynamic>> updateSheikhLecture({
    required String lectureId,
    required String sheikhId,
    required String title,
    String? description,
    required int startTime,
    int? endTime,
    Map<String, dynamic>? location,
    Map<String, dynamic>? media,
  }) async {
    try {
      return await _withRetry((db) async {
        final Map<String, dynamic> updateData = {
          'title': title,
          'startTime': startTime,
          'updatedAt': nowMillis(),
        };

        if (description != null) updateData['description'] = description;
        if (endTime != null) updateData['endTime'] = endTime;

        // Update location if provided
        if (location != null) {
          try {
            final locationJson = jsonEncode(location);
            updateData['location'] = locationJson;
            developer.log(
              '[LocalRepository] Updating location: $locationJson',
              name: 'updateSheikhLecture',
            );
          } catch (e) {
            developer.log(
              '[LocalRepository] Error serializing location: $e',
              name: 'updateSheikhLecture',
            );
          }
        }

        // Update video URL and videoId from media if provided
        if (media != null) {
          // Extract videoUrl (preferred) or video_path (fallback)
          final videoUrl =
              media['videoUrl']?.toString() ??
              media['videoPath']?.toString() ??
              media['video_path']?.toString();

          // Extract videoId - prefer direct videoId, otherwise extract from URL
          String? videoId = media['videoId']?.toString();
          if ((videoId == null || videoId.isEmpty) &&
              videoUrl != null &&
              videoUrl.isNotEmpty) {
            videoId = YouTubeUtils.extractVideoId(videoUrl);
          }

          // Store both video_path (for backward compatibility) and videoId
          if (videoUrl != null && videoUrl.isNotEmpty) {
            updateData['video_path'] = videoUrl;
            if (videoId != null && videoId.isNotEmpty) {
              updateData['videoId'] = videoId;
            }
          } else {
            // If videoUrl is cleared, also clear videoId and video_path
            updateData['video_path'] = '';
            updateData['videoId'] = '';
          }
        }

        await db.update(
          'lectures',
          updateData,
          where: 'id = ? AND sheikhId = ?',
          whereArgs: [lectureId, sheikhId],
        );

        return {'success': true, 'message': 'تم تحديث المحاضرة بنجاح'};
      }, 'updateSheikhLecture');
    } catch (e) {
      developer.log('Update sheikh lecture error: $e', name: 'LocalRepository');
      return {'success': false, 'message': 'حدث خطأ أثناء تحديث المحاضرة: $e'};
    }
  }

  /// Archive sheikh lecture
  /// Sets status='archived', isPublished=0, isDeleted=0
  Future<Map<String, dynamic>> archiveSheikhLecture({
    required String lectureId,
    required String sheikhId,
  }) async {
    try {
      return await _withRetry((db) async {
        final now = nowMillis();
        await db.update(
          'lectures',
          {
            'status': 'archived',
            'isPublished': 0,
            'isDeleted': 0,
            'updatedAt': now,
          },
          where: 'id = ? AND sheikhId = ?',
          whereArgs: [lectureId, sheikhId],
        );

        // Log for diagnostics
        developer.log(
          '[LocalRepository] Archived lecture: id=$lectureId, status=archived, isPublished=0, isDeleted=0',
          name: 'archiveSheikhLecture',
        );

        return {'success': true, 'message': 'تم أرشفة المحاضرة بنجاح'};
      }, 'archiveSheikhLecture');
    } catch (e) {
      developer.log(
        'Archive sheikh lecture error: $e',
        name: 'LocalRepository',
      );
      return {'success': false, 'message': 'حدث خطأ أثناء أرشفة المحاضرة: $e'};
    }
  }

  /// Delete sheikh lecture (permanent delete)
  /// Sets isDeleted=1
  Future<Map<String, dynamic>> deleteSheikhLecture({
    required String lectureId,
    required String sheikhId,
  }) async {
    try {
      return await _withRetry((db) async {
        final now = nowMillis();
        await db.update(
          'lectures',
          {'isDeleted': 1, 'status': 'deleted', 'updatedAt': now},
          where: 'id = ? AND sheikhId = ?',
          whereArgs: [lectureId, sheikhId],
        );

        // Log for diagnostics
        developer.log(
          '[LocalRepository] Deleted lecture: id=$lectureId, isDeleted=1',
          name: 'deleteSheikhLecture',
        );

        return {'success': true, 'message': 'تم حذف المحاضرة بنجاح'};
      }, 'deleteSheikhLecture');
    } catch (e) {
      developer.log('Delete sheikh lecture error: $e', name: 'LocalRepository');
      return {'success': false, 'message': 'حدث خطأ أثناء حذف المحاضرة: $e'};
    }
  }

  /// Check for overlapping lectures
  /// Conflict exists ONLY when: sameSheikh AND sameCategory AND exact same timestamp
  /// The timestamp includes: year, month, day, hour, and minute (full datetime precision)
  /// This allows:
  /// - Same sheikh, different category, same datetime → ✅ Allowed
  /// - Different sheikh, same category, same datetime → ✅ Allowed
  /// - Same sheikh, same category, different date (same time) → ✅ Allowed
  /// - Same sheikh, same category, same date, different time → ✅ Allowed
  /// - Same sheikh, same category, exact same datetime → ❌ Blocked
  ///
  /// Note: startTime is in milliseconds since epoch, which includes full date-time precision
  Future<bool> hasOverlappingLectures({
    required String sheikhId,
    required String categoryId,
    required int startTime,
    int? endTime,
    String? excludeLectureId,
  }) async {
    try {
      return await _withRetry((db) async {
        // Conflict condition: same sheikh + same category + exact same startTime (timestamp)
        // This ensures full date-time precision: year, month, day, hour, minute are all matched
        // startTime is stored as milliseconds since epoch, which includes complete datetime info
        String whereClause =
            'sheikhId = ? AND categoryId = ? AND isDeleted = ? AND startTime = ?';

        List<dynamic> whereArgs = [
          sheikhId,
          categoryId,
          0,
          startTime, // Exact timestamp match (includes full date-time: year, month, day, hour, minute)
        ];

        if (excludeLectureId != null) {
          whereClause += ' AND id != ?';
          whereArgs.add(excludeLectureId);
        }

        final results = await db.query(
          'lectures',
          where: whereClause,
          whereArgs: whereArgs,
          limit: 1,
        );

        final hasConflict = results.isNotEmpty;

        // Convert timestamp to readable datetime for logging
        final conflictDateTime = DateTime.fromMillisecondsSinceEpoch(
          startTime,
          isUtc: true,
        );
        final dateTimeStr =
            '${conflictDateTime.year}-${conflictDateTime.month.toString().padLeft(2, '0')}-${conflictDateTime.day.toString().padLeft(2, '0')} ${conflictDateTime.hour.toString().padLeft(2, '0')}:${conflictDateTime.minute.toString().padLeft(2, '0')}';

        developer.log(
          '[LocalRepository] hasOverlappingLectures: sheikhId=$sheikhId, categoryId=$categoryId, startTime=$startTime ($dateTimeStr UTC), hasConflict=$hasConflict',
          name: 'hasOverlappingLectures',
        );

        return hasConflict;
      }, 'hasOverlappingLectures');
    } catch (e) {
      developer.log(
        'Has overlapping lectures error: $e',
        name: 'LocalRepository',
      );
      return false;
    }
  }

  /// Get sheikh lecture statistics
  Future<Map<String, dynamic>> getSheikhLectureStats(String sheikhId) async {
    try {
      return await _withRetry((db) async {
        // Total lectures (not deleted)
        final totalResults = await db.rawQuery(
          '''
          SELECT COUNT(*) as count FROM lectures
          WHERE sheikhId = ? AND isDeleted = 0
        ''',
          [sheikhId],
        );
        final totalLectures = Sqflite.firstIntValue(totalResults) ?? 0;

        // Upcoming today (startTime within today)
        final now = DateTime.now().toUtc();
        final todayStart = DateTime(now.year, now.month, now.day);
        final todayEnd = todayStart.add(const Duration(days: 1));
        final todayStartMillis = todayStart.millisecondsSinceEpoch;
        final todayEndMillis = todayEnd.millisecondsSinceEpoch;

        final upcomingResults = await db.rawQuery(
          '''
          SELECT COUNT(*) as count FROM lectures
          WHERE sheikhId = ? 
          AND isDeleted = 0
          AND startTime >= ? AND startTime < ?
        ''',
          [sheikhId, todayStartMillis, todayEndMillis],
        );
        final upcomingToday = Sqflite.firstIntValue(upcomingResults) ?? 0;

        // Last updated
        final lastUpdatedResults = await db.rawQuery(
          '''
          SELECT MAX(updatedAt) as lastUpdated FROM lectures
          WHERE sheikhId = ? AND isDeleted = 0
        ''',
          [sheikhId],
        );
        final lastUpdated = Sqflite.firstIntValue(lastUpdatedResults);

        return {
          'totalLectures': totalLectures,
          'upcomingToday': upcomingToday,
          'lastUpdated': lastUpdated,
        };
      }, 'getSheikhLectureStats');
    } catch (e) {
      developer.log('Get sheikh stats error: $e', name: 'LocalRepository');
      return {'totalLectures': 0, 'upcomingToday': 0, 'lastUpdated': null};
    }
  }

  /// Initialize default subcategories
  /// NOTE: This method is deprecated - subcategories should always have category_id
  /// This method will not create orphaned subcategories
  Future<void> initializeDefaultSubcategories() async {
    try {
      await _withRetry((db) async {
        // Check if subcategories already exist
        final existing = await db.query('subcategories', limit: 1);
        if (existing.isNotEmpty) {
          developer.log(
            '[LocalRepository] Subcategories already exist - skipping initialization',
            name: 'initializeDefaultSubcategories',
          );
          return;
        }

        developer.log(
          '[LocalRepository] Skipping default subcategory initialization - subcategories must be created with category_id',
          name: 'initializeDefaultSubcategories',
        );
        // Do not create orphaned subcategories without category_id
        // Subcategories should be created through the proper UI flow with category selection
      }, 'initializeDefaultSubcategories');
    } catch (e) {
      developer.log(
        '[LocalRepository] Initialize subcategories error: $e',
        name: 'initializeDefaultSubcategories',
      );
    }
  }

  /// Initialize default subcategories (if empty) - alias for compatibility
  Future<void> initializeDefaultSubcategoriesIfEmpty() async {
    return initializeDefaultSubcategories();
  }

  /// Ensure default admin account exists
  Future<void> ensureDefaultAdmin() async {
    try {
      await _withRetry((db) async {
        final adminCheck = await db.query(
          'users',
          where: 'is_admin = ?',
          whereArgs: [1],
          limit: 1,
        );

        if (adminCheck.isEmpty) {
          await createAdminAccount(
            username: 'admin',
            email: 'admin@admin.com',
            password: 'admin123',
          );
          developer.log(
            'Default admin account created',
            name: 'LocalRepository',
          );
        }
      }, 'ensureDefaultAdmin');
    } catch (e) {
      developer.log('Ensure default admin error: $e', name: 'LocalRepository');
    }
  }

  /// Get sheikh by uniqueId from sheikhs table only
  Future<Map<String, dynamic>?> getSheikhByUniqueId(String uniqueId) async {
    try {
      return await _withRetry((db) async {
        // Normalize uniqueId
        final uidInput = uniqueId.trim();
        if (uidInput.isEmpty) return null;

        final normalized = uidInput.replaceAll(RegExp(r'[^0-9]'), '');
        if (normalized.length != 8) return null;

        final sheikhResults = await db.query(
          'sheikhs',
          where: 'uniqueId = ? AND isDeleted = 0',
          whereArgs: [normalized],
          limit: 1,
        );

        if (sheikhResults.isNotEmpty) {
          final sheikh = Map<String, dynamic>.from(sheikhResults.first);
          // Map sheikh data to user-like format for compatibility
          return {
            'id': sheikh['id']?.toString() ?? normalized,
            'uid': sheikh['id']?.toString() ?? normalized,
            'uniqueId': sheikh['uniqueId'] as String? ?? normalized,
            'name': sheikh['name'] as String? ?? 'غير محدد',
            'email': sheikh['email'] as String?,
            'role': 'sheikh',
            'category': sheikh['category'] as String?,
            'phone': sheikh['phone'] as String?,
            'passwordHash': sheikh['passwordHash'] as String?,
          };
        }

        return null;
      }, 'getSheikhByUniqueId');
    } catch (e) {
      developer.log(
        'Get sheikh by uniqueId error: $e',
        name: 'LocalRepository',
      );
      return null;
    }
  }

  /// Login sheikh using uniqueId and password from sheikhs table only
  Future<Map<String, dynamic>> loginSheikh({
    required String uniqueId,
    required String password,
  }) async {
    try {
      return await _withRetry((db) async {
        // Normalize inputs
        final uidInput = uniqueId.trim();
        final pwdInput = password.trim();

        if (uidInput.isEmpty || pwdInput.isEmpty) {
          return {
            'success': false,
            'message': 'الرجاء إدخال رقم الشيخ وكلمة المرور',
          };
        }

        final normalized = uidInput.replaceAll(RegExp(r'[^0-9]'), '');
        if (normalized.length != 8) {
          return {
            'success': false,
            'message': 'رقم الشيخ يجب أن يكون 8 أرقام بالضبط',
          };
        }

        // Hash password
        final passwordHash = sha256Hex(pwdInput);

        // Query sheikhs table directly
        final results = await db.query(
          'sheikhs',
          where: 'uniqueId = ? AND passwordHash = ? AND isDeleted = 0',
          whereArgs: [normalized, passwordHash],
          limit: 1,
        );

        if (results.isEmpty) {
          return {
            'success': false,
            'message': 'رقم الشيخ أو كلمة المرور غير صحيحة',
          };
        }

        final sheikh = Map<String, dynamic>.from(results.first);
        return {
          'success': true,
          'message': 'تم تسجيل الدخول بنجاح',
          'sheikh': {
            'id': sheikh['id']?.toString() ?? normalized,
            'uid': sheikh['id']?.toString() ?? normalized,
            'uniqueId': sheikh['uniqueId'] as String? ?? normalized,
            'name': sheikh['name'] as String? ?? 'غير محدد',
            'email': sheikh['email'] as String?,
            'role': 'sheikh',
            'category': sheikh['category'] as String?,
            'phone': sheikh['phone'] as String?,
          },
        };
      }, 'loginSheikh');
    } catch (e) {
      developer.log('Login sheikh error: $e', name: 'LocalRepository');
      return {'success': false, 'message': 'حدث خطأ أثناء تسجيل الدخول: $e'};
    }
  }

  /// Get user by uniqueId - for backward compatibility (checks users table only)
  Future<Map<String, dynamic>?> getUserByUniqueId(
    String uniqueId, {
    String role = 'sheikh',
  }) async {
    // For sheikh role, delegate to getSheikhByUniqueId
    if (role == 'sheikh') {
      return await getSheikhByUniqueId(uniqueId);
    }

    // For other roles, check users table
    try {
      return await _withRetry((db) async {
        final userResults = await db.query(
          'users',
          where: 'uniqueId = ? AND role = ?',
          whereArgs: [uniqueId, role],
          limit: 1,
        );

        if (userResults.isNotEmpty) {
          final user = Map<String, dynamic>.from(userResults.first);
          user['is_admin'] = (user['is_admin'] as int) == 1;
          user['uid'] = user['id']; // Add uid for compatibility
          user.remove('password_hash');
          return user;
        }

        return null;
      }, 'getUserByUniqueId');
    } catch (e) {
      developer.log('Get user by uniqueId error: $e', name: 'LocalRepository');
      return null;
    }
  }

  /// Archive all lectures by a sheikh
  Future<void> archiveLecturesBySheikh(String sheikhId) async {
    try {
      await _withRetry((db) async {
        final now = nowMillis();
        await db.update(
          'lectures',
          {'status': 'archived', 'updatedAt': now},
          where: 'sheikhId = ?',
          whereArgs: [sheikhId],
        );
      }, 'archiveLecturesBySheikh');
    } catch (e) {
      developer.log(
        'Archive lectures by sheikh error: $e',
        name: 'LocalRepository',
      );
    }
  }

  /// Create a sheikh in the sheikhs table
  /// uniqueId must be TEXT and exactly 8 digits
  /// password is optional; if provided, passwordHash will be stored
  Future<Map<String, dynamic>> createSheikh({
    required String name,
    String? email,
    String? phone,
    String? uniqueId,
    String? category,
    String? password,
  }) async {
    try {
      return await _withRetry((db) async {
        // Normalize uniqueId input (null-safe)
        final uidInput = (uniqueId ?? '').trim();

        // Validate uniqueId: must be TEXT, exactly 8 digits
        if (uidInput.isEmpty) {
          return {'success': false, 'message': 'رقم الشيخ مطلوب'};
        }

        final normalized = uidInput.replaceAll(RegExp(r'[^0-9]'), '');
        if (normalized.isEmpty) {
          return {
            'success': false,
            'message': 'رقم الشيخ يجب أن يحتوي على أرقام فقط',
          };
        }
        if (normalized.length != 8) {
          return {
            'success': false,
            'message': 'رقم الشيخ يجب أن يكون 8 أرقام بالضبط',
          };
        }
        // Use normalized 8-digit value
        uniqueId = normalized;

        // Check uniqueId uniqueness
        final existing = await db.query(
          'sheikhs',
          where: 'uniqueId = ? AND isDeleted = 0',
          whereArgs: [uniqueId],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          return {'success': false, 'message': 'رقم الشيخ موجود مسبقاً'};
        }

        // Hash password if provided
        String? passwordHash;
        final pwdInput = (password ?? '').trim();
        if (pwdInput.isNotEmpty) {
          passwordHash = sha256Hex(pwdInput);
        }

        final now = DateTime.now().millisecondsSinceEpoch;
        final insertedId = await db.insert('sheikhs', {
          'uniqueId': uniqueId, // TEXT type - preserves leading zeros
          'name': name,
          'email': email,
          'phone': phone,
          'category': category,
          'passwordHash': passwordHash,
          'createdAt': now,
          'updatedAt': now,
          'isDeleted': 0,
        });

        return {
          'success': true,
          'id': insertedId,
          'message': 'تم إنشاء الشيخ بنجاح',
          'sheikhId': uniqueId,
        };
      }, 'createSheikh');
    } catch (e) {
      developer.log('Create sheikh error: $e', name: 'LocalRepository');
      return {'success': false, 'message': 'حدث خطأ أثناء إنشاء الشيخ: $e'};
    }
  }

  /// Count sheikhs
  Future<int> countSheikhs() async {
    try {
      return await _withRetry((db) async {
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM sheikhs WHERE isDeleted = 0',
        );
        return Sqflite.firstIntValue(result) ?? 0;
      }, 'countSheikhs');
    } catch (e) {
      developer.log('Count sheikhs error: $e', name: 'LocalRepository');
      return 0;
    }
  }

  /// Update user uniqueId and role (for sheikh accounts)
  Future<void> updateUserRoleAndUniqueId({
    required String userId,
    String? uniqueId,
    String? role,
    String? name,
  }) async {
    try {
      await _withRetry((db) async {
        final updates = <String, dynamic>{};
        // Normalize uniqueId input (null-safe)
        final uidInput = (uniqueId ?? '').trim();
        if (uidInput.isNotEmpty) {
          // Validate uniqueId: must be TEXT, exactly 8 digits
          final normalized = uidInput.replaceAll(RegExp(r'[^0-9]'), '');
          if (normalized.isNotEmpty && normalized.length == 8) {
            updates['uniqueId'] = normalized; // Use normalized value
          }
        }
        if (role != null) updates['role'] = role;
        if (name != null) updates['name'] = name;
        if (updates.isNotEmpty) {
          updates['updated_at'] = nowMillis();
          await db.update(
            'users',
            updates,
            where: 'id = ?',
            whereArgs: [userId],
          );
        }
      }, 'updateUserRoleAndUniqueId');
    } catch (e) {
      developer.log(
        'Update user role/uniqueId error: $e',
        name: 'LocalRepository',
      );
    }
  }

  /// Get all sheikhs (non-deleted only)
  Future<List<Map<String, dynamic>>> getAllSheikhs({
    String? search,
    String? category,
    int? limit,
  }) async {
    try {
      return await _withRetry((db) async {
        var query = 'SELECT * FROM sheikhs WHERE isDeleted = 0';
        final whereArgs = <dynamic>[];

        // Normalize category input (null-safe)
        final catInput = (category ?? '').trim();
        if (catInput.isNotEmpty) {
          query += ' AND category = ?';
          whereArgs.add(catInput);
        }

        // Normalize search input (null-safe)
        final searchInput = (search ?? '').trim();
        if (searchInput.isNotEmpty) {
          query += ' AND (name LIKE ? OR email LIKE ? OR uniqueId LIKE ?)';
          final searchTerm = '%$searchInput%';
          whereArgs.add(searchTerm);
          whereArgs.add(searchTerm);
          whereArgs.add(searchTerm);
        }

        query += ' ORDER BY createdAt DESC';

        if (limit != null && limit > 0) {
          query += ' LIMIT ?';
          whereArgs.add(limit);
        }

        final results = await db.rawQuery(query, whereArgs);
        return results.map((row) {
          final sheikh = Map<String, dynamic>.from(row);
          sheikh['sheikhId'] = sheikh['uniqueId']; // Alias for compatibility
          return sheikh;
        }).toList();
      }, 'getAllSheikhs');
    } catch (e) {
      developer.log('Get all sheikhs error: $e', name: 'LocalRepository');
      return [];
    }
  }

  /// Delete sheikh by uniqueId (soft delete) - returns rowsAffected
  Future<Map<String, dynamic>> deleteSheikhByUniqueId(String uniqueId) async {
    try {
      return await _withRetry((db) async {
        // Normalize uniqueId
        final uidInput = uniqueId.trim();
        if (uidInput.isEmpty) {
          return {
            'success': false,
            'message': 'رقم الشيخ مطلوب',
            'rowsAffected': 0,
          };
        }

        final normalized = uidInput.replaceAll(RegExp(r'[^0-9]'), '');
        if (normalized.length != 8) {
          return {
            'success': false,
            'message': 'رقم الشيخ يجب أن يكون 8 أرقام بالضبط',
            'rowsAffected': 0,
          };
        }

        // First, find the sheikh to get name
        final results = await db.query(
          'sheikhs',
          where: 'uniqueId = ? AND isDeleted = 0',
          whereArgs: [normalized],
          limit: 1,
        );

        if (results.isEmpty) {
          return {
            'success': false,
            'message': 'لم يتم العثور على شيخ بهذا الرقم',
            'rowsAffected': 0,
          };
        }

        final sheikh = results.first;
        final sheikhName = sheikh['name'] ?? 'غير محدد';
        final sheikhId = sheikh['id']?.toString();

        // Soft delete the sheikh - must affect exactly 1 row
        final now = DateTime.now().millisecondsSinceEpoch;
        final rowsAffected = await db.update(
          'sheikhs',
          {'isDeleted': 1, 'updatedAt': now},
          where: 'uniqueId = ? AND isDeleted = 0',
          whereArgs: [normalized],
        );

        // Verify exactly 1 row was affected
        if (rowsAffected != 1) {
          developer.log(
            'Delete sheikh: Expected 1 row affected, got $rowsAffected',
            name: 'LocalRepository',
          );
          return {
            'success': false,
            'message': 'فشل في حذف الشيخ: لم يتم العثور على سجل واحد فقط',
            'rowsAffected': rowsAffected,
          };
        }

        // Archive all lectures by this sheikh's id if we have it
        if (sheikhId != null) {
          try {
            await archiveLecturesBySheikh(sheikhId);
          } catch (e) {
            developer.log(
              'Error archiving lectures for sheikh: $e',
              name: 'LocalRepository',
            );
            // Continue even if archiving fails
          }
        }

        return {
          'success': true,
          'message': 'تم حذف الشيخ وجميع محاضراته بنجاح',
          'sheikhName': sheikhName,
          'rowsAffected': rowsAffected, // Should be exactly 1
        };
      }, 'deleteSheikhByUniqueId');
    } catch (e) {
      developer.log(
        'Delete sheikh by uniqueId error: $e',
        name: 'LocalRepository',
      );
      return {
        'success': false,
        'message': 'حدث خطأ أثناء حذف الشيخ: $e',
        'rowsAffected': 0,
      };
    }
  }

  /// Get table counts for logging
  Future<Map<String, int>> getTableCounts() async {
    try {
      return await _withRetry((db) async {
        final usersCount =
            Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM users'),
            ) ??
            0;
        final subcategoriesCount =
            Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM subcategories'),
            ) ??
            0;
        final lecturesCount =
            Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM lectures'),
            ) ??
            0;
        final sheikhsCount =
            Sqflite.firstIntValue(
              await db.rawQuery(
                'SELECT COUNT(*) FROM sheikhs WHERE isDeleted = 0',
              ),
            ) ??
            0;
        return {
          'users': usersCount,
          'subcategories': subcategoriesCount,
          'lectures': lecturesCount,
          'sheikhs': sheikhsCount,
        };
      }, 'getTableCounts');
    } catch (e) {
      developer.log('Get table counts error: $e', name: 'LocalRepository');
      return {'users': 0, 'subcategories': 0, 'lectures': 0, 'sheikhs': 0};
    }
  }
}
