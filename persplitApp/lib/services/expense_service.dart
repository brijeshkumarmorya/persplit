import '../utils/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_service.dart';

class ExpenseService {
  static const String _baseUrl = baseUrl;
  // For Android Emulator: http://10.0.2.2:8000/api
  // For Physical Device: http://YOUR_IP:8000/api

  /// Get user's expenses
  static Future<Map<String, dynamic>> getUserExpenses({
    String? filter, // 'all', 'personal', 'instant', 'group'
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final token = await AuthService.getAccessToken();

      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      print('🔵 Fetching expenses...');

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (filter != null && filter != 'all') 'type': filter,
      };

      final uri = Uri.parse('$_baseUrl/expenses').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      print('Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Expenses fetched successfully');

        return {
          'success': true,
          'expenses': data['data']?['expenses'] ?? data['expenses'] ?? [],
          'total': data['data']?['total'] ?? data['total'] ?? 0,
          'page': data['data']?['page'] ?? data['page'] ?? 1,
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch expenses',
        };
      }
    } catch (e) {
      print('❌ GET EXPENSES ERROR: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'expenses': [], // Return empty list on error
      };
    }
  }

  /// Get user's balance summary
  static Future<Map<String, dynamic>> getUserBalance() async {
    try {
      final token = await AuthService.getAccessToken();

      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      print('🔵 Fetching balance...');

      final response = await http.get(
        Uri.parse('$_baseUrl/balance'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      print('Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Balance fetched successfully');

        return {
          'success': true,
          'toReceive': data['data']?['toReceive'] ?? data['toReceive'] ?? 0.0,
          'toPay': data['data']?['toPay'] ?? data['toPay'] ?? 0.0,
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch balance',
        };
      }
    } catch (e) {
      print('❌ GET BALANCE ERROR: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'toReceive': 0.0,
        'toPay': 0.0,
      };
    }
  }

  /// Create new expense
  static Future<Map<String, dynamic>> createExpense({
    required String title,
    required double amount,
    required String category,
    String? description,
    String type = 'personal', // 'personal', 'instant', 'group'
    List<String>? participants,
  }) async {
    try {
      final token = await AuthService.getAccessToken();

      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      print('🔵 Creating expense...');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/expenses'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'title': title,
              'amount': amount,
              'category': category,
              'description': description,
              'type': type,
              'participants': participants,
            }),
          )
          .timeout(const Duration(seconds: 15));

      print('Response Status: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Expense created successfully');

        return {
          'success': true,
          'message': 'Expense created successfully',
          'expense': data['data']?['expense'] ?? data['expense'],
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to create expense',
        };
      }
    } catch (e) {
      print('❌ CREATE EXPENSE ERROR: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}
