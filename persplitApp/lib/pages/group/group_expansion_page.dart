import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/group_service.dart';
import '../../services/auth_service.dart';
import '../home/widgets/balanceCard.dart';
import '../home/widgets/expenseList.dart';

class GroupExpansionPage extends StatefulWidget {
  final String groupId;

  const GroupExpansionPage({super.key, required this.groupId});

  @override
  State<GroupExpansionPage> createState() => _GroupExpansionPageState();
}

class _GroupExpansionPageState extends State<GroupExpansionPage> {
  Map<String, dynamic>? _groupData;
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _filteredExpenses = [];

  double _youOwe = 0.0;
  double _youAreOwed = 0.0;
  String? _currentUserId; // ✅ For ExpenseList

  bool _isLoading = true;
  String? _errorMessage;

  int _selectedFilterIndex = 0; // 0=All, 1=Group, 2=Instant, 3=Personal

  @override
  void initState() {
    super.initState();
    _loadGroupDetails();
  }

  Future<void> _loadGroupDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // ✅ Get current user ID for ExpenseList
    _currentUserId = await AuthService.getUserId();
    debugPrint('🔑 Current User ID: $_currentUserId');

    final result = await GroupService.getGroupDetails(widget.groupId);

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      setState(() {
        _groupData = result['group'] as Map<String, dynamic>?;

        // Extract expenses
        final expensesList = result['expenses'] as List?;
        _expenses = expensesList != null
            ? List<Map<String, dynamic>>.from(expensesList)
            : [];

        // Extract balances
        final balance = result['balance'] as Map<String, dynamic>?;
        _youOwe = double.tryParse(balance?['youOwe']?.toString() ?? '0') ?? 0.0;
        _youAreOwed =
            double.tryParse(balance?['youAreOwed']?.toString() ?? '0') ?? 0.0;

        // Initialize filtered expenses (show all by default)
        _filterExpenses(_selectedFilterIndex);

        debugPrint('📊 Loaded ${_expenses.length} expenses');
        debugPrint('💰 You owe: ₹$_youOwe');
        debugPrint('💰 You are owed: ₹$_youAreOwed');
      });
    } else {
      setState(() {
        _errorMessage = result['message'];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to load group'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Filter expenses by type
  void _filterExpenses(int filterIndex) {
    setState(() {
      _selectedFilterIndex = filterIndex;

      if (filterIndex == 0) {
        // All expenses
        _filteredExpenses = List.from(_expenses);
      } else {
        // Filter by type
        String filterType = '';
        switch (filterIndex) {
          case 1:
            filterType = 'group';
            break;
          case 2:
            filterType = 'instant';
            break;
          case 3:
            filterType = 'personal';
            break;
        }

        _filteredExpenses = _expenses.where((exp) {
          final expenseType = (exp['type'] ?? exp['expenseType'] ?? 'group')
              .toString()
              .toLowerCase();
          return expenseType == filterType;
        }).toList();
      }

      debugPrint(
        '📊 Filtered ${_filteredExpenses.length} expenses for filter $filterIndex',
      );
    });
  }

  Future<void> _refreshGroupData() async {
    await _loadGroupDetails();
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'About':
        _showAboutDialog();
        break;
      case 'Add Member':
        _showAddMemberDialog();
        break;
      case 'Settle Up':
        _showSettleUpDialog();
        break;
      case 'Analyse':
        _showAnalyseDialog();
        break;
      case 'Exit':
        _showExitConfirmDialog();
        break;
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_groupData?['name'] ?? 'Group'),
        content: Text(_groupData?['description'] ?? 'No description'),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Member'),
        content: const Text('Add member functionality coming soon!'),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSettleUpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settle Up'),
        content: const Text('Settle up functionality coming soon!'),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAnalyseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analyse'),
        content: const Text('Analyse functionality coming soon!'),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Group'),
        content: const Text(
          'Are you sure you want to exit this group? You\'ll no longer see this group.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              context.pop();
              final result = await GroupService.exitGroup(widget.groupId);
              if (result['success']) {
                if (mounted) {
                  context.go('/groups');
                }
              }
            },
            child: const Text('Exit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupName = _groupData?['name'] ?? 'Group';
    final memberCount = (_groupData?['members'] as List?)?.length ?? 0;
    final width = MediaQuery.of(context).size.width;
    final isTablet = width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAF9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => context.go('/groups'),
        ),
        centerTitle: true,
        title: Text(
          groupName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'About', child: Text('About')),
              PopupMenuItem(value: 'Add Member', child: Text('Add Member')),
              PopupMenuItem(value: 'Settle Up', child: Text('Settle Up')),
              PopupMenuItem(value: 'Analyse', child: Text('Analyse')),
              PopupMenuItem(value: 'Exit', child: Text('Exit')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF41A67E)),
            )
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshGroupData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF41A67E),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Scrollable header section
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshGroupData,
                    color: const Color(0xFF41A67E),
                    child: CustomScrollView(
                      slivers: [
                        // Header Section
                        SliverToBoxAdapter(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF6FD1C5), Color(0xFF58A7D9)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(40),
                                bottomRight: Radius.circular(40),
                              ),
                            ),
                            child: Column(
                              children: [
                                const CircleAvatar(
                                  radius: 45,
                                  backgroundColor: Colors.white24,
                                  child: Icon(
                                    Icons.groups,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  groupName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$memberCount members',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 20)),

                        // Balance Cards
                        SliverToBoxAdapter(
                          child: BalanceCards(
                            isTablet: isTablet,
                            width: width,
                            toReceive: _youAreOwed,
                            toPay: _youOwe,
                          ),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 24)),

                        // Expenses Section Header
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Expenses',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  '${_filteredExpenses.length} items',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 16)),

                        // ✅ USE ExpenseList WIDGET
                        if (_filteredExpenses.isEmpty)
                          SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 40,
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 60,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No expenses in this category',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          SliverFillRemaining(
                            hasScrollBody: true,
                            child: ExpenseList(
                              expenses: _filteredExpenses,
                              currentUserId: _currentUserId,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/add');
        },
        backgroundColor: const Color(0xFF64C5CC),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Add Expense",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
