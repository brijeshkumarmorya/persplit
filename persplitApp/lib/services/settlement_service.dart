import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';
import 'auth_service.dart';

class SettlementService {
  static final Dio _dio = Dio();
  static const String _baseUrl = baseUrl;
  static bool _isInitialized = false;

  /// Initialize Dio with interceptors
  static void initializeDio() {
    if (_isInitialized) {
      debugPrint('⚠️ [DIO] Already initialized');
      return;
    }

    debugPrint('\n🔧 [DIO] Initializing...\n');
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
    debugPrint('✅ [DIO] Ready\n');
  }

  /// ✅ HELPER: Get headers with token
  static Future<Map<String, String>> _getHeadersWithToken() async {
    final token = await AuthService.getAccessToken();
    return {
      'Authorization': token != null && token.isNotEmpty ? 'Bearer $token' : '',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  /// GET PENDING EXPENSES
  static Future<Map<String, dynamic>> getPendingExpenses() async {
    try {
      debugPrint('\n🔄 [FETCH] Getting pending expenses...\n');
      final headers = await _getHeadersWithToken();
      debugPrint(
        '🔍 [TOKEN-CHECK] Auth: ${headers['Authorization']?.substring(0, 20) ?? 'NONE'}...',
      );

      final response = await _dio.get(
        '$_baseUrl/expenses/pending-expenses',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: headers,
        ),
      );

      debugPrint('Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final responseData = data['data'] as Map<String, dynamic>? ?? {};
        final expenses = responseData['expenses'] as List? ?? [];

        debugPrint('✅ [SUCCESS] Got ${expenses.length} expenses\n');
        return {
          'success': true,
          'message': 'Expenses retrieved',
          'expenses': expenses,
        };
      } else if (response.statusCode == 401) {
        debugPrint('❌ [401] Unauthorized\n');
        return {'success': false, 'message': 'Session expired', 'expenses': []};
      } else {
        return {'success': false, 'message': 'Failed', 'expenses': []};
      }
    } catch (e) {
      debugPrint('❌ [ERR] $e\n');
      return {'success': false, 'message': 'Error: $e', 'expenses': []};
    }
  }

  /// ✅ GET NET AMOUNT WITH SPECIFIC USER - WITH EXPLICIT TOKEN
  static Future<Map<String, dynamic>> getNetAmountWithUser({
    required String friendId,
  }) async {
    try {
      debugPrint('\n💰 [NET-AMOUNT] Getting net with: $friendId\n');

      final token = await AuthService.getAccessToken();
      debugPrint('🔍 [TOKEN] Exists: ${token != null && token.isNotEmpty}');
      if (token != null && token.isNotEmpty) {
        debugPrint('   Value: Bearer ${token.substring(0, 30)}...');
      }

      final headers = await _getHeadersWithToken();
      debugPrint('📤 [REQ] GET /expenses/net-with/$friendId');
      debugPrint(
        '📋 [HEADERS] Authorization: ${headers['Authorization']?.substring(0, 40) ?? 'NONE'}...',
      );

      final response = await _dio.get(
        '$_baseUrl/expenses/net-with/$friendId',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: headers,
        ),
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final responseData = data['data'] as Map<String, dynamic>? ?? {};
        final netAmount = (responseData['netAmount'] ?? 0.0).toDouble();

        debugPrint('✅ [NET-AMOUNT] Success: $netAmount\n');
        return {
          'success': true,
          'netAmount': netAmount,
          'message': responseData['message'] ?? 'Calculated',
          'between': responseData['between'],
        };
      } else if (response.statusCode == 401) {
        debugPrint('❌ [401] No token in request\n');
        return {
          'success': false,
          'netAmount': 0.0,
          'message': 'Session expired',
        };
      } else {
        final error = response.data['error'] as Map<String, dynamic>?;
        debugPrint('❌ [ERROR] ${error?['message'] ?? 'Unknown'}\n');
        return {
          'success': false,
          'netAmount': 0.0,
          'message': error?['message'] ?? 'Failed',
        };
      }
    } catch (e) {
      debugPrint('❌ [EXCEPTION] $e\n');
      return {'success': false, 'netAmount': 0.0, 'message': 'Error: $e'};
    }
  }

