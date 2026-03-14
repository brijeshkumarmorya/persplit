import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'auth_service.dart';

class NotificationService {
  static final Dio _dio = Dio();
  static const String _baseUrl = baseUrl;
  static bool _isInitialized = false;

  /// Initialize Dio with interceptors
  static void initializeDio() {
    if (_isInitialized) {
      debugPrint('⚠️ [NOTIFICATION-DIO] Already initialized');
      return;
    }

    debugPrint('\n🔧 [NOTIFICATION-DIO] Initializing...\n');

    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.contentType = 'application/json';

    _dio.interceptors.clear();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest:
            (RequestOptions options, RequestInterceptorHandler handler) async {
              try {
                final token = await AuthService.getAccessToken();

                // ✅ DETAILED TOKEN DEBUG
                debugPrint(
                  '\n📤 [NOTIFICATION-REQ] ${options.method} ${options.path}',
                );
                debugPrint('🔑 [TOKEN-CHECK] Token exists: ${token != null}');
                debugPrint(
                  '🔑 [TOKEN-CHECK] Token length: ${token?.length ?? 0}',
                );
                if (token != null && token.isNotEmpty) {
                  debugPrint(
                    '🔑 [TOKEN-CHECK] Token preview: ${token.substring(0, token.length > 20 ? 20 : token.length)}...',
                  );
                }

                if (token != null && token.isNotEmpty) {
                  options.headers['Authorization'] = 'Bearer $token';
                  debugPrint('✅ [HEADER] Authorization header added');
                } else {
                  debugPrint('❌ [HEADER] No token available - will get 401!');
                }
                handler.next(options);
              } catch (e) {
                debugPrint('❌ [NOTIFICATION-REQ-ERROR] $e');
                handler.next(options);
              }
            },
        onResponse: (Response response, ResponseInterceptorHandler handler) {
          debugPrint('📥 [NOTIFICATION-RES] ${response.statusCode}');
          if (response.statusCode == 401) {
            debugPrint(
              '⚠️ [401] Unauthorized - token might be expired or invalid',
            );
          }
          handler.next(response);
        },
        onError: (DioException e, ErrorInterceptorHandler handler) {
          debugPrint('❌ [NOTIFICATION-ERROR] ${e.message}');
          debugPrint('   Status: ${e.response?.statusCode}');
          debugPrint('   Data: ${e.response?.data}');
          handler.next(e);
        },
      ),
    );

    _isInitialized = true;
    debugPrint('✅ [NOTIFICATION-DIO] Initialized successfully\n');
  }

  /// Ensure Dio is initialized before making requests
  static void _ensureInitialized() {
    if (!_isInitialized) {
      initializeDio();
    }
  }

  /// Get authorization headers
  static Future<Map<String, String>> _getHeadersWithToken() async {
    final token = await AuthService.getAccessToken();

    debugPrint('\n🔍 [GET-HEADERS] Preparing headers...');
    debugPrint('🔑 Token exists: ${token != null}');
    debugPrint('🔑 Token empty: ${token?.isEmpty ?? true}');

    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// ================================================================
  /// GET MY NOTIFICATIONS
  /// ================================================================
  static Future<Map<String, dynamic>> getMyNotifications() async {
    _ensureInitialized();

    try {
      debugPrint('\n📬 [GET-NOTIFICATIONS] Fetching...');

      // ✅ CHECK AUTHENTICATION FIRST
      final isAuth = await AuthService.isAuthenticated();
      debugPrint('🔐 [AUTH-CHECK] Authenticated: $isAuth');

      if (!isAuth) {
        debugPrint('❌ [AUTH-CHECK] User not authenticated!');
        return {
          'success': false,
          'message': 'Please login to view notifications',
        };
      }

      final headers = await _getHeadersWithToken();

      // ✅ VERIFY TOKEN IN HEADERS
      final hasAuth = headers.containsKey('Authorization');
      debugPrint('🔑 [HEADERS] Has Authorization: $hasAuth');

      final response = await _dio.get(
        '$_baseUrl/notifications',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: headers,
        ),
      );

      debugPrint('📥 [GET-NOTIFICATIONS] Status: ${response.statusCode}');

      if (response.statusCode == 401) {
        debugPrint('⚠️ [401] Attempting token refresh...');

        // Try to refresh token
        final refreshResult = await AuthService.refreshAccessToken();

        if (refreshResult['success'] == true) {
          debugPrint('✅ [REFRESH] Token refreshed, retrying request...');
          // Retry the request with new token
          return await getMyNotifications();
        } else {
          debugPrint('❌ [REFRESH] Token refresh failed');
          return {
            'success': false,
            'message': 'Session expired. Please login again.',
          };
        }
      }

      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        final notifications = data['notifications'] as List? ?? [];

        debugPrint(
          '✅ [GET-NOTIFICATIONS] Found ${notifications.length} notifications',
        );

        return {'success': true, 'notifications': notifications};
      }

      return {
        'success': false,
        'message': response.data['message'] ?? 'Failed to fetch notifications',
      };
    } catch (e) {
      debugPrint('❌ [GET-NOTIFICATIONS-ERROR] $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// ================================================================
  /// MARK NOTIFICATION AS READ
  /// ================================================================
  static Future<Map<String, dynamic>> markAsRead({
    required String notificationId,
  }) async {
    _ensureInitialized();

    try {
      debugPrint('\n✅ [MARK-READ] Notification: $notificationId');

      final headers = await _getHeadersWithToken();

      final response = await _dio.patch(
        '$_baseUrl/notifications/$notificationId/read',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: headers,
        ),
      );

      debugPrint('📥 [MARK-READ] Status: ${response.statusCode}');

      if (response.statusCode == 401) {
        // Try refresh
        final refreshResult = await AuthService.refreshAccessToken();

        if (refreshResult['success'] == true) {
          return await markAsRead(notificationId: notificationId);
        } else {
          return {
            'success': false,
            'message': 'Session expired. Please login again.',
          };
        }
      }

      if (response.statusCode == 200) {
        debugPrint('✅ [MARK-READ] Successfully marked as read');

        return {'success': true, 'message': 'Notification marked as read'};
      }

      return {
        'success': false,
        'message': response.data['message'] ?? 'Failed to mark as read',
      };
    } catch (e) {
      debugPrint('❌ [MARK-READ-ERROR] $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// ================================================================
  /// HELPER: Get notification icon based on type
  /// ================================================================
  static IconData getNotificationIcon(String type) {
    switch (type) {
      case 'payment_confirmed':
      case 'payment_request':
        return Icons.currency_rupee;
      case 'friend_request':
      case 'friend_accept':
      case 'friend_accepted':
        return Icons.person_add_alt_1;
      case 'expense_added':
      case 'expense_updated':
        return Icons.receipt_long;
      case 'group_invite':
      case 'group_settled':
        return Icons.groups;
      case 'settlement_reminder':
        return Icons.notifications_active;
      default:
        return Icons.notifications_none;
    }
  }

  /// ================================================================
  /// HELPER: Get notification icon color based on type
  /// ================================================================
  static Color getNotificationIconColor(String type) {
    switch (type) {
      case 'payment_confirmed':
      case 'payment_request':
        return const Color(0xFF41A67E); // Green
      case 'friend_request':
      case 'friend_accept':
      case 'friend_accepted':
        return const Color(0xFF90CAF9); // Blue
      case 'expense_added':
      case 'expense_updated':
        return const Color(0xFFFF9800); // Orange
      case 'group_invite':
      case 'group_settled':
        return const Color(0xFF64C5CC); // Teal
      case 'settlement_reminder':
        return const Color(0xFFB39DDB); // Purple
      default:
        return const Color(0xFF9E9E9E); // Gray
    }
  }
}
