import '../utils/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const String _baseUrl = '$baseUrl/auth';
  static const String _userBaseUrl = '$baseUrl/users';
  static const _secureStorage = FlutterSecureStorage();

  // ✅ Stream controller for auth state changes (used by GoRouter)
  static final _authStateController = StreamController<bool>.broadcast();

  /// Stream for listening to auth state changes (GoRouter integration)
  static Stream<void> authStatusStream() {
    return _authStateController.stream.map((_) => null);
  }

  /// Notify listeners of auth state change
  static void _notifyAuthChange(bool isLoggedIn) {
    if (!_authStateController.isClosed) {
      _authStateController.add(isLoggedIn);
    }
  }

  /// ========================
  /// REGISTER
  /// ========================
  static Future<Map<String, dynamic>> register({
    required String name,
    required String username,
    required String email,
    required String password,
    String? upiId,
  }) async {
    try {
      print('🔵 REGISTER: Starting registration...');
      print('Request URL: $_baseUrl/register');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/register'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'name': name,
              'username': username,
              'email': email,
              'password': password,
              'upiId': upiId ?? '',
            }),
          )
          .timeout(const Duration(seconds: 15));

      print('Response Status: ${response.statusCode}');

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ Registration successful');
        return {
          'success': true,
          'message': data['message'] ?? 'Registration successful',
        };
      } else if (response.statusCode == 409) {
        return {
          'success': false,
          'message': 'Email or username already exists',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      print('❌ REGISTER ERROR: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// ========================
  /// LOGIN - SAVE BOTH TOKENS
  /// ========================
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      print('\n✅ [LOGIN] Starting login for: $email\n');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      print('Response Status: ${response.statusCode}');

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final userData = data['data']?['user'] ?? data['user'];
        final accessToken =
            data['data']?['accessToken'] ??
            data['accessToken'] ??
            data['token'];
        final refreshToken =
            data['data']?['refreshToken'] ?? data['refreshToken'] ?? '';

        if (accessToken == null || accessToken.isEmpty) {
          print('❌ No access token in response');
          return {'success': false, 'message': 'No token received from server'};
        }

        // ✅ Save BOTH tokens
        await _secureStorage.write(key: 'accessToken', value: accessToken);
        if (refreshToken.isNotEmpty) {
          await _secureStorage.write(key: 'refreshToken', value: refreshToken);
          print('✅ [TOKEN] Both tokens saved');
        }

        // Save user data
        await _secureStorage.write(
          key: 'userId',
          value:
              userData?['id']?.toString() ?? userData?['_id']?.toString() ?? '',
        );
        await _secureStorage.write(
          key: 'userName',
          value: userData?['name'] ?? '',
        );
        await _secureStorage.write(
          key: 'userEmail',
          value: userData?['email'] ?? '',
        );
        await _secureStorage.write(
          key: 'userUsername',
          value: userData?['username'] ?? '',
        );
        await _secureStorage.write(
          key: 'userAvatar',
          value: userData?['avatar'] ?? '',
        );
        await _secureStorage.write(
          key: 'userUpiId',
          value: userData?['upiId'] ?? '',
        );

        // ✅ Notify listeners (GoRouter)
        _notifyAuthChange(true);

        print('✅ [LOGIN] Success - redirecting...\n');
        return {
          'success': true,
          'message': 'Login successful',
          'user': userData,
          'accessToken': accessToken,
        };
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': 'Invalid email or password'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      print('❌ LOGIN ERROR: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// ========================
  /// REFRESH ACCESS TOKEN
  /// ========================
  static Future<Map<String, dynamic>> refreshAccessToken() async {
    try {
      print('\n🔄 [TOKEN-REFRESH] Attempting refresh...\n');

      final refreshToken = await _secureStorage.read(key: 'refreshToken');

      if (refreshToken == null || refreshToken.isEmpty) {
        print('❌ [REFRESH] No refresh token in storage');
        await clearAllData();
        return {'success': false, 'message': 'Refresh token not found'};
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccessToken =
            data['data']?['accessToken'] ?? data['accessToken'];
        final newRefreshToken = data['data']?['refreshToken'] ?? '';

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          await _secureStorage.write(key: 'accessToken', value: newAccessToken);
          if (newRefreshToken.isNotEmpty) {
            await _secureStorage.write(
              key: 'refreshToken',
              value: newRefreshToken,
            );
          }

          print('✅ [REFRESH] Access token refreshed successfully\n');
          return {'success': true, 'accessToken': newAccessToken};
        }
      }

      print('❌ [REFRESH] Failed to refresh token');
      await clearAllData();
      _notifyAuthChange(false);
      return {'success': false, 'message': 'Token refresh failed'};
    } catch (e) {
      print('❌ REFRESH TOKEN ERROR: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// ========================
  /// UPDATE PROFILE
  /// ========================
  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String username,
    required String email,
    String? upiId,
    String? avatar,
  }) async {
    try {
      print('\n✏️ [UPDATE-PROFILE] Updating profile...\n');

      final accessToken = await getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final body = <String, dynamic>{
        'name': name,
        'username': username,
        'email': email,
      };

      if (upiId != null && upiId.isNotEmpty) {
        body['upiId'] = upiId;
      }

      if (avatar != null && avatar.isNotEmpty) {
        body['avatar'] = avatar;
      }

      final response = await http
          .patch(
            Uri.parse('$_userBaseUrl/me'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      print('Response Status: ${response.statusCode}');

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final userData = data['user'];

        // Update local storage
        await _secureStorage.write(
          key: 'userName',
          value: userData['name'] ?? '',
        );
        await _secureStorage.write(
          key: 'userEmail',
          value: userData['email'] ?? '',
        );
        await _secureStorage.write(
          key: 'userUsername',
          value: userData['username'] ?? '',
        );
        if (userData['avatar'] != null) {
          await _secureStorage.write(
            key: 'userAvatar',
            value: userData['avatar'],
          );
        }
        if (userData['upiId'] != null) {
          await _secureStorage.write(
            key: 'userUpiId',
            value: userData['upiId'],
          );
        }

        print('✅ [UPDATE-PROFILE] Profile updated successfully\n');
        return {
          'success': true,
          'message': data['message'] ?? 'Profile updated successfully',
          'user': userData,
        };
      } else if (response.statusCode == 400) {
        return {'success': false, 'message': data['message'] ?? 'Invalid data'};
      } else if (response.statusCode == 401) {
        // Try refreshing token
        final refreshResult = await refreshAccessToken();
        if (refreshResult['success']) {
          // Retry the update
          return await updateProfile(
            name: name,
            username: username,
            email: email,
            upiId: upiId,
            avatar: avatar,
          );
        }
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Update failed',
        };
      }
    } catch (e) {
      print('❌ UPDATE PROFILE ERROR: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// ========================
  /// LOGOUT
  /// ========================
  static Future<Map<String, dynamic>> logout() async {
    try {
      print('\n🚪 [LOGOUT] Logging out...\n');

      final refreshToken = await _secureStorage.read(key: 'refreshToken');

      // Try to logout on server
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          await http
              .post(
                Uri.parse('$_baseUrl/logout'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'refreshToken': refreshToken}),
              )
              .timeout(const Duration(seconds: 10));
        } catch (e) {
          print('⚠️ Server logout failed, clearing local data');
        }
      }

      // Clear all stored data
      await clearAllData();

      // ✅ Notify listeners (GoRouter)
      _notifyAuthChange(false);

      print('✅ [LOGOUT] Complete\n');
      return {'success': true, 'message': 'Logged out successfully'};
    } catch (e) {
      await clearAllData();
      _notifyAuthChange(false);
      return {'success': true, 'message': 'Logged out'};
    }
  }

  /// ========================
  /// TOKEN MANAGEMENT
  /// ========================
  static Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: 'accessToken');
  }

  static Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: 'refreshToken');
  }

  /// ========================
  /// CHECK AUTHENTICATION
  /// ========================
  static Future<bool> isAuthenticated() async {
    try {
      final token = await _secureStorage.read(key: 'accessToken');
      final isAuth = token != null && token.isNotEmpty;
      print('🔍 [AUTH-CHECK] Result: $isAuth');
      return isAuth;
    } catch (e) {
      print('❌ [AUTH-CHECK] Error: $e');
      return false;
    }
  }

  /// ========================
  /// GET CURRENT USER INFO
  /// ========================
  static Future<Map<String, String?>> getCurrentUserInfo() async {
    return {
      'id': await _secureStorage.read(key: 'userId'),
      'name': await _secureStorage.read(key: 'userName'),
      'email': await _secureStorage.read(key: 'userEmail'),
      'username': await _secureStorage.read(key: 'userUsername'),
      'avatar': await _secureStorage.read(key: 'userAvatar'),
      'upiId': await _secureStorage.read(key: 'userUpiId'),
    };
  }

  /// Get current user ID
  static Future<String?> getUserId() async {
    final userId = await _secureStorage.read(key: 'userId');
    print('🔵 [DEBUG-AUTH] getUserId() returned: $userId'); // ADD THIS
    return userId;
  }

  // Get current user name
  static Future<String?> getUserName() async {
    return await _secureStorage.read(key: 'userName');
  }

  /// ========================
  /// CLEAR ALL DATA
  /// ========================
  static Future<void> clearAllData() async {
    try {
      await _secureStorage.deleteAll();
      print('✅ [STORAGE] All data cleared');
    } catch (e) {
      print('❌ [STORAGE] Error clearing: $e');
    }
  }

  /// ========================
  /// DISPOSE (cleanup)
  /// ========================
  static void dispose() {
    _authStateController.close();
  }
}
