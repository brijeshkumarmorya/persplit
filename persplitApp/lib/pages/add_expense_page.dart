// lib/pages/expense/add_expense_page.dart - FULLY FIXED VERSION

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/group_service.dart';
import '../../services/friend_service.dart';
import '../../services/auth_service.dart';
import '../services/add_expense_service.dart' as AddExpenseService;
import 'home/widgets/bottomNavBar.dart';
import 'home/widgets/toggleButton.dart';

class AddExpensePage extends StatefulWidget {
  final String? groupId;
  const AddExpensePage({super.key, this.groupId});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  int selectedExpenseType = 0;
  int selectedSplitType = 1;
  String? selectedCategory;
  String? selectedGroup;

  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> members = [];

  bool _isLoading = false;
  bool _isLoadingGroups = false;
  bool _isLoadingFriends = false;
  String? _errorMessage;

  // ✅ ADD THESE
  String? _currentUserId;
  String? _currentUserName;

  final List<String> categories = [
    'Food',
    'Travel',
    'Entertainment',
    'Utilities',
    'Shopping',
    'Health',
    'Education',
    'Rent',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // ✅ LOAD CURRENT USER INFO FIRST
    _currentUserId = await AuthService.getUserId();
    _currentUserName = await AuthService.getUserName();

    await _loadGroups();
    await _loadFriends();

    if (widget.groupId != null) {
      selectedGroup = widget.groupId;
      selectedExpenseType = 1;
      _loadGroupMembers(widget.groupId!);
    }
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoadingGroups = true);
    final result = await GroupService.getUserGroups();
    if (result['success']) {
      dynamic groupsList = result['groups'] ?? [];
      if (groupsList is List) {
        setState(() {
          _groups = List<Map<String, dynamic>>.from(groupsList);
          _isLoadingGroups = false;
        });
      }
    } else {
      setState(() => _isLoadingGroups = false);
    }
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoadingFriends = true);
    final result = await FriendService.getFriends();
    if (result['success']) {
      dynamic friendsList = result['friends'] ?? [];
      if (friendsList is List) {
        setState(() {
          _friends = List<Map<String, dynamic>>.from(friendsList);
          _isLoadingFriends = false;
        });
      }
    } else {
      setState(() => _isLoadingFriends = false);
    }
  }

  Future<void> _loadGroupMembers(String groupId) async {
    final result = await GroupService.getGroupDetails(groupId);
    if (result['success']) {
      final groupData = result['group'] as Map<String, dynamic>?;
      final membersList = groupData?['members'] as List? ?? [];

      setState(() {
        members = membersList.map((member) {
          return {
            'id': member['_id'] ?? member['id'] ?? '',
            'name': member['name'] ?? member['username'] ?? 'Member',
            'share': 100.0 / (membersList.length > 0 ? membersList.length : 1),
            'amount': 0.0,
          };
        }).toList();
      });
      _updateAmounts();
    }
  }

  // ✅ FIXED: Add current user first if not already in list
  void _addMemberToExpense(Map<String, dynamic> friend) {
    setState(() {
      // ✅ CHECK: Is this the first member being added for instant split?
      if (selectedExpenseType == 2 && members.isEmpty) {
        // ✅ ADD CURRENT USER FIRST
        if (_currentUserId != null && _currentUserName != null) {
          members.add({
            'id': _currentUserId!,
            'name': '$_currentUserName (You)',
            'share': 50.0, // Will be recalculated
            'amount': 0.0,
            'isCurrentUser': true, // ✅ Mark as current user
          });
          print('✅ Current user added to display: $_currentUserName');
        }
      }

      // ✅ NOW ADD THE SELECTED FRIEND
      final exists = members.any(
        (m) => m['id'] == friend['_id'] || m['id'] == friend['id'],
      );

      if (!exists) {
        members.add({
          'id': friend['_id'] ?? friend['id'] ?? '',
          'name': friend['name'] ?? friend['username'] ?? 'Friend',
          'share': 100.0 / (members.length + 1),
          'amount': 0.0,
        });

        // ✅ RECALCULATE EQUAL SHARES
        for (var member in members) {
          member['share'] = 100.0 / members.length;
        }

        _updateAmounts();
      }
    });
  }

  void _removeMemberFromExpense(String memberId) {
    setState(() {
      // ✅ PREVENT REMOVING CURRENT USER IN INSTANT SPLIT
      final memberToRemove = members.firstWhere(
        (m) => m['id'] == memberId,
        orElse: () => {},
      );

      if (memberToRemove['isCurrentUser'] == true && selectedExpenseType == 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You cannot remove yourself from the split'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      members.removeWhere((m) => m['id'] == memberId);

      if (members.isNotEmpty) {
        for (var member in members) {
          member['share'] = 100.0 / members.length;
        }
        _updateAmounts();
      }
    });
  }

  void _updateAmounts() {
    final amount = double.tryParse(amountController.text) ?? 0.0;
    setState(() {
      if (selectedSplitType == 0) {
        // Equal split
        final equalAmount = members.isNotEmpty ? amount / members.length : 0.0;
        for (var member in members) {
          member['amount'] = equalAmount;
          member['share'] = members.isNotEmpty ? 100.0 / members.length : 0.0;
        }
      } else if (selectedSplitType == 1) {
        // Percentage split
        for (var member in members) {
          member['amount'] = (amount * (member['share'] / 100)).toDouble();
        }
      }
    });
  }

  double _getTotalCustomAmount() {
    double total = 0;
    for (var member in members) {
      total += member['amount'] ?? 0.0;
    }
    return total;
  }

  String? _validateExpense() {
    if (titleController.text.isEmpty) return 'Please enter expense title';

    if (amountController.text.isEmpty ||
        double.tryParse(amountController.text) == null) {
      return 'Please enter valid amount';
    }

    if (selectedCategory == null) return 'Please select a category';

    if (selectedExpenseType == 1 && selectedGroup == null) {
      return 'Please select a group';
    }

    if (members.isEmpty) return 'Please add at least one member';

    final totalAmount = double.tryParse(amountController.text) ?? 0.0;

    if (selectedExpenseType != 0) {
      if (selectedSplitType == 1) {
        double totalPercentage = 0.0;
        for (var member in members) {
          totalPercentage += member['share'];
        }
        if ((totalPercentage - 100.0).abs() > 0.01) {
          return 'Percentages must sum to 100%';
        }
      } else if (selectedSplitType == 2) {
        final customTotal = _getTotalCustomAmount();
        if ((customTotal - totalAmount).abs() > 0.01) {
          return 'Custom amounts must sum to ₹$totalAmount';
        }
      }
    }

    return null;
  }

  Future<void> _addExpense() async {
    final error = _validateExpense();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final expenseTypes = ['personal', 'group', 'instant'];
    final splitTypes = ['equal', 'percentage', 'custom', 'none'];

    List<Map<String, dynamic>>? splitDetails;

    // ✅ HANDLE ALL EXPENSE TYPES CORRECTLY
    if (selectedExpenseType == 0) {
      // PERSONAL: No split details needed
      splitDetails = null;
    } else if (selectedExpenseType == 1) {
      // GROUP: Send ALL members including current user
      splitDetails = members.map((member) {
        return {
          'id': member['id'],
          'percentage': member['share'],
          'amount': member['amount'],
        };
      }).toList();

      print('📤 Frontend sending (GROUP split):');
      print('Total members: ${splitDetails.length}');
      for (var detail in splitDetails) {
        print(
          '  ${detail['id']}: ${detail['percentage']}% = ₹${detail['amount']}',
        );
      }
    } else if (selectedExpenseType == 2) {
      // INSTANT: Send ONLY friends (exclude current user)
      // Backend will add current user automatically
      splitDetails = members
          .where((member) => member['isCurrentUser'] != true)
          .map((member) {
            return {
              'id': member['id'],
              'percentage': member['share'],
              'amount': member['amount'],
            };
          })
          .toList();

      print('📤 Frontend sending (INSTANT split):');
      print('Selected friends: ${splitDetails.length}');
      for (var detail in splitDetails) {
        print(
          '  ${detail['id']}: ${detail['percentage']}% = ₹${detail['amount']}',
        );
      }
    }

    final result = await AddExpenseService.addExpense(
      title: titleController.text,
      amount: double.tryParse(amountController.text) ?? 0.0,
      category: selectedCategory ?? 'Other',
      type: expenseTypes[selectedExpenseType],
      splitType: selectedExpenseType == 0
          ? 'none'
          : splitTypes[selectedSplitType],
      groupId: selectedGroup,
      description: descriptionController.text,
      splitDetails: splitDetails,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense added successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) context.go('/');
    } else {
      setState(
        () => _errorMessage = result['message'] ?? 'Failed to add expense',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => context.go('/'),
        ),
        centerTitle: true,
        title: const Text(
          'Add Expense',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF41A67E)),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: width * 0.05,
                vertical: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  _buildAmountInput(),
                  const SizedBox(height: 24),

                  _buildTextField(
                    'Title',
                    'e.g. Dinner with friends',
                    titleController,
                  ),
                  const SizedBox(height: 16),

                  _buildCategoryDropdown(),
                  const SizedBox(height: 16),

                  _buildTextField(
                    'Description',
                    '(Optional)',
                    descriptionController,
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Expense Type',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ToggleButtonsRow(
                    tabs: const ['Personal', 'Group', 'Instant'],
                    initialIndex: selectedExpenseType,
                    onTabSelected: (index) {
                      setState(() {
                        selectedExpenseType = index;
                        if (index == 0) members.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  if (selectedExpenseType == 1) ...[
                    _buildGroupDropdown(),
                    const SizedBox(height: 20),
                  ],

                  if (selectedExpenseType != 0) ...[
                    const Text(
                      'Type:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ToggleButtonsRow(
                      tabs: const ['Equal', 'Percentage', 'Custom'],
                      initialIndex: selectedSplitType,
                      onTabSelected: (index) {
                        setState(() {
                          selectedSplitType = index;
                          _updateAmounts();
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    if (selectedExpenseType == 1)
                      _buildAddGroupMembersButton()
                    else if (selectedExpenseType == 2)
                      _buildAddFriendsButton(),

                    const SizedBox(height: 16),
                    _buildMembersRowList(),
                    const SizedBox(height: 20),

                    // Validation info for Custom split
                    if (selectedSplitType == 2) _buildCustomSplitInfo(),
                    const SizedBox(height: 20),
                  ],

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
                      onPressed: _isLoading ? null : _addExpense,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Add Expense',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }

  Widget _buildAmountInput() {
    return Center(
      child: Column(
        children: [
          const Text(
            'Amount',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '₹',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF41A67E),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: amountController,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '0.00',
                  ),
                  onChanged: (value) => _updateAmounts(),
                ),
              ),
            ],
          ),
          const Divider(height: 20, thickness: 1, color: Colors.black12),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    TextEditingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: selectedCategory,
            hint: const Text('Select Category'),
            isExpanded: true,
            underline: const SizedBox(),
            items: categories
                .map(
                  (String cat) =>
                      DropdownMenuItem(value: cat, child: Text(cat)),
                )
                .toList(),
            onChanged: (String? value) =>
                setState(() => selectedCategory = value),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Group',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _isLoadingGroups
              ? const Center(child: CircularProgressIndicator())
              : DropdownButton<String>(
                  value: selectedGroup,
                  hint: const Text('Choose a group'),
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _groups.map((group) {
                    final groupId = group['_id'] ?? group['id'] ?? '';
                    final groupName = group['name'] ?? 'Group';
                    return DropdownMenuItem(
                      value: groupId.toString(),
                      child: Text(groupName),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    setState(() => selectedGroup = value);
                    if (value != null) _loadGroupMembers(value);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAddGroupMembersButton() {
    return GestureDetector(
      onTap: () {
        _showAddMembersDialogWithSearch(
          _groups.firstWhere(
                    (g) =>
                        g['_id'] == selectedGroup || g['id'] == selectedGroup,
                    orElse: () => {},
                  )['members']
                  as List? ??
              [],
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.person_add, color: Colors.grey, size: 18),
            SizedBox(width: 8),
            Text(
              'Add Members',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddFriendsButton() {
    return GestureDetector(
      onTap: () => _showAddFriendsDialogWithSearch(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.person_add, color: Colors.grey, size: 18),
            SizedBox(width: 8),
            Text(
              'Add Members',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMembersDialogWithSearch(List<dynamic> groupMembers) {
    final searchController = TextEditingController();
    List<dynamic> filteredMembers = List.from(groupMembers);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Add Group Members',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: double.maxFinite,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search members...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          filteredMembers = groupMembers.where((m) {
                            final name = (m['name'] ?? m['username'] ?? '')
                                .toString()
                                .toLowerCase();
                            return name.contains(value.toLowerCase());
                          }).toList();
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: filteredMembers.isEmpty
                        ? Center(
                            child: Text(
                              'No members found',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredMembers.length,
                            itemBuilder: (context, index) {
                              final member =
                                  filteredMembers[index]
                                      as Map<String, dynamic>;
                              final name =
                                  member['name'] ??
                                  member['username'] ??
                                  'Member';
                              final isAlreadyAdded = members.any(
                                (m) =>
                                    m['id'] == member['_id'] ||
                                    m['id'] == member['id'],
                              );

                              return ListTile(
                                enabled: !isAlreadyAdded,
                                leading: CircleAvatar(
                                  backgroundColor: isAlreadyAdded
                                      ? Colors.grey.shade300
                                      : Colors.purple.shade200,
                                  child: Text(
                                    name[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                title: Text(name),
                                trailing: isAlreadyAdded
                                    ? Icon(
                                        Icons.check,
                                        color: Colors.green.shade700,
                                      )
                                    : null,
                                onTap: isAlreadyAdded
                                    ? null
                                    : () {
                                        _addMemberToExpense(member);
                                        Navigator.pop(context);
                                      },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddFriendsDialogWithSearch() {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> filteredFriends = List.from(_friends);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Add Friends',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: double.maxFinite,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search friends...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          filteredFriends = _friends.where((f) {
                            final name = (f['name'] ?? f['username'] ?? '')
                                .toString()
                                .toLowerCase();
                            return name.contains(value.toLowerCase());
                          }).toList();
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: _isLoadingFriends
                        ? const Center(child: CircularProgressIndicator())
                        : filteredFriends.isEmpty
                        ? Center(
                            child: Text(
                              'No friends found',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredFriends.length,
                            itemBuilder: (context, index) {
                              final friend =
                                  filteredFriends[index]
                                      as Map<String, dynamic>;
                              final name =
                                  friend['name'] ??
                                  friend['username'] ??
                                  'Friend';
                              final isAlreadyAdded = members.any(
                                (m) =>
                                    m['id'] == friend['_id'] ||
                                    m['id'] == friend['id'],
                              );

                              return ListTile(
                                enabled: !isAlreadyAdded,
                                leading: CircleAvatar(
                                  backgroundColor: isAlreadyAdded
                                      ? Colors.grey.shade300
                                      : Colors.purple.shade200,
                                  child: Text(
                                    name[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                title: Text(name),
                                trailing: isAlreadyAdded
                                    ? Icon(
                                        Icons.check,
                                        color: Colors.green.shade700,
                                      )
                                    : null,
                                onTap: isAlreadyAdded
                                    ? null
                                    : () {
                                        _addMemberToExpense(friend);
                                        Navigator.pop(context);
                                      },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Build clean rows with Name | Editable Value | Amount
  Widget _buildMembersRowList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (members.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No members added',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ),
          )
        else
          ...members.map(
            (member) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildMemberRow(member),
            ),
          ),
      ],
    );
  }

  Widget _buildMemberRow(Map<String, dynamic> member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Member name
          Expanded(
            flex: 2,
            child: Text(
              member['name'],
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Split entry
          Expanded(
            flex: 2,
            child: selectedSplitType == 1
                ? _buildPercentageField(member)
                : _buildAmountField(member),
          ),
          const SizedBox(width: 10),

          // Remove button
          InkWell(
            onTap: () => _removeMemberFromExpense(member['id']),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentageField(Map<String, dynamic> member) {
    final controller = TextEditingController(
      text: member['share'].toStringAsFixed(0),
    );

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              enabled: selectedSplitType != 0,
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: TextStyle(
                color: Colors.green.shade800,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
              ),
              onChanged: (value) {
                setState(() {
                  member['share'] = double.tryParse(value) ?? 0.0;
                  _updateAmounts();
                });
              },
            ),
          ),
          Text(
            '%',
            style: TextStyle(
              color: Colors.green.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField(Map<String, dynamic> member) {
    final controller = TextEditingController(
      text: member['amount'].toStringAsFixed(2),
    );

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          const Text(
            '₹',
            style: TextStyle(
              color: Color(0xFF2563EB),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              enabled: selectedSplitType != 0,
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
              ),
              onChanged: (value) {
                setState(() {
                  member['amount'] = double.tryParse(value) ?? 0.0;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomSplitInfo() {
    final totalAmount = double.tryParse(amountController.text) ?? 0.0;
    final customTotal = _getTotalCustomAmount();
    final isValid = (customTotal - totalAmount).abs() < 0.01;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isValid ? Colors.green.shade50 : Colors.orange.shade50,
        border: Border.all(
          color: isValid ? Colors.green.shade300 : Colors.orange.shade300,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.info,
            color: isValid ? Colors.green.shade700 : Colors.orange.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isValid
                  ? 'Total: ₹${customTotal.toStringAsFixed(2)} / ₹${totalAmount.toStringAsFixed(2)} ✓'
                  : 'Total: ₹${customTotal.toStringAsFixed(2)} / ₹${totalAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isValid ? Colors.green.shade700 : Colors.orange.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}
