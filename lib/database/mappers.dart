import 'package:new_project/offline/firestore_shims.dart';

/// Mapper functions to convert data structures
/// Works with both Firestore Timestamp shims and integer timestamps

/// Convert timestamp (Timestamp or int) to milliseconds
int? _timestampToMillis(dynamic timestamp) {
  if (timestamp == null) return null;
  if (timestamp is int) return timestamp;
  if (timestamp is Timestamp) {
    return timestamp.millisecondsSinceEpoch;
  }
  if (timestamp is DateTime) {
    return timestamp.millisecondsSinceEpoch;
  }
  return null;
}

/// Convert Firestore user document to SQLite row
Map<String, dynamic> userDocToRow(String id, Map<String, dynamic> docData) {
  final timestamp = docData['created_at'];
  final updatedTimestamp = docData['updated_at'];

  return {
    'id': id,
    'username': docData['username']?.toString(),
    'email': docData['email']?.toString(),
    'is_admin': (docData['is_admin'] == true) ? 1 : 0,
    'name': docData['name']?.toString(),
    'gender': docData['gender']?.toString(),
    'birth_date': docData['birth_date']?.toString(),
    'profile_image_url': docData['profile_image_url']?.toString(),
    'updated_at': _timestampToMillis(updatedTimestamp),
    'created_at': _timestampToMillis(timestamp),
  };
}

/// Convert Firestore subcategory document to SQLite row
Map<String, dynamic> subcatDocToRow(String id, Map<String, dynamic> docData) {
  final timestamp = docData['created_at'];

  return {
    'id': id,
    'name': docData['name']?.toString(),
    'section': docData['section']?.toString(),
    'description': docData['description']?.toString(),
    'icon_name': docData['icon_name']?.toString(),
    'created_at': _timestampToMillis(timestamp),
  };
}

/// Convert Firestore lecture document to SQLite row
Map<String, dynamic> lectureDocToRow(String id, Map<String, dynamic> docData) {
  final createdTimestamp = docData['createdAt'] ?? docData['created_at'];
  final updatedTimestamp = docData['updatedAt'] ?? docData['updated_at'];
  final startTime = docData['startTime'];
  final endTime = docData['endTime'];

  // Map video_path with fallback
  final videoPath =
      docData['video_path'] ??
      docData['media']?['videoPath'] ??
      docData['videoPath'];

  // Normalize section key if it's Arabic
  String? section = docData['section']?.toString();
  if (section != null) {
    switch (section.trim()) {
      case 'الفقه':
        section = 'fiqh';
        break;
      case 'الحديث':
        section = 'hadith';
        break;
      case 'السيرة':
        section = 'seerah';
        break;
      case 'التفسير':
        section = 'tafsir';
        break;
      default:
        section = section.trim().toLowerCase();
    }
  }

  return {
    'id': id,
    'title': docData['title']?.toString() ?? '',
    'description': docData['description']?.toString() ?? '',
    'video_path': videoPath?.toString() ?? '',
    'section': section ?? 'unknown',
    'subcategory_id':
        docData['subcategoryId']?.toString() ??
        docData['subcategory_id']?.toString() ??
        '',
    'categoryId': docData['categoryId']?.toString() ?? '',
    'categoryName': docData['categoryName']?.toString() ?? '',
    'subcategoryName': docData['subcategoryName']?.toString() ?? '',
    'sheikhId': docData['sheikhId']?.toString() ?? '',
    'sheikhName': docData['sheikhName']?.toString() ?? '',
    'startTime': _timestampToMillis(startTime),
    'endTime': _timestampToMillis(endTime),
    'status': docData['status']?.toString() ?? 'draft',
    'isPublished': (docData['isPublished'] == true) ? 1 : 0,
    'isDeleted': (docData['isDeleted'] == true || docData['deletedAt'] != null)
        ? 1
        : 0,
    'created_at': _timestampToMillis(createdTimestamp) ?? 0,
    'updated_at': _timestampToMillis(updatedTimestamp) ?? 0,
    'archivedAt': _timestampToMillis(docData['archivedAt']),
    'deletedAt': _timestampToMillis(docData['deletedAt']),
  };
}
