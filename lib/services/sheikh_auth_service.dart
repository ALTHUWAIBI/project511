import 'package:new_project/repository/local_repository.dart';

/// SheikhAuthService - Local SQLite implementation
/// Authenticates Sheikh using uniqueId and password
class SheikhAuthService {
  final LocalRepository _repository = LocalRepository();

  /// Authenticate Sheikh using ONLY sheikhId and password
  /// Uses sheikhs table directly via loginSheikh
  Future<Map<String, dynamic>> authenticateSheikh(
    String sheikhId,
    String password,
  ) async {
    try {
      // Delegate to repository's loginSheikh which queries sheikhs table directly
      return await _repository.loginSheikh(
        uniqueId: sheikhId,
        password: password,
      );
    } catch (e) {
      print('[SheikhAuthService] Error during authentication: $e');
      return {'success': false, 'message': 'حدث خطأ أثناء تسجيل الدخول'};
    }
  }

  /// Validate input format
  String? getErrorMessage(String sheikhId, String password) {
    if (sheikhId.trim().isEmpty || password.trim().isEmpty) {
      return 'الرجاء إدخال رقم الشيخ وكلمة المرور';
    }

    final normalized = sheikhId.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) {
      return 'رقم الشيخ غير صحيح';
    }

    if (normalized.length != 8) {
      return 'رقم الشيخ يجب أن يكون 8 أرقام بالضبط';
    }

    return null;
  }

  /// Legacy method for backward compatibility
  Future<bool> validateSheikh(String sheikhId, String password) async {
    final result = await authenticateSheikh(sheikhId, password);
    return result['success'] == true;
  }

  /// Legacy method for backward compatibility
  Future<Map<String, dynamic>> validateSheikhDetailed(
    String sheikhId,
    String password,
  ) async {
    return await authenticateSheikh(sheikhId, password);
  }

  /// Normalize sheikhId to 8-digit string (enforces exactly 8 digits)
  String normalizeSheikhId(String sheikhId) {
    final normalized = sheikhId.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) return '';

    // Enforce exactly 8 digits - no padding, must be exactly 8 digits
    if (normalized.length != 8) {
      return ''; // Return empty string for invalid length
    }

    return normalized; // Return as-is since it's exactly 8 digits
  }
}
