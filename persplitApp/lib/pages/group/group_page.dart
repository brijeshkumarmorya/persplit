// lib/pages/group/group_page.dart (FINAL: Full Width, Photos Removed)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/group_service.dart';
import '../home/widgets/bottomNavBar.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  int _currentPage = 1;
  int _totalGroups = 0;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await GroupService.getUserGroups(
      search: _searchQuery.isEmpty ? null : _searchQuery,
      page: _currentPage,
    );

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      dynamic groupsData = result['groups'] ?? [];

      if (groupsData is Map) {
        groupsData = [];
      }

      if (groupsData is List) {
        setState(() {
          _groups = List<Map<String, dynamic>>.from(groupsData);
          _totalGroups = result['total'] ?? 0;
        });
      } else {
        setState(() {
          _groups = [];
          _errorMessage = 'Invalid data format from server';
        });
      }
    } else {
      setState(() {
        _errorMessage = result['message'];
        _groups = [];
      });
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 1;
    });
    _loadGroups();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadGroups();
  }

  Future<void> _refreshGroups() async {
    await _loadGroups();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAF9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAF9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => context.go('/'),
        ),
        centerTitle: true,
        title: Text(
          "My Groups",
          style: TextStyle(
            fontSize: width * 0.045,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black87, size: 28),
            onPressed: () => context.push('/create-group'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshGroups,
        color: const Color(0xFF41A67E),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: width * 0.04,
            vertical: height * 0.01,
          ),
          child: Column(
            children: [
              _buildSearchBar(context, width),
              SizedBox(height: height * 0.02),

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

              if (_errorMessage != null) SizedBox(height: height * 0.02),

              _isLoading
                  ? SizedBox(
                      height: height * 0.6,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF41A67E),
                        ),
                      ),
                    )
                  : _groups.isEmpty
                  ? SizedBox(
                      height: height * 0.6,
                      child: Center(
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
                              'No groups yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to create your first group',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: _groups.map((group) {
                        return _buildGroupCard(context, group, width);
                      }).toList(),
                    ),

              SizedBox(height: height * 0.02),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }

  Widget _buildSearchBar(BuildContext context, double width) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: width * 0.04,
        vertical: width * 0.015,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.04),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.black45),
          SizedBox(width: width * 0.02),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: "Search groups...",
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: Colors.black38,
                  fontSize: width * 0.04,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(
    BuildContext context,
    Map<String, dynamic> group,
    double width,
  ) {
    final groupName = group['name'] ?? 'Untitled Group';
    final membersCount = (group['members'] as List?)?.length ?? 0;
    final groupId = group['id']?.toString() ?? group['_id']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        if (groupId.isNotEmpty) {
          context.go('/group/$groupId');
        }
      },
      child: Container(
        width: double.infinity, // ⭐ FULL WIDTH
        margin: EdgeInsets.symmetric(vertical: width * 0.02),
        padding: EdgeInsets.all(width * 0.04),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(width * 0.04),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              groupName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: width * 0.045,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: width * 0.01),
            Text(
              "$membersCount members",
              style: TextStyle(color: Colors.black54, fontSize: width * 0.035),
            ),

            SizedBox(height: width * 0.03),

            /// ⭐ Removed avatars completely + let card expand fully
            const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
