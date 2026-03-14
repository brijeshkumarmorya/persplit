// ======================= group_service_COMPLETE.dart =======================
// lib/services/group_service.dart - ALL METHODS FOR FULL GROUP FUNCTIONALITY

import 'package:dio/dio.dart';
import '../utils/constants.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class GroupService {
  static final Dio _dio = Dio();
  static const String _baseUrl = baseUrl; // ← UPDATE THIS
  static bool _isInitialized = false;

  /// Initialize Dio with auth interceptor
  static void initializeDio() {
    if (_isInitialized) {
      debugPrint('⚠️ [DIO-GROUP] Already initialized');
      return;
    }

    debugPrint('\n🔧 [DIO-GROUP] Initializing...\n');

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

                debugPrint('📤 [REQ] ${options.method} ${options.path}');

                if (token != null && token.isNotEmpty) {
                  options.headers['Authorization'] = 'Bearer $token';
                  debugPrint('✅ [TOKEN] Injected');
                } else {
                  debugPrint('⚠️ [TOKEN] None available');
                }

                options.headers['Accept'] = 'application/json';
                return handler.next(options);
              } catch (e) {
                debugPrint('❌ [REQ-ERR] $e');
                return handler.next(options);
              }
            },
        onResponse: (Response response, ResponseInterceptorHandler handler) {
          debugPrint('✅ [RES] ${response.statusCode}');
          return handler.next(response);
        },
        onError: (DioException e, ErrorInterceptorHandler handler) async {
          debugPrint('❌ [ERR] ${e.response?.statusCode}');

          if (e.response?.statusCode == 401) {
            debugPrint('\n🔐 [401] Token refresh...\n');

            final refreshResult = await AuthService.refreshAccessToken();

            if (refreshResult['success'] == true) {
              final newToken = await AuthService.getAccessToken();

              if (newToken != null && newToken.isNotEmpty) {
                e.requestOptions.headers['Authorization'] = 'Bearer $newToken';

                try {
                  final response = await _dio.request(
                    e.requestOptions.path,
                    options: Options(
                      method: e.requestOptions.method,
                      headers: e.requestOptions.headers,
                    ),
                    data: e.requestOptions.data,
                    queryParameters: e.requestOptions.queryParameters,
                  );

                  return handler.resolve(response);
                } catch (retryError) {
                  return handler.next(e);
                }
              }
            }
          }

          return handler.next(e);
        },
      ),
    );

    _isInitialized = true;
    debugPrint('✅ [DIO-GROUP] Ready\n');
  }

  /// Helper: Get headers with token
  static Future<Map<String, String>> _getHeadersWithToken() async {
    final token = await AuthService.getAccessToken();
    return {
      'Authorization': token != null && token.isNotEmpty ? 'Bearer $token' : '',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  /// ✅ CREATE GROUP
  static Future<Map<String, dynamic>> createGroup({
    required String name,
    required String description,
    required List<String> memberIds,
  }) async {
    try {
      debugPrint('\n👥 [CREATE-GROUP] Creating: $name\n');

      final headers = await _getHeadersWithToken();

      final response = await _dio.post(
        '$_baseUrl/groups',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: headers,
        ),
        data: {'name': name, 'description': description, 'members': memberIds},
      );

      debugPrint('Response Status: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final groupData = data['data'] as Map<String, dynamic>? ?? data;

        debugPrint('✅ [CREATE-GROUP] Success\n');

        return {
          'success': true,
          'message': 'Group created successfully',
          'group': groupData['group'] ?? groupData,
        };
      }

      return {'success': false, 'message': 'Failed to create group'};
    } catch (e) {
      debugPrint('❌ [ERR] $e\n');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// ✅ GET MY GROUPS (with optional search)
  static Future<Map<String, dynamic>> getUserGroups({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    try {
      debugPrint('\n👥 [GET-GROUPS] Fetching my groups\n');

      final headers = await _getHeadersWithToken();

      final queryParams = <String, dynamic>{'page': page, 'limit': limit};

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _dio.get(
        '$_baseUrl/groups/my',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: headers,
        ),
        queryParameters: queryParams,
      );

      debugPrint('Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final groupsData = data['data'] as Map<String, dynamic>? ?? {};
        final groups = groupsData['groups'] as List<dynamic>? ?? [];

        debugPrint('✅ [GET-GROUPS] Got ${groups.length} groups\n');

        return {
          'success': true,
          'message': 'Groups retrieved',
          'groups': groups,
        };
      }

      return {
        'success': false,
        'message': 'Failed to fetch groups',
        'groups': [],
      };
    } catch (e) {
      debugPrint('❌ [ERR] $e\n');
      return {'success': false, 'message': 'Error: $e', 'groups': []};
    }
  }

  /// ✅ GET GROUP DETAILS
  /// ✅ GET GROUP DETAILS (with expenses and balances)
  static Future<Map<String, dynamic>> getGroupDetails(String groupId) async {
    try {
      debugPrint('\n👥 [GET-GROUP-DETAILS] Fetching: $groupId\n');
      final headers = await _getHeadersWithToken();

      final response = await _dio.get(
        '$_baseUrl/groups/$groupId',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: headers,
        ),
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final responseData = data['data'] as Map<String, dynamic>? ?? {};

        debugPrint('✅ [GET-GROUP-DETAILS] Success\n');

        return {
          'success': true,
          'group': responseData['group'],
          'expenses': responseData['expenses'] ?? [],
          'balance':
              responseData['balance'] ?? {'youOwe': '0.0', 'youAreOwed': '0.0'},
        };
      }

      return {'success': false, 'message': 'Group not found'};
    } catch (e) {
      debugPrint('❌ [ERR] $e\n');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// ✅ ADD MEMBER TO GROUP
  static Future<Map<String, dynamic>> addGroupMember({
    required String groupId,
    required String memberId,
  }) async {
    try {
      debugPrint('\n👥 [ADD-MEMBER] Adding to group: $groupId\n');

      final headers = await _getHeadersWithToken();

      final response = await _dio.patch(
        '$_baseUrl/groups/$groupId/add-member',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: headers,
        ),
        data: {'memberId': memberId},
      );

      debugPrint('Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('✅ [ADD-MEMBER] Success\n');

        return {
          'success': true,
          'message': 'Member added successfully',
          'group': response.data['data'] ?? response.data['group'],
        };
      }

      return {'success': false, 'message': 'Failed to add member'};
    } catch (e) {
      debugPrint('❌ [ERR] $e\n');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// ✅ REMOVE MEMBER FROM GROUP
  static Future<Map<String, dynamic>> removeGroupMember({
    required String groupId,
    required String memberId,
  }) async {
    try {
      debugPrint('\n👥 [REMOVE-MEMBER] Removing from group: $groupId\n');

      final headers = await _getHeadersWithToken();

      final response = await _dio.delete(
        '$_baseUrl/groupId/remove-member',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: headers,
        ),
        data: {'memberId': memberId},
      );

      debugPrint('Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('✅ [REMOVE-MEMBER] Success\n');

        return {'success': true, 'message': 'Member removed successfully'};
      }

      return {'success': false, 'message': 'Failed to remove member'};
    } catch (e) {
      debugPrint('❌ [ERR] $e\n');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// ✅ EXIT GROUP (for current user)
  static Future<Map<String, dynamic>> exitGroup(String groupId) async {
    try {
      debugPrint('\n👥 [EXIT-GROUP] Exiting group: $groupId\n');

      // Get current user ID
      final userInfo = await AuthService.getCurrentUserInfo();
      final userId = userInfo['id'] as String? ?? '';

      if (userId.isEmpty) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      // Call remove member with current user's ID
      return await removeGroupMember(groupId: groupId, memberId: userId);
    } catch (e) {
      debugPrint('❌ [ERR] $e\n');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// ✅ UPDATE GROUP (name, description, etc.)
  static Future<Map<String, dynamic>> updateGroup({
    required String groupId,
    String? name,
    String? description,
  }) async {
    try {
      debugPrint('\n👥 [UPDATE-GROUP] Updating: $groupId\n');

      final headers = await _getHeadersWithToken();

      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;

      final response = await _dio.put(
        '$_baseUrl/groups/$groupId',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: headers,
        ),
        data: data,
      );

      debugPrint('Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('✅ [UPDATE-GROUP] Success\n');

        return {
          'success': true,
          'message': 'Group updated successfully',
          'group': response.data['data'] ?? response.data['group'],
        };
      }

      return {'success': false, 'message': 'Failed to update group'};
    } catch (e) {
      debugPrint('❌ [ERR] $e\n');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// ✅ GET GROUP EXPENSES
  static Future<Map<String, dynamic>> getGroupExpenses(String groupId) async {
    try {
      debugPrint('\n💰 [GROUP-EXPENSES] Fetching expenses for: $groupId\n');

      final headers = await _getHeadersWithToken();

      final response = await _dio.get(
        '$_baseUrl/groups/$groupId/expenses',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: headers,
        ),
      );

      debugPrint('Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final expensesData = data['data'] as Map<String, dynamic>? ?? {};
        final expenses = expensesData['expenses'] as List<dynamic>? ?? [];

        debugPrint('✅ [GROUP-EXPENSES] Got ${expenses.length} expenses\n');

        return {'success': true, 'expenses': expenses};
      }

      return {
        'success': false,
        'message': 'Failed to fetch expenses',
        'expenses': [],
      };
    } catch (e) {
      debugPrint('❌ [ERR] $e\n');
      return {'success': false, 'message': 'Error: $e', 'expenses': []};
    }
  }

  static bool isInitialized() => _isInitialized;
  static Dio getDio() => _dio;
}
