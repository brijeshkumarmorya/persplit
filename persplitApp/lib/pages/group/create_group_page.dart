// ======================= create_group_page_FRIENDS_ONLY.dart =======================
// lib/pages/group/create_group_page.dart - SHOW ONLY USER'S ACCEPTED FRIENDS

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/group_service.dart';
import '../../services/friend_service.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allFriends = []; // ✅ ONLY FRIENDS
  List<Map<String, dynamic>> _filteredFriends = [];
  Set<String> _selectedMemberIds = {};

  bool _isLoading = true;
  bool _isCreating = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadUserFriends(); // ✅ LOAD FRIENDS, NOT ALL USERS
  }

  /// ✅ Load ONLY user's accepted friends from backend
  Future<void> _loadUserFriends() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('\n👥 [LOADING FRIENDS] Fetching user\'s friends...\n');

      // ✅ Call getFriends (gets only accepted friends)
      final friendsResult = await FriendService.getFriends();

      if (friendsResult['success'] == true) {
        final friends = friendsResult['friends'] as List<dynamic>? ?? [];

        debugPrint('✅ Loaded ${friends.length} friends\n');

        setState(() {
          _allFriends = friends.map((friend) {
            final f = friend as Map<String, dynamic>;
            return {
              'id': f['id'] ?? f['_id'] ?? '',
              'name': f['name'] ?? 'Friend',
              'email': f['email'] ?? '',
              'username': f['username'] ?? '',
              'avatar': ((f['name'] ?? 'F') as String)[0].toUpperCase(),
            };
          }).toList();

          _filteredFriends = List.from(_allFriends);
          _isLoading = false;
        });

        // Show message if no friends
        if (_allFriends.isEmpty) {
          setState(() {
            _errorMessage = 'You have no friends yet. Add friends first!';
          });
        }
      } else {
        throw Exception(friendsResult['message'] ?? 'Failed to load friends');
      }
    } catch (e) {
      debugPrint('❌ Error loading friends: $e\n');

      setState(() {
        _errorMessage = 'Failed to load friends: $e';
        _isLoading = false;
        _allFriends = [];
        _filteredFriends = [];
      });
    }
  }

  /// ✅ Filter friends by search query (searches only in friends)
  void _filterFriends(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFriends = List.from(_allFriends);
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredFriends = _allFriends
            .where((friend) =>
                (friend['name'] as String).toLowerCase().contains(lowerQuery) ||
                (friend['email'] as String)
                    .toLowerCase()
                    .contains(lowerQuery) ||
                (friend['username'] as String)
                    .toLowerCase()
                    .contains(lowerQuery))
            .toList();
      }
    });
  }

  /// Toggle friend selection
  void _toggleFriend(String friendId) {
    setState(() {
      if (_selectedMemberIds.contains(friendId)) {
        _selectedMemberIds.remove(friendId);
      } else {
        _selectedMemberIds.add(friendId);
      }
    });
  }

  /// Create group
  Future<void> _createGroup() async {
    // Validate inputs
    if (_groupNameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a group name';
        _successMessage = null;
      });
      return;
    }

    if (_selectedMemberIds.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one friend';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
      _successMessage = null;
    });

    debugPrint('\n👥 [CREATE] Group: ${_groupNameController.text}');
    debugPrint(
        '👥 [CREATE] Selected Friends: ${_selectedMemberIds.toList()}\n');

    final result = await GroupService.createGroup(
      name: _groupNameController.text.trim(),
      description: '',
      memberIds: _selectedMemberIds.toList(),
    );

    setState(() {
      _isCreating = false;
    });

    if (result['success']) {
      setState(() {
        _successMessage = 'Group created successfully!';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Group created successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Navigate back after delay
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        context.go('/groups');
      }
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Failed to create group';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${result['message'] ?? "Failed to create group"}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: const Text(
          "Create Group",
          style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF41A67E)),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error Message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
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
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Success Message
                  if (_successMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _successMessage!,
                              style: const TextStyle(
                                  color: Colors.green, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Group Name Label
                  const Text(
                    "Group Name",
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 8),

                  // Group Name Input
                  TextField(
                    controller: _groupNameController,
                    decoration: InputDecoration(
                      hintText: "e.g. Weekend Trip, Apartment Utilities",
                      hintStyle: const TextStyle(color: Colors.black38),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Add Friends Label
                  const Text(
                    "Select Friends",
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 8),

                  // Search Friends (searches within friends only)
                  TextField(
                    controller: _searchController,
                    onChanged: _filterFriends,
                    decoration: InputDecoration(
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.black45),
                      hintText: "Search your friends",
                      hintStyle: const TextStyle(color: Colors.black38),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Friends List
                  Expanded(
                    child: _filteredFriends.isEmpty
                        ? Center(
                            child: Text(
                              _allFriends.isEmpty
                                  ? 'No friends available'
                                  : 'No friends found',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredFriends.length,
                            itemBuilder: (context, index) {
                              final friend = _filteredFriends[index];
                              final friendId = friend['id'] as String;
                              final isSelected =
                                  _selectedMemberIds.contains(friendId);

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor:
                                      const Color(0xFF41A67E).withOpacity(0.2),
                                  child: Text(
                                    friend['avatar'] as String,
                                    style: const TextStyle(
                                      color: Color(0xFF41A67E),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  friend['name'] as String,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14),
                                ),
                                subtitle: Text(
                                  friend['email'] as String,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                                trailing: GestureDetector(
                                  onTap: () => _toggleFriend(friendId),
                                  child: CircleAvatar(
                                    radius: 12,
                                    backgroundColor: isSelected
                                        ? const Color(0xFF41A67E)
                                        : Colors.transparent,
                                    child: isSelected
                                        ? const Icon(Icons.check,
                                            color: Colors.white, size: 16)
                                        : Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: Colors.black26),
                                            ),
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),

                  // Selected Count
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF41A67E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_selectedMemberIds.length} friend(s) selected',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF41A67E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Create Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF41A67E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isCreating ? null : _createGroup,
                      child: _isCreating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Create Group",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
