import 'package:flutter/material.dart';
import '../../services/settlement_service.dart';
import 'widgets/balanceCard.dart';
import 'widgets/bottomNavBar.dart';
import 'widgets/expenseList.dart';
import 'widgets/paginationButton.dart';
import 'widgets/toggleButton.dart';
import 'widgets/topNavBar.dart';
import '../../services/expense_service.dart';
import '../../services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _currentFilter = 'all';
  int _currentPage = 1;
  bool _isLoading = true;
  List<Map<String, dynamic>> _expenses = [];
  double _toReceive = 0.0;
  double _toPay = 0.0;
  int _totalExpenses = 0;
  String? _userName;
  String? _errorMessage;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadBalance();
    _loadExpenses();
  }

  Future<void> _loadUserData() async {
    try {
      final userInfo = await AuthService.getCurrentUserInfo();
      setState(() {
        _userName = userInfo['name'];
        _currentUserId = userInfo['id'];
      });
      print('✅ User loaded: $_userName, ID: $_currentUserId');
    } catch (e) {
      print('❌ Error loading user data: $e');
    }
  }

  Future<void> _loadBalance() async {
    debugPrint('🔄 Loading balance from SettlementService...');

    final result = await SettlementService.getTotalBalance();

    if (result['success']) {
      setState(() {
        _toReceive = (result['toReceive'] ?? 0.0).toDouble();
        _toPay = (result['toPay'] ?? 0.0).toDouble();
      });

      debugPrint('✅ Balance loaded: Receive=₹$_toReceive, Pay=₹$_toPay');
    } else {
      debugPrint('❌ Failed to load balance: ${result['message']}');

      // Optionally show error to user
      setState(() {
        _errorMessage = result['message'];
      });
    }
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ExpenseService.getUserExpenses(
      filter: _currentFilter,
      page: _currentPage,
      limit: 10,
    );

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      setState(() {
        _expenses = List<Map<String, dynamic>>.from(result['expenses'] ?? []);
        _totalExpenses = result['total'] ?? 0;
      });
      print('✅ Loaded ${_expenses.length} expenses');
    } else {
      setState(() {
        _errorMessage = result['message'];
        _expenses = [];
      });
    }
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _currentFilter = filter.toLowerCase();
      _currentPage = 1;
    });
    _loadExpenses();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadExpenses();
  }

  Future<void> _refreshData() async {
    await _loadUserData();
    await Future.wait([_loadBalance(), _loadExpenses()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAF9),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth > 600;
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            return RefreshIndicator(
              onRefresh: _refreshData,
              color: const Color(0xFF41A67E),
              child: Column(
                children: [
                  // Top Navigation with User Name
                  TopNavbar(userName: _userName),

                  SizedBox(height: height * 0.02),

                  // ✅ RESTORED: Balance Cards with Real Data
                  BalanceCards(
                    isTablet: isTablet,
                    width: width,
                    toReceive: _toReceive,
                    toPay: _toPay,
                  ),

                  SizedBox(height: height * 0.02),

                  // Filter Toggle Buttons
                  ToggleButtonsRow(
                    tabs: const ["All", "Personal", "Instant", "Group"],
                    initialIndex: 0,
                    onTabSelected: (index) {
                      final filters = ["all", "personal", "instant", "group"];
                      _onFilterChanged(filters[index]);
                    },
                  ),

                  SizedBox(height: height * 0.01),

                  // Error Message
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
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
                    ),

                  // Expense List with Real Data
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF41A67E),
                            ),
                          )
                        : _expenses.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 80,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No expenses yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap + to add your first expense',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ExpenseList(
                            expenses: _expenses,
                            currentUserId: _currentUserId,
                          ),
                  ),

                  // Pagination Buttons
                  if (_totalExpenses > 10)
                    PaginationButtons(
                      currentPage: _currentPage,
                      totalPages: (_totalExpenses / 10).ceil(),
                      onPageChanged: _onPageChanged,
                    ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}
