import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/settlement_service.dart';
import '../../services/auth_service.dart';
import '../home/widgets/bottomNavBar.dart';
import '../home/widgets/toggleButton.dart';

class SettlePage extends StatefulWidget {
  const SettlePage({super.key});

  @override
  State<SettlePage> createState() => _SettlePageState();
}

class _SettlePageState extends State<SettlePage> {
  int _selectedToggleIndex = 0;
  List<Map<String, dynamic>> _splitwiseTransactions = [];
  List<Map<String, dynamic>> _friendsList = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadSettlementData();
  }

  Future<void> _loadSettlementData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // ✅ FIX BUG 1: Get current user ID
    _currentUserId = await AuthService.getUserId();
    debugPrint('🔍 [CURRENT-USER] ID: $_currentUserId');

    if (_currentUserId == null || _currentUserId!.isEmpty) {
      setState(() {
        _errorMessage = 'Unable to get user information. Please login again.';
        _isLoading = false;
      });
      return;
    }

    final pendingExpensesResult = await SettlementService.getPendingExpenses();
    if (pendingExpensesResult['success'] != true) {
      setState(() {
        _errorMessage =
            pendingExpensesResult['message'] ?? 'Failed to load settlements';
        _isLoading = false;
      });
      return;
    }

    final pendingExpenses = (pendingExpensesResult['expenses'] as List?) ?? [];
    _splitwiseTransactions = _formatSplitwiseTransactions(
      pendingExpenses.cast<Map<String, dynamic>>(),
    );
    _friendsList = await _formatFriendsListWithNetAmount(
      pendingExpenses.cast<Map<String, dynamic>>(),
    );

    setState(() {
      _isLoading = false;
    });
  }

  // ✅ FIX BUG 1: Filter splits for CURRENT USER ONLY
  List<Map<String, dynamic>> _formatSplitwiseTransactions(
    List<Map<String, dynamic>> expenses,
  ) {
    List<Map<String, dynamic>> transactions = [];

    debugPrint('\n📊 [SPLITWISE] Processing ${expenses.length} expenses');
    debugPrint('🔑 [CURRENT-USER] $_currentUserId\n');

    for (var exp in expenses) {
      try {
        final description = exp['description'] ?? 'Split Payment';
        final expenseId = exp['_id'] ?? '';
        final paidByData = exp['paidBy'];

        // Extract payer info
        final paidByName = paidByData is Map
            ? (paidByData['name'] ?? 'Friend')
            : 'Friend';

        // ✅ Handle BOTH populated object AND plain ID string
        final paidByIdData = paidByData is Map ? paidByData['_id'] : paidByData;
        final paidById = paidByIdData?.toString() ?? '';

        final splitDetails = (exp['splitDetails'] as List?) ?? [];
        final createdAt = exp['createdAt'] ?? DateTime.now().toString();

        debugPrint('💰 Expense: $description (ID: $expenseId)');
        debugPrint('   Paid by: $paidByName (ID: $paidById)');
        debugPrint('   Current user: $_currentUserId');
        debugPrint('   Is current user payer? ${paidById == _currentUserId}');
        debugPrint('   Total splits: ${splitDetails.length}\n');

        // ✅ CASE 1: Current user is the PAYER - show what others owe YOU
        if (paidById == _currentUserId) {
          debugPrint('   📤 You paid this expense - checking who owes you...');

          for (var split in splitDetails) {
            final splitMap = split as Map<String, dynamic>?;

            // Extract split user info - handle BOTH object and string
            final splitUserData = splitMap?['user'];
            final splitUserId = splitUserData is Map
                ? (splitUserData['_id']?.toString() ?? '')
                : (splitUserData?.toString() ?? '');

            final splitUserName = splitUserData is Map
                ? (splitUserData['name'] ?? 'Friend')
                : 'Friend';

            final splitStatus = splitMap?['status'] ?? '';
            final splitId = splitMap?['_id'] ?? '';

            debugPrint(
              '      Split: user=$splitUserId ($splitUserName), status=$splitStatus',
            );

            // Show pending splits from OTHERS (not yourself)
            if (splitStatus == 'pending' &&
                splitUserId != _currentUserId &&
                splitUserId.isNotEmpty) {
              final amountOwed =
                  (splitMap?['amountOwed'] ?? splitMap?['finalShare'] ?? 0.0)
                      .toDouble();

              transactions.add({
                'title': description,
                'subtitle':
                    'Collect from $splitUserName', // ✅ Changed from "Pay to"
                'time': _formatTime(createdAt),
                'amount': amountOwed,
                'date': _formatDate(createdAt),
                'expenseId': expenseId,
                'paidById': splitUserId, // ✅ The person who owes you
                'paidByName': splitUserName,
                'splitId': splitId,
                'type': 'owed_to_you', // ✅ NEW: Mark as money owed TO you
              });

              debugPrint(
                '      ✅ ADDED (owed to you): $description - ₹$amountOwed from $splitUserName\n',
              );
            } else {
              debugPrint(
                '      ⏭️  SKIPPED: ${splitUserId == _currentUserId ? "your own split" : "status=$splitStatus"}\n',
              );
            }
          }
        }
        // ✅ CASE 2: Someone ELSE is the payer - show what YOU owe them
        else {
          debugPrint('   📥 Someone else paid - checking if you owe money...');

          for (var split in splitDetails) {
            final splitMap = split as Map<String, dynamic>?;

            // Extract split user info - handle BOTH object and string
            final splitUserData = splitMap?['user'];
            final splitUserId = splitUserData is Map
                ? (splitUserData['_id']?.toString() ?? '')
                : (splitUserData?.toString() ?? '');

            final splitStatus = splitMap?['status'] ?? '';
            final splitId = splitMap?['_id'] ?? '';

            debugPrint('      Split: user=$splitUserId, status=$splitStatus');

            // ✅ Show only YOUR pending splits (where you owe the payer)
            if (splitStatus == 'pending' && splitUserId == _currentUserId) {
              final amountOwed =
                  (splitMap?['amountOwed'] ?? splitMap?['finalShare'] ?? 0.0)
                      .toDouble();

              transactions.add({
                'title': description,
                'subtitle': 'Pay to $paidByName', // ✅ You owe the payer
                'time': _formatTime(createdAt),
                'amount': amountOwed,
                'date': _formatDate(createdAt),
                'expenseId': expenseId,
                'paidById': paidById, // ✅ The payer you owe
                'paidByName': paidByName,
                'splitId': splitId,
                'type': 'you_owe', // ✅ NEW: Mark as money you owe
              });

              debugPrint(
                '      ✅ ADDED (you owe): $description - ₹$amountOwed to $paidByName\n',
              );
            } else {
              debugPrint(
                '      ⏭️  SKIPPED: ${splitUserId != _currentUserId ? "not your split" : "status=$splitStatus"}\n',
              );
            }
          }
        }
      } catch (e) {
        debugPrint('❌ Error parsing expense: $e\n');
      }
    }

    // Sort by date (newest first)
    transactions.sort((a, b) {
      try {
        final dateA = DateTime.parse(
          (a['date'] as String?) ?? DateTime.now().toString(),
        );
        final dateB = DateTime.parse(
          (b['date'] as String?) ?? DateTime.now().toString(),
        );
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });

    debugPrint('\n📊 [SPLITWISE] Total transactions: ${transactions.length}');
    final owedToYou = transactions
        .where((t) => t['type'] == 'owed_to_you')
        .length;
    final youOwe = transactions.where((t) => t['type'] == 'you_owe').length;
    debugPrint('   Owed to you: $owedToYou');
    debugPrint('   You owe: $youOwe\n');

    return transactions;
  }

  // ✅ FRIENDWISE: Calculate net amounts correctly
  Future<List<Map<String, dynamic>>> _formatFriendsListWithNetAmount(
    List<Map<String, dynamic>> expenses,
  ) async {
    debugPrint('\n👥 [FRIENDWISE] Collecting unique friends...');

    Set<String> uniqueFriendIds = {};
    for (var exp in expenses) {
      try {
        final paidByData = exp['paidBy'];
        final paidById = paidByData is Map ? (paidByData['_id'] ?? '') : '';
        if (paidById.isNotEmpty && paidById != _currentUserId) {
          uniqueFriendIds.add(paidById);
        }

        final splitDetails = (exp['splitDetails'] as List?) ?? [];
        for (var split in splitDetails) {
          final userData = (split is Map) ? split['user'] : null;
          final userId = userData is Map ? (userData['_id'] ?? '') : '';
          if (userId.isNotEmpty && userId != _currentUserId) {
            uniqueFriendIds.add(userId);
          }
        }
      } catch (e) {
        debugPrint('❌ Error collecting friends: $e');
      }
    }

    debugPrint('👥 Found ${uniqueFriendIds.length} unique friends\n');

    List<Map<String, dynamic>> friends = [];
    for (var friendId in uniqueFriendIds) {
      try {
        debugPrint('🔍 [FRIENDWISE] Fetching net amount for: $friendId');
        final netResult = await SettlementService.getNetAmountWithUser(
          friendId: friendId,
        );

        if (netResult['success'] == true) {
          final netAmount = (netResult['netAmount'] as num?)?.toDouble() ?? 0.0;

          debugPrint('   Net amount: $netAmount');

          if (netAmount != 0.0) {
            String friendName = 'Friend';
            for (var exp in expenses) {
              final paidByData = exp['paidBy'];
              if (paidByData is Map && paidByData['_id'] == friendId) {
                friendName = paidByData['name'] ?? friendName;
                break;
              }

              final splitDetails = (exp['splitDetails'] as List?) ?? [];
              for (var split in splitDetails) {
                final userData = (split is Map) ? split['user'] : null;
                if (userData is Map && userData['_id'] == friendId) {
                  friendName =
                      userData['name'] ?? userData['username'] ?? friendName;
                  break;
                }
              }
              if (friendName != 'Friend') break;
            }

            friends.add({
              'friendId': friendId,
              'friendName': friendName,
              'netAmount': netAmount,
              'youOwe': netAmount < 0 ? -netAmount : 0.0,
              'owedToYou': netAmount > 0 ? netAmount : 0.0,
            });
            debugPrint('   ✅ Added: $friendName with net: $netAmount');
          }
        }
      } catch (e) {
        debugPrint('❌ [FRIENDWISE] Error for $friendId: $e');
      }
    }

    friends.sort((a, b) {
      final netA = (a['netAmount'] as double).abs();
      final netB = (b['netAmount'] as double).abs();
      return netB.compareTo(netA);
    });

    debugPrint(
      '\n👥 [FRIENDWISE] Total friends with balance: ${friends.length}\n',
    );
    return friends;
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly == today) return 'Today';
      if (dateOnly == yesterday) return 'Yesterday';
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return 'Today';
    }
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '00:00';
    }
  }

  Future<void> _refreshSettlement() async {
    await _loadSettlementData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => context.go('/'),
        ),
        centerTitle: true,
        title: const Text(
          'Settle Up',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.history, color: Colors.black54),
              onPressed: () => context.push('/payment-management'),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshSettlement,
        color: const Color(0xFF41A67E),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF41A67E)),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
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
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ToggleButtonsRow(
                      tabs: const ['Splitwise', 'Friends'],
                      initialIndex: _selectedToggleIndex,
                      onTabSelected: (index) {
                        setState(() {
                          _selectedToggleIndex = index;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    if (_selectedToggleIndex == 0) ..._buildSplitwiseView(),
                    if (_selectedToggleIndex == 1) ..._buildFriendwiseView(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }

  List<Widget> _buildSplitwiseView() {
    if (_splitwiseTransactions.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.green.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'All settled up!',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return _splitwiseTransactions
        .map((transaction) => _buildLedgerCard(transaction))
        .toList();
  }

  Widget _buildLedgerCard(Map<String, dynamic> transaction) {
    final title = transaction['title'] ?? 'Split';
    final subtitle = transaction['subtitle'] ?? '';
    final time = transaction['time'] ?? '';
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
    final type = transaction['type'] ?? 'you_owe'; // ✅ NEW

    // ✅ Different colors and icons for different types
    final isOwedToYou = type == 'owed_to_you';
    final amountColor = isOwedToYou
        ? const Color(0xFF22C55E) // Green for money owed to you
        : const Color(0xFFDC2626); // Red for money you owe
    final buttonText = isOwedToYou ? 'Collect' : 'Pay';
    final buttonColor = isOwedToYou
        ? const Color(0xFFE8F5E9) // Light green
        : const Color(0xFFEFF4EF); // Light teal

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            // ✅ Allow text to wrap if needed
            child: Row(
              children: [
                // ✅ Different icon based on type
                Icon(
                  isOwedToYou ? Icons.receipt_long : Icons.receipt_long,
                  color: isOwedToYou ? Colors.green : const Color.fromARGB(255, 105, 191, 108),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$subtitle • $time',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: amountColor, // ✅ Different color based on type
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      buttonColor, // ✅ Different color based on type
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  if (isOwedToYou) {
                    // ✅ For amounts owed to you, send reminder
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Reminder sent to ${transaction['paidByName']}',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    // ✅ For amounts you owe, navigate to payment
                    _navigateToPayment(transaction);
                  }
                },
                child: Text(
                  buttonText, // ✅ "Collect" or "Pay"
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFriendwiseView() {
    if (_friendsList.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Icon(
                  Icons.handshake_outlined,
                  size: 64,
                  color: Colors.green.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'All settled up with your friends!',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return _friendsList
        .map((friend) => _buildFriendTransactionCard(friend))
        .toList();
  }

  Widget _buildFriendTransactionCard(Map<String, dynamic> friend) {
    final friendName = (friend['friendName'] as String?) ?? 'Friend';
    final friendId = (friend['friendId'] as String?) ?? '';
    final netAmount = (friend['netAmount'] as double?) ?? 0.0;
    final youOwe = (friend['youOwe'] as double?) ?? 0.0;
    final owedToYou = (friend['owedToYou'] as double?) ?? 0.0;

    final isYouOwe = netAmount < 0;
    final displayAmount = isYouOwe ? youOwe : owedToYou;
    final statusColor = isYouOwe
        ? const Color(0xFFDC2626)
        : const Color(0xFF22C55E);
    final statusIcon = isYouOwe ? Icons.arrow_upward : Icons.arrow_downward;
    final statusText = isYouOwe ? 'You owe' : 'You are owed';
    final actionText = isYouOwe ? 'Pay' : 'Remind';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friendName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${displayAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEFF4EF),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  if (isYouOwe) {
                    _navigateToPaymentFromFriendwise(
                      friendName,
                      youOwe,
                      friendId,
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reminder sent to $friendName')),
                    );
                  }
                },
                child: Text(
                  actionText,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToPayment(Map<String, dynamic> transaction) {
    context.push(
      '/payment/new',
      extra: {
        'payeeName': transaction['paidByName'] ?? 'Friend',
        'amount': (transaction['amount'] as num?)?.toDouble() ?? 0.0,
        'payeeId': transaction['paidById'] ?? '',
        'expenseId': transaction['expenseId'] ?? '',
        'splitId': transaction['splitId'] ?? '',
        'source': 'splitwise',
      },
    );
  }

  void _navigateToPaymentFromFriendwise(
    String name,
    double amount,
    String friendId,
  ) {
    context.push(
      '/payment/new',
      extra: {
        'payeeName': name,
        'amount': amount,
        'payeeId': friendId,
        'source': 'friendwise',
      },
    );
  }
}
