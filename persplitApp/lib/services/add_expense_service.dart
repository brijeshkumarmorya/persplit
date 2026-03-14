import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../utils/constants.dart';

const String _baseUrl = baseUrl;

Future<Map<String, dynamic>> addExpense({
  required String title,
  required double amount,
  required String category,
  required String type,
  required String splitType,
  String? groupId,
  String? description,
  List<Map<String, dynamic>>? splitDetails,
}) async {
  try {
    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) {
      print('❌ [ERROR] No auth token');
      return {'success': false, 'message': 'Not authenticated'};
    } 

    print('\n========== FRONTEND: EXPENSE CREATE ==========');
    print('Title: $title');
    print('Amount: ₹$amount');
    print('Type: $type');
    print('Split Type: $splitType');
    print('Group ID: $groupId');
    print('Split Details: $splitDetails');
    print('==============================================\n');

    final body = {
      'description': title,
      'amount': amount,
      'category': category,
      'type': type, // ✅ SEND TYPE
      'group': groupId,
      'splitType': splitType,
      'notes': description ?? '',
      'currency': 'INR',
    };

    // ✅ ADD SPLIT DETAILS IF PRESENT
    if (splitDetails != null && splitDetails.isNotEmpty) {
      body['splitDetails'] = splitDetails.map((detail) {
        return {
          'user': detail['id'],
          'percentage': detail['percentage'],
          'amount': detail['amount'],
        };
      }).toList();
    }

    print('📤 Sending to backend: ${jsonEncode(body)}\n');

    final response = await http
        .post(
          Uri.parse('$_baseUrl/expenses/add'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    print('📥 Response: ${response.statusCode}');
    print('📥 Body: ${response.body}\n');

    if (response.statusCode == 201 || response.statusCode == 200) {
      print('✅ SUCCESS!\n');
      final data = jsonDecode(response.body);
      return {
        'success': true,
        'message': 'Expense added successfully',
        'expense': data['expense'] ?? data['data']?['expense'],
      };
    } else {
      print('❌ FAILED!\n');
      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to add expense',
      };
    }
  } catch (e) {
    print('❌ ERROR: $e\n');
    return {'success': false, 'message': 'Error: $e'};
  }
}