  /// ✅ FIX BUG 2: SETTLE SPLIT - Mark as settled and refresh calculations
  static Future<Map<String, dynamic>> settleSplit({
    required String expenseId,
    required String splitId,
    required double amount,
  }) async {
    try {
      debugPrint(
        '\n💸 [SETTLE-SPLIT] Expense: $expenseId, Split: $splitId, Amount: $amount\n',
      );

      final headers = await _getHeadersWithToken();
      final response = await _dio.patch(
        '$_baseUrl/expenses/$expenseId/split/$splitId/settle',
        data: {'amount': amount},
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: headers,
        ),
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.data}');

      if (response.statusCode == 200) {
        debugPrint('✅ [SETTLE-SPLIT] Success\n');
        return {
          'success': true,
          'message': 'Settled successfully',
          'data': response.data['data'],
        };
      } else {
        debugPrint('❌ [SETTLE-SPLIT] Failed: ${response.statusCode}\n');
        return {
          'success': false,
          'message': response.data['error']?['message'] ?? 'Settlement failed',
        };
      }
    } catch (e) {
      debugPrint('❌ [SETTLE-SPLIT-ERR] $e\n');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// ✅ FIX BUG 2: SETTLE FRIENDWISE - Pay off net amount to friend
  /// This should handle partial or full payments toward net balance
  static Future<Map<String, dynamic>> settleFriendwise({
    required String friendId,
    required double amount,
  }) async {
    try {
      debugPrint(
        '\n💸 [SETTLE-FRIENDWISE] Friend: $friendId, Amount: $amount\n',
      );

      final headers = await _getHeadersWithToken();

      // ✅ NEW ENDPOINT: Backend should have a dedicated friendwise settlement
      // This should settle multiple pending splits up to the amount paid
      final response = await _dio.post(
        '$_baseUrl/expenses/settle-friendwise',
        data: {'friendId': friendId, 'amount': amount},
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: headers,
        ),
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ [SETTLE-FRIENDWISE] Success\n');
        return {
          'success': true,
          'message': 'Settled successfully',
          'data': response.data['data'],
        };
      } else {
        debugPrint('❌ [SETTLE-FRIENDWISE] Failed: ${response.statusCode}\n');
        return {
          'success': false,
          'message': response.data['error']?['message'] ?? 'Settlement failed',
        };
      }
    } catch (e) {
      debugPrint('❌ [SETTLE-FRIENDWISE-ERR] $e\n');

      // ✅ FALLBACK: If backend doesn't have friendwise endpoint yet,
      // the frontend should handle settling multiple splits
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// GET FRIEND SUMMARY
  static Future<Map<String, dynamic>> getFriendSummary({
    required String friendId,
  }) async {
    try {
      final headers = await _getHeadersWithToken();
      final response = await _dio.get(
        '$_baseUrl/expenses/friend-summary/$friendId',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: headers,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>? ?? {};
        return {
          'success': true,
          'youOwe': (data['youOwe'] ?? 0.0).toDouble(),
          'owedToYou': (data['owedToYou'] ?? 0.0).toDouble(),
          'netAmount': (data['netAmount'] ?? 0.0).toDouble(),
        };
      }

      return {
        'success': false,
        'youOwe': 0.0,
        'owedToYou': 0.0,
        'netAmount': 0.0,
      };
    } catch (e) {
      return {
        'success': false,
        'youOwe': 0.0,
        'owedToYou': 0.0,
        'netAmount': 0.0,
      };
    }
  }

  /// GET ALL FRIENDS NET AMOUNTS AND CALCULATE TOTAL BALANCE
  static Future<Map<String, dynamic>> getTotalBalance() async {
    try {
      debugPrint('\n💰 [TOTAL-BALANCE] Calculating total balance...\n');
      final headers = await _getHeadersWithToken();

      final pendingResult = await getPendingExpenses();
      if (!pendingResult['success']) {
        return {
          'success': false,
          'toReceive': 0.0,
          'toPay': 0.0,
          'message': 'Failed to get pending expenses',
        };
      }

      final expenses = pendingResult['expenses'] as List;
      Set<String> friendIds = {};

      for (var expense in expenses) {
        final splitDetails = expense['splitDetails'] as List? ?? [];
        for (var split in splitDetails) {
          final userId = split['user']['_id'] as String?;
          if (userId != null) {
            friendIds.add(userId);
          }
        }
        final paidById = expense['paidBy']['_id'] as String?;
        if (paidById != null) {
          friendIds.add(paidById);
        }
      }

      debugPrint('🔍 [FRIENDS] Found ${friendIds.length} unique users');

      double totalToReceive = 0.0;
      double totalToPay = 0.0;

      for (String friendId in friendIds) {
        final netResult = await getNetAmountWithUser(friendId: friendId);
        if (netResult['success']) {
          final netAmount = (netResult['netAmount'] ?? 0.0).toDouble();
          if (netAmount > 0) {
            totalToReceive += netAmount;
          } else if (netAmount < 0) {
            totalToPay += netAmount.abs();
          }
          debugPrint(
            '   Friend $friendId: ${netAmount > 0 ? '+' : ''}$netAmount',
          );
        }
      }

      debugPrint('✅ [BALANCE] Receive: $totalToReceive, Pay: $totalToPay\n');
      return {
        'success': true,
        'toReceive': totalToReceive,
        'toPay': totalToPay,
        'message': 'Balance calculated successfully',
      };
    } catch (e) {
      debugPrint('❌ [TOTAL-BALANCE-ERR] $e\n');
      return {
        'success': false,
        'toReceive': 0.0,
        'toPay': 0.0,
        'message': 'Error: $e',
      };
    }
  }

  static bool isInitialized() => _isInitialized;
  static Dio getDio() => _dio;
}
