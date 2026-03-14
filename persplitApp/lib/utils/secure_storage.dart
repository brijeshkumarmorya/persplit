import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  // Create storage instance with secure options
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Storage keys
  static const String _keyToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';

  // ============================================
  // TOKEN MANAGEMENT
  // ============================================

  /// Save authentication token
  static Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _keyToken, value: token);
    } catch (e) {
      print('[SECURE-STORAGE] Error saving token: $e');
      rethrow;
    }
  }

  /// Get authentication token
  static Future<String?> getToken() async {
    try {
      return await _storage.read(key: _keyToken);
    } catch (e) {
      print('[SECURE-STORAGE] Error reading token: $e');
      return null;
    }
  }

  /// Delete authentication token
  static Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _keyToken);
    } catch (e) {
      print('[SECURE-STORAGE] Error deleting token: $e');
      rethrow;
    }
  }

  /// Check if token exists
  static Future<bool> hasToken() async {
    try {
      final token = await _storage.read(key: _keyToken);
      return token != null && token.isNotEmpty;
    } catch (e) {
      print('[SECURE-STORAGE] Error checking token: $e');
      return false;
    }
  }

  // ============================================
  // USER DATA MANAGEMENT
  // ============================================

  /// Save user ID
  static Future<void> saveUserId(String userId) async {
    try {
      await _storage.write(key: _keyUserId, value: userId);
    } catch (e) {
      print('[SECURE-STORAGE] Error saving user ID: $e');
      rethrow;
    }
  }

  /// Get user ID
  static Future<String?> getUserId() async {
    try {
      return await _storage.read(key: _keyUserId);
    } catch (e) {
      print('[SECURE-STORAGE] Error reading user ID: $e');
      return null;
    }
  }

  /// Save user name
  static Future<void> saveUserName(String userName) async {
    try {
      await _storage.write(key: _keyUserName, value: userName);
    } catch (e) {
      print('[SECURE-STORAGE] Error saving user name: $e');
      rethrow;
    }
  }

  /// Get user name
  static Future<String?> getUserName() async {
    try {
      return await _storage.read(key: _keyUserName);
    } catch (e) {
      print('[SECURE-STORAGE] Error reading user name: $e');
      return null;
    }
  }

  /// Save user email
  static Future<void> saveUserEmail(String userEmail) async {
    try {
      await _storage.write(key: _keyUserEmail, value: userEmail);
    } catch (e) {
      print('[SECURE-STORAGE] Error saving user email: $e');
      rethrow;
    }
  }

  /// Get user email
  static Future<String?> getUserEmail() async {
    try {
      return await _storage.read(key: _keyUserEmail);
    } catch (e) {
      print('[SECURE-STORAGE] Error reading user email: $e');
      return null;
    }
  }

  // ============================================
  // COMPLETE USER DATA
  // ============================================

  /// Save complete user data (called after login)
  static Future<void> saveUserData({
    required String token,
    required String userId,
    String? userName,
    String? userEmail,
  }) async {
    try {
      await saveToken(token);
      await saveUserId(userId);
      if (userName != null) await saveUserName(userName);
      if (userEmail != null) await saveUserEmail(userEmail);
    } catch (e) {
      print('[SECURE-STORAGE] Error saving user data: $e');
      rethrow;
    }
  }

  /// Get complete user data
  static Future<Map<String, String?>> getUserData() async {
    try {
      final token = await getToken();
      final userId = await getUserId();
      final userName = await getUserName();
      final userEmail = await getUserEmail();

      return {
        'token': token,
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
      };
    } catch (e) {
      print('[SECURE-STORAGE] Error reading user data: $e');
      return {
        'token': null,
        'userId': null,
        'userName': null,
        'userEmail': null,
      };
    }
  }

  // ============================================
  // LOGOUT / CLEAR ALL DATA
  // ============================================

  /// Clear all stored data (called on logout)
  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      print('[SECURE-STORAGE] Error clearing all data: $e');
      rethrow;
    }
  }

  /// Delete specific user data (keeps token)
  static Future<void> clearUserData() async {
    try {
      await _storage.delete(key: _keyUserId);
      await _storage.delete(key: _keyUserName);
      await _storage.delete(key: _keyUserEmail);
    } catch (e) {
      print('[SECURE-STORAGE] Error clearing user data: $e');
      rethrow;
    }
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  /// Check if user is logged in (has valid token and userId)
  static Future<bool> isLoggedIn() async {
    try {
      final token = await getToken();
      final userId = await getUserId();
      return token != null &&
          token.isNotEmpty &&
          userId != null &&
          userId.isNotEmpty;
    } catch (e) {
      print('[SECURE-STORAGE] Error checking login status: $e');
      return false;
    }
  }

  /// Print all stored values (DEBUG ONLY - remove in production)
  static Future<void> debugPrintAll() async {
    try {
      final all = await _storage.readAll();
      print('[SECURE-STORAGE] All stored values:');
      all.forEach((key, value) {
        // Mask token for security
        if (key == _keyToken) {
          print('  $key: ${value.substring(0, 10)}...[MASKED]');
        } else {
          print('  $key: $value');
        }
      });
    } catch (e) {
      print('[SECURE-STORAGE] Error reading all values: $e');
    }
  }
}
