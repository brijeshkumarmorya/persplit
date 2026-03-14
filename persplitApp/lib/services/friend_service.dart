// lib/services/friend_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';
import 'auth_service.dart';

class FriendService {
  static const String _baseUrl = baseUrl;
  // For Android Emulator: http://10.0.2.2:8000/api
  // For Physical Device: http://YOUR_IP:8000/api

  /// Get user's friends list
  static Future<Map<String, dynamic>> getFriends() async {
    try {
      final token = await AuthService.getAccessToken();

      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      print('🔵 Fetching friends list...');

      final response = await http.get(
        Uri.parse('$_baseUrl/friends/list'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      print('Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Friends fetched successfully');

        // Handle both 'friends' and 'data.friends' response formats
        dynamic friendsList = data['friends'] ?? data['data']?['friends'] ?? [];

        if (friendsList is Map) {
          friendsList = [];
        }

        if (friendsList is List) {
          return {
            'success': true,
            'friends': List<Map<String, dynamic>>.from(friendsList),
          };
        } else {
          return {
            'success': true,
            'friends': [],
          };
        }
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch friends',
        };
      }
    } catch (e) {
      print('❌ GET FRIENDS ERROR: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'friends': [],
      };
    }
  }

  /// Get pending friend requests
  static Future<Map<String, dynamic>> getPendingRequests() async {
    try {
      final token = await AuthService.getAccessToken();

      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      print('🔵 Fetching pending requests...');

      final response = await http.get(
        Uri.parse('$_baseUrl/friends/requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      print('Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Pending requests fetched');

        // Handle both response formats
        dynamic requestsList =
            data['pendingRequests'] ?? data['data']?['pendingRequests'] ?? [];

        if (requestsList is Map) {
          requestsList = [];
        }

        if (requestsList is List) {
          return {
            'success': true,
            'pendingRequests': List<Map<String, dynamic>>.from(requestsList),
          };
        } else {
          return {
            'success': true,
            'pendingRequests': [],
          };
        }
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch requests',
        };
      }
    } catch (e) {
      print('❌ GET PENDING REQUESTS ERROR: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'pendingRequests': [],
      };
    }
  }

  /// Search users by name or username
  static Future<Map<String, dynamic>> searchUsers(String query) async {
    try {
      if (query.trim().isEmpty) {
        return {
          'success': true,
          'users': [],
          'count': 0,
        };
      }

      final token = await AuthService.getAccessToken();

      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      print('🔵 Searching users: $query');

      final response = await http.get(
        Uri.parse('$_baseUrl/friends/search?query=$query'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      print('Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Users found: ${data['count']}');

        dynamic usersList = data['users'] ?? data['data']?['users'] ?? [];

        if (usersList is Map) {
          usersList = [];
        }

        if (usersList is List) {
          return {
            'success': true,
            'users': List<Map<String, dynamic>>.from(usersList),
            'count': data['count'] ?? usersList.length,
          };
        } else {
          return {
            'success': true,
            'users': [],
            'count': 0,
          };
        }
      } else {
        return {
          'success': false,
          'message': 'No users found',
          'users': [],
          'count': 0,
        };
      }
    } catch (e) {
      print('❌ SEARCH USERS ERROR: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'users': [],
        'count': 0,
      };
    }
  }

  /// Send friend request
  static Future<Map<String, dynamic>> sendFriendRequest(String friendId) async {
    try {
      final token = await AuthService.getAccessToken();

      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      print('🔵 Sending friend request to: $friendId');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/friends/send'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'friendId': friendId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      print('Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Friend request sent');

        return {
          'success': true,
          'message': 'Friend request sent',
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to send request',
        };
      }
    } catch (e) {
      print('❌ SEND FRIEND REQUEST ERROR: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Accept friend request
  static Future<Map<String, dynamic>> acceptFriendRequest(
      String friendId) async {
    try {
      final token = await AuthService.getAccessToken();

      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      print('🔵 Accepting friend request from: $friendId');

      final response = await http
          .patch(
            Uri.parse('$_baseUrl/friends/accept'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'friendId': friendId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      print('Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Friend request accepted');

        return {
          'success': true,
          'message': 'Friend request accepted',
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to accept request',
        };
      }
    } catch (e) {
      print('❌ ACCEPT FRIEND REQUEST ERROR: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Reject friend request
  static Future<Map<String, dynamic>> rejectFriendRequest(
      String friendId) async {
    try {
      final token = await AuthService.getAccessToken();

      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      print('🔵 Rejecting friend request from: $friendId');

      final response = await http
          .patch(
            Uri.parse('$_baseUrl/friends/reject'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'friendId': friendId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      print('Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Friend request rejected');

        return {
          'success': true,
          'message': 'Friend request rejected',
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to reject request',
        };
      }
    } catch (e) {
      print('❌ REJECT FRIEND REQUEST ERROR: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}
