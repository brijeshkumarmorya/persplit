// lib/pages/friend/friends_page_integrated.dart (UPDATED - PROPER STATUS ICONS)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/friend_service.dart';
import 'home/widgets/bottomNavBar.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _searchResults = [];
  final Set<String> _sentRequests = {}; // Track users we sent requests to

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFriendsData();
  }

  Future<void> _loadFriendsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Fetch both friends and pending requests
    final friendsResult = await FriendService.getFriends();
    final requestsResult = await FriendService.getPendingRequests();

    setState(() {
      _isLoading = false;

      if (friendsResult['success']) {
        dynamic friendsList = friendsResult['friends'] ?? [];
        if (friendsList is List) {
          _friends = List<Map<String, dynamic>>.from(friendsList);
        } else {
          _friends = [];
        }
      } else {
        _errorMessage = friendsResult['message'];
      }

      if (requestsResult['success']) {
        dynamic requestsList = requestsResult['pendingRequests'] ?? [];
        if (requestsList is List) {
          _pendingRequests = List<Map<String, dynamic>>.from(requestsList);
        } else {
          _pendingRequests = [];
        }
      }
    });
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {});

    final result = await FriendService.searchUsers(query);

    setState(() {
      if (result['success']) {
        dynamic usersList = result['users'] ?? [];
        if (usersList is List) {
          _searchResults = List<Map<String, dynamic>>.from(usersList);
        } else {
          _searchResults = [];
        }
      } else {
        _searchResults = [];
      }
    });
  }

  /// Check if user is already a friend
  bool _isFriend(String userId) {
    return _friends.any((f) => (f['_id'] == userId || f['id'] == userId));
  }

  /// Check if request has been sent to this user
  bool _hasRequestSent(String userId) {
    return _sentRequests.contains(userId);
  }

  /// Check if user has pending request from this person
  bool _hasPendingRequest(String userId) {
    return _pendingRequests.any(
      (r) => (r['_id'] == userId || r['id'] == userId),
    );
  }

  /// Get user status
  /// Returns: 'friend' | 'requested' | 'pending' | 'stranger'
  String _getUserStatus(String userId) {
    if (_isFriend(userId)) {
      return 'friend';
    } else if (_hasRequestSent(userId)) {
      return 'requested';
    } else if (_hasPendingRequest(userId)) {
      return 'pending';
    }
    return 'stranger';
  }

  Future<void> _acceptRequest(String friendId) async {
    final result = await FriendService.acceptFriendRequest(friendId);

    if (result['success']) {
      // Reload data
      _loadFriendsData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request accepted!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to accept request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectRequest(String friendId) async {
    final result = await FriendService.rejectFriendRequest(friendId);

    if (result['success']) {
      // Reload data
      _loadFriendsData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request rejected'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to reject request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendFriendRequest(String friendId) async {
    final result = await FriendService.sendFriendRequest(friendId);

    if (result['success']) {
      // Track that we sent request to this user
      setState(() {
        _sentRequests.add(friendId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request sent!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to send request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _refreshData() async {
    await _loadFriendsData();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isTablet = width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => context.go('/'),
        ),
        centerTitle: true,
        title: const Text(
          'Friends',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF41A67E),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF41A67E)),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.04,
                  vertical: height * 0.01,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: width * 0.02),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            color: Colors.green.shade600,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _searchUsers,
                              decoration: InputDecoration(
                                hintText: "Search friends",
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Search Results
                    if (_searchController.text.isNotEmpty &&
                        _searchResults.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'Search Results (${_searchResults.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._searchResults.map((user) {
                            final userId = user['_id'] ?? user['id'] ?? '';
                            final name = user['name'] ?? 'User';
                            final username = user['username'] ?? 'user';

                            return _buildSearchUserCard(
                              context,
                              name,
                              username,
                              userId,
                              isTablet,
                            );
                          }).toList(),
                          const SizedBox(height: 24),
                        ],
                      ),

                    // Error Message
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_errorMessage != null) const SizedBox(height: 16),

                    // Friend Requests Section
                    if (_pendingRequests.isNotEmpty) ...[
                      _buildSectionHeader(
                        'Friend Requests',
                        _pendingRequests.length,
                      ),
                      const SizedBox(height: 14),
                      ..._pendingRequests.map((request) {
                        final requestId = request['_id'] ?? request['id'] ?? '';
                        final name = request['name'] ?? 'User';
                        final username = request['username'] ?? 'user';

                        return _buildRequestCard(
                          context,
                          name,
                          username,
                          requestId,
                          isTablet,
                        );
                      }).toList(),
                      const SizedBox(height: 28),
                    ],

                    // Friends Section
                    if (_friends.isNotEmpty) ...[
                      _buildSectionHeader('Friends', _friends.length),
                      const SizedBox(height: 14),
                      ..._friends.map((friend) {
                        final friendId = friend['_id'] ?? friend['id'] ?? '';
                        final name = friend['name'] ?? 'User';
                        final username = friend['username'] ?? 'user';

                        return _buildFriendCard(
                          name,
                          username,
                          friendId,
                          isTablet,
                        );
                      }).toList(),
                    ] else if (_pendingRequests.isEmpty &&
                        _searchController.text.isEmpty)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: height * 0.1),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No friends yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Search and add friends to get started',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: title == 'Friend Requests'
                  ? Colors.green.shade50
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: title == 'Friend Requests'
                    ? Colors.green.shade200
                    : Colors.grey.shade300,
              ),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: title == 'Friend Requests'
                    ? Colors.green.shade700
                    : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    String name,
    String username,
    String friendId,
    bool isTablet,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: isTablet ? 32 : 26,
            backgroundColor: Colors.green.shade100,
            child: Text(
              name[0].toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isTablet ? 18 : 16,
                color: Colors.green.shade700,
              ),
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@$username',
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontSize: isTablet ? 15 : 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => _acceptRequest(friendId),
                child: Container(
                  width: isTablet ? 44 : 38,
                  height: isTablet ? 44 : 38,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.green.withOpacity(0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    Icons.check,
                    color: Colors.green.shade700,
                    size: isTablet ? 22 : 20,
                  ),
                ),
              ),
              SizedBox(width: isTablet ? 12 : 10),
              GestureDetector(
                onTap: () => _rejectRequest(friendId),
                child: Container(
                  width: isTablet ? 44 : 38,
                  height: isTablet ? 44 : 38,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.red.withOpacity(0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.red.shade600,
                    size: isTablet ? 22 : 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFriendCard(
    String name,
    String username,
    String friendId,
    bool isTablet,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isTablet ? 14 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: isTablet ? 30 : 24,
            backgroundColor: Colors.grey.shade200,
            child: Text(
              name[0].toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isTablet ? 16 : 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: isTablet ? 17 : 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@$username',
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Only show info icon for friends (no add button)
          Icon(
            Icons.info_outline,
            size: isTablet ? 28 : 24,
            color: const Color(0xFF777C6D),
          ),
        ],
      ),
    );
  }

  /// Build search user card with status-based icon
  Widget _buildSearchUserCard(
    BuildContext context,
    String name,
    String username,
    String userId,
    bool isTablet,
  ) {
    final status = _getUserStatus(userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isTablet ? 14 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: isTablet ? 30 : 24,
            backgroundColor: _getAvatarColor(status),
            child: Text(
              name[0].toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isTablet ? 16 : 14,
                color: _getAvatarTextColor(status),
              ),
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: isTablet ? 17 : 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@$username',
                  style: TextStyle(
                    color: _getSubtitleColor(status),
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _buildStatusButton(status, userId, isTablet),
        ],
      ),
    );
  }

  /// Get avatar background color based on status
  Color _getAvatarColor(String status) {
    switch (status) {
      case 'friend':
        return Colors.grey.shade200; // Already friend
      case 'requested':
        return Colors.orange.shade100; // Request sent
      case 'pending':
        return Colors.green.shade100; // Pending request
      default:
        return Colors.blue.shade200; // Stranger
    }
  }

  /// Get avatar text color based on status
  Color _getAvatarTextColor(String status) {
    switch (status) {
      case 'friend':
        return Colors.grey.shade700;
      case 'requested':
        return Colors.orange.shade700;
      case 'pending':
        return Colors.green.shade700;
      default:
        return Colors.blue.shade700;
    }
  }

  /// Get subtitle text color based on status
  Color _getSubtitleColor(String status) {
    switch (status) {
      case 'friend':
        return Colors.green.shade600;
      case 'requested':
        return Colors.orange.shade600;
      case 'pending':
        return Colors.green.shade600;
      default:
        return Colors.blue.shade600;
    }
  }

  /// Build status button based on user status
  Widget _buildStatusButton(String status, String userId, bool isTablet) {
    switch (status) {
      case 'friend':
        // Already a friend - show no button (just info icon or nothing)
        return Icon(
          Icons.info_outline,
          size: isTablet ? 28 : 24,
          color: Colors.grey.shade600,
        );

      case 'requested':
        // Request already sent - show clock/timer icon
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 12 : 10,
            vertical: isTablet ? 8 : 6,
          ),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(isTablet ? 10 : 8),
            border: Border.all(color: Colors.orange.shade300, width: 1.5),
          ),
          child: Tooltip(
            message: 'Request sent',
            child: Icon(
              Icons.schedule,
              size: isTablet ? 24 : 20,
              color: Colors.orange.shade700,
            ),
          ),
        );

      case 'pending':
        // Has pending request from this user - show no button
        return Icon(
          Icons.info_outline,
          size: isTablet ? 28 : 24,
          color: Colors.green.shade600,
        );

      default:
        // Stranger - show add friend button
        return GestureDetector(
          onTap: () => _sendFriendRequest(userId),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: isTablet ? 10 : 8,
            ),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
              border: Border.all(color: Colors.blue.shade300, width: 1.5),
            ),
            child: Icon(
              Icons.person_add,
              size: isTablet ? 24 : 20,
              color: Colors.blue.shade700,
            ),
          ),
        );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
