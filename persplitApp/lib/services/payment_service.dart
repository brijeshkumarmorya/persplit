import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';
import 'auth_service.dart';

class PaymentService {
  static const String _baseUrl = '$baseUrl/payments';

  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ============================================
  // 1. GET PAYEE DETAILS (WITH AMOUNT)
  // ============================================
  static Future<Map<String, dynamic>> getPayeeDetails(
    String payeeId, {
    double? amount,
  }) async {
    try {
      debugPrint('[PAYMENT-SERVICE] Getting payee details: $payeeId');
      debugPrint('[PAYMENT-SERVICE] Amount: $amount');
      final headers = await _getHeaders();

      if (!headers.containsKey('Authorization')) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      // Build URL with amount query parameter
      String url = '$_baseUrl/payee/$payeeId';
      if (amount != null) {
        final amountStr = amount.toStringAsFixed(2);
        url += '?amount=$amountStr';
      }

      debugPrint('[PAYMENT-SERVICE] Request URL: $url');
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(Constants.connectionTimeout);

      debugPrint('[PAYMENT-SERVICE] Response: ${response.statusCode}');
      debugPrint('[PAYMENT-SERVICE] Response body: ${response.body}');

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final payee = data['data']?['payee'];
        final upiIntent = data['data']?['upiIntent'];
        final note = data['data']?['note'];
        debugPrint('[PAYMENT-SERVICE] UPI Intent received: $upiIntent');
        return {
          'success': true,
          'payee': payee,
          'upiIntent': upiIntent,
          'note': note,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get payee details',
        };
      }
    } catch (e) {
      debugPrint('[PAYMENT-SERVICE] Error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ============================================
  // 2. SUBMIT PAYMENT (After User Pays)
  // ============================================
  static Future<Map<String, dynamic>> submitPayment({
    required String payeeId,
    String? expenseId,
    double? amount,
    required String method, // 'upi' or 'cash'
    String? transactionId,
    String? note,
  }) async {
    try {
      debugPrint('[PAYMENT-SERVICE] Submitting payment');
      debugPrint('[PAYMENT-SERVICE] Method: $method');
      debugPrint('[PAYMENT-SERVICE] PayeeId: $payeeId');
      debugPrint('[PAYMENT-SERVICE] ExpenseId: $expenseId');
      debugPrint('[PAYMENT-SERVICE] Amount: $amount');

      final headers = await _getHeaders();

      if (!headers.containsKey('Authorization')) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      // Build request body
      final body = <String, dynamic>{'payeeId': payeeId, 'method': method};

      if (expenseId != null) {
        body['expenseId'] = expenseId;
      }

      // ✅ CRITICAL FIX: Send amount as number, NOT string
      if (amount != null) {
        body['amount'] = amount; // ✅ This is correct - keep as double
      }

      if (transactionId != null && transactionId.isNotEmpty) {
        body['transactionId'] = transactionId;
      }

      if (note != null && note.isNotEmpty) {
        body['note'] = note;
      }

      debugPrint('[PAYMENT-SERVICE] Request body: ${jsonEncode(body)}');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/submit'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(Constants.connectionTimeout);

      debugPrint('[PAYMENT-SERVICE] Submit response: ${response.statusCode}');
      debugPrint('[PAYMENT-SERVICE] Response body: ${response.body}');

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'payment': data['data']?['payment'],
          'message': data['message'] ?? 'Payment submitted successfully',
        };
      } else if (response.statusCode == 401) {
        final refreshResult = await AuthService.refreshAccessToken();
        if (refreshResult['success']) {
          return await submitPayment(
            payeeId: payeeId,
            expenseId: expenseId,
            amount: amount,
            method: method,
            transactionId: transactionId,
            note: note,
          );
        }
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to submit payment',
        };
      }
    } catch (e) {
      debugPrint('[PAYMENT-SERVICE] Submit payment error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ============================================
  // 3. VERIFY PAYMENT (Payee Confirms/Rejects)
  // ============================================
  static Future<Map<String, dynamic>> verifyPayment({
    required String paymentId,
    required bool verified,
    String? rejectionReason,
  }) async {
    try {
      debugPrint('[PAYMENT-SERVICE] ====== VERIFY PAYMENT START ======');
      debugPrint('[PAYMENT-SERVICE] Payment ID: $paymentId');
      debugPrint('[PAYMENT-SERVICE] Verified: $verified');
      debugPrint('[PAYMENT-SERVICE] Rejection Reason: $rejectionReason');

      final headers = await _getHeaders();

      debugPrint('[PAYMENT-SERVICE] Headers: ${headers.keys.join(", ")}');

      if (!headers.containsKey('Authorization')) {
        debugPrint('[PAYMENT-SERVICE] ❌ Not authenticated');
        return {'success': false, 'message': 'Not authenticated'};
      }

      final body = {
        'verified': verified,
        if (rejectionReason != null && rejectionReason.isNotEmpty)
          'rejectionReason': rejectionReason,
      };

      debugPrint('[PAYMENT-SERVICE] Request URL: $_baseUrl/$paymentId/verify');
      debugPrint('[PAYMENT-SERVICE] Request body: ${jsonEncode(body)}');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/$paymentId/verify'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('[PAYMENT-SERVICE] Response status: ${response.statusCode}');
      debugPrint('[PAYMENT-SERVICE] Response body: ${response.body}');

      if (response.body.isEmpty) {
        debugPrint('[PAYMENT-SERVICE] ❌ Empty response from server');
        return {'success': false, 'message': 'Empty response from server'};
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        debugPrint('[PAYMENT-SERVICE] ✅ Payment verification successful');
        return {
          'success': true,
          'payment': data['data']?['payment'],
          'message':
              data['message'] ??
              (verified ? 'Payment confirmed' : 'Payment rejected'),
        };
      } else if (response.statusCode == 401) {
        debugPrint('[PAYMENT-SERVICE] Token expired, refreshing...');
        final refreshResult = await AuthService.refreshAccessToken();
        if (refreshResult['success']) {
          debugPrint('[PAYMENT-SERVICE] Token refreshed, retrying...');
          return await verifyPayment(
            paymentId: paymentId,
            verified: verified,
            rejectionReason: rejectionReason,
          );
        }
        debugPrint('[PAYMENT-SERVICE] ❌ Token refresh failed');
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      } else {
        debugPrint('[PAYMENT-SERVICE] ❌ Error: ${data['message']}');

        // Extract actual error message from nested structure
        String errorMessage = 'Failed to verify payment';

        if (data['error'] != null && data['error']['message'] != null) {
          errorMessage = data['error']['message'];
        } else if (data['message'] != null) {
          errorMessage = data['message'];
        }

        return {
          'success': false,
          'message': errorMessage, 
        };
      }
    } catch (e) {
      debugPrint('[PAYMENT-SERVICE] ❌ Exception: $e');
      debugPrint('[PAYMENT-SERVICE] Exception type: ${e.runtimeType}');
      return {'success': false, 'message': 'Network error: $e'};
    } finally {
      debugPrint('[PAYMENT-SERVICE] ====== VERIFY PAYMENT END ======');
    }
  }

  // ============================================
  // 4. CANCEL PAYMENT (Payer Only)
  // ============================================
  static Future<Map<String, dynamic>> cancelPayment(String paymentId) async {
    try {
      debugPrint('[PAYMENT-SERVICE] Cancelling payment: $paymentId');

      final headers = await _getHeaders();

      if (!headers.containsKey('Authorization')) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http
          .post(Uri.parse('$_baseUrl/$paymentId/cancel'), headers: headers)
          .timeout(Constants.connectionTimeout);

      debugPrint('[PAYMENT-SERVICE] Cancel response: ${response.statusCode}');

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'payment': data['data']?['payment'],
          'message': data['message'],
        };
      } else if (response.statusCode == 401) {
        final refreshResult = await AuthService.refreshAccessToken();
        if (refreshResult['success']) {
          return await cancelPayment(paymentId);
        }
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to cancel payment',
        };
      }
    } catch (e) {
      debugPrint('[PAYMENT-SERVICE] Cancel payment error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ============================================
  // 5. GET PAYMENT STATUS
  // ============================================
  static Future<Map<String, dynamic>> getPaymentStatus(String paymentId) async {
    try {
      final headers = await _getHeaders();

      if (!headers.containsKey('Authorization')) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http
          .get(Uri.parse('$_baseUrl/$paymentId'), headers: headers)
          .timeout(Constants.connectionTimeout);

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'payment': data['data']?['payment']};
      } else if (response.statusCode == 401) {
        final refreshResult = await AuthService.refreshAccessToken();
        if (refreshResult['success']) {
          return await getPaymentStatus(paymentId);
        }
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get payment status',
        };
      }
    } catch (e) {
      debugPrint('[PAYMENT-SERVICE] Get payment status error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ============================================
  // 6. GET PENDING PAYMENTS (TO PAY)
  // ============================================
  static Future<Map<String, dynamic>> getPendingPaymentsToPay() async {
    try {
      final headers = await _getHeaders();

      if (!headers.containsKey('Authorization')) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http
          .get(Uri.parse('$_baseUrl/pending/to-pay'), headers: headers)
          .timeout(Constants.connectionTimeout);

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'payments': data['data']?['payments'] ?? [],
          'count': data['data']?['count'] ?? 0,
        };
      } else if (response.statusCode == 401) {
        final refreshResult = await AuthService.refreshAccessToken();
        if (refreshResult['success']) {
          return await getPendingPaymentsToPay();
        }
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get pending payments',
        };
      }
    } catch (e) {
      debugPrint('[PAYMENT-SERVICE] Get pending payments error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ============================================
  // 7. GET PENDING PAYMENTS (TO CONFIRM)
  // ============================================
  static Future<Map<String, dynamic>> getPendingPaymentsToConfirm() async {
    try {
      final headers = await _getHeaders();

      if (!headers.containsKey('Authorization')) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http
          .get(Uri.parse('$_baseUrl/pending/to-confirm'), headers: headers)
          .timeout(Constants.connectionTimeout);

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'payments': data['data']?['payments'] ?? [],
          'count': data['data']?['count'] ?? 0,
        };
      } else if (response.statusCode == 401) {
        final refreshResult = await AuthService.refreshAccessToken();
        if (refreshResult['success']) {
          return await getPendingPaymentsToConfirm();
        }
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get payments to confirm',
        };
      }
    } catch (e) {
      debugPrint('[PAYMENT-SERVICE] Get payments to confirm error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
