import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/payment_service.dart';
import '../home/widgets/toggleButton.dart';

class PaymentManagementPage extends StatefulWidget {
  const PaymentManagementPage({super.key});

  @override
  State<PaymentManagementPage> createState() => _PaymentManagementPageState();
}

class _PaymentManagementPageState extends State<PaymentManagementPage> {
  int selectedTab = 0; // 0 = Incoming Requests, 1 = Outgoing Requests
  bool isLoading = false;

  // Incoming: Payments I need to confirm (as payee)
  List<Map<String, dynamic>> incomingPendingPayments = [];
  List<Map<String, dynamic>> incomingHistoryPayments = [];

  // Outgoing: Payments I need to pay (as payer)
  List<Map<String, dynamic>> outgoingPendingPayments = [];
  List<Map<String, dynamic>> outgoingHistoryPayments = [];

  @override
  void initState() {
    super.initState();
    _loadAllPayments();
  }

  Future<void> _loadAllPayments() async {
    setState(() => isLoading = true);

    // Load incoming payments (to confirm)
    final incomingResponse = await PaymentService.getPendingPaymentsToConfirm();
    if (incomingResponse['success']) {
      incomingPendingPayments = List<Map<String, dynamic>>.from(
        incomingResponse['payments'] ?? [],
      );
    }

    // Load outgoing payments (to pay)
    final outgoingResponse = await PaymentService.getPendingPaymentsToPay();
    if (outgoingResponse['success']) {
      outgoingPendingPayments = List<Map<String, dynamic>>.from(
        outgoingResponse['payments'] ?? [],
      );
    }

    // TODO: Add history API endpoints if available
    incomingHistoryPayments = [];
    outgoingHistoryPayments = [];

    setState(() => isLoading = false);
  }

  // ============================================
  // INCOMING ACTIONS (Confirm/Reject)
  // ============================================
  Future<void> _confirmIncomingPayment(String paymentId) async {
    final response = await PaymentService.verifyPayment(
      paymentId: paymentId,
      verified: true,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(response['message'] ?? 'Payment confirmed'),
          ],
        ),
        backgroundColor: response['success']
            ? const Color(0xFF41A67E)
            : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );

    if (response['success']) {
      _loadAllPayments();
    }
  }

  Future<void> _rejectIncomingPayment(String paymentId) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.cancel_outlined, color: Color(0xFFE53935)),
            SizedBox(width: 12),
            Text('Reject Payment'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Why are you rejecting this payment?',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g., Already paid, Wrong amount',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF41A67E)),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Rejecting payment...'),
            ],
          ),
          duration: const Duration(seconds: 30),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }

    try {
      final reason = reasonController.text.trim();

      debugPrint('[PAYMENT_MGMT] Rejecting payment: $paymentId');
      debugPrint(
        '[PAYMENT_MGMT] Rejection reason: ${reason.isEmpty ? "None" : reason}',
      );

      final response = await PaymentService.verifyPayment(
        paymentId: paymentId,
        verified: false,
        rejectionReason: reason.isEmpty ? null : reason,
      );

      debugPrint('[PAYMENT_MGMT] Response: $response');

      if (!mounted) return;

      // Dismiss loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(response['message'] ?? 'Payment rejected successfully'),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
        _loadAllPayments();
      } else {
        final errorMessage = response['message'] ?? 'Failed to reject payment';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _rejectIncomingPayment(paymentId),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[PAYMENT_MGMT] Exception during reject: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ============================================
  // OUTGOING ACTIONS (Cancel)
  // ============================================
  Future<void> _cancelOutgoingPayment(String paymentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9800)),
            SizedBox(width: 12),
            Text('Cancel Payment'),
          ],
        ),
        content: const Text(
          'Are you sure you want to cancel this payment request?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final response = await PaymentService.cancelPayment(paymentId);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              response['success'] ? Icons.info_outline : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(response['message'] ?? 'Payment cancelled'),
          ],
        ),
        backgroundColor: response['success'] ? Colors.orange : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );

    if (response['success']) {
      _loadAllPayments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Payment Requests",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.black12, height: 1),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),

          /// Toggle Buttons (Incoming / Outgoing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ToggleButtonsRow(
              tabs: const ["Incoming", "Outgoing"],
              initialIndex: selectedTab,
              onTabSelected: (index) {
                setState(() {
                  selectedTab = index;
                });
              },
            ),
          ),

          const SizedBox(height: 20),

          /// Content
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF41A67E)),
                  )
                : RefreshIndicator(
                    onRefresh: _loadAllPayments,
                    color: const Color(0xFF41A67E),
                    child: selectedTab == 0
                        ? _buildIncomingTab()
                        : _buildOutgoingTab(),
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // INCOMING TAB (Payments to Confirm)
  // ============================================
  Widget _buildIncomingTab() {
    if (incomingPendingPayments.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  "No incoming payment requests",
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: incomingPendingPayments.length,
      itemBuilder: (context, index) {
        final payment = incomingPendingPayments[index];
        return IncomingRequestCard(
          key: ValueKey(payment['_id']),
          payment: payment,
          onConfirm: () => _confirmIncomingPayment(payment['_id']),
          onReject: () => _rejectIncomingPayment(payment['_id']),
        );
      },
    );
  }

  // ============================================
  // OUTGOING TAB (Payments to Pay)
  // ============================================
  Widget _buildOutgoingTab() {
    if (outgoingPendingPayments.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.send_outlined,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  "No outgoing payment requests",
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: outgoingPendingPayments.length,
      itemBuilder: (context, index) {
        final payment = outgoingPendingPayments[index];
        return OutgoingRequestCard(
          key: ValueKey(payment['_id']),
          payment: payment,
          onCancel: () => _cancelOutgoingPayment(payment['_id']),
        );
      },
    );
  }
}

// ================================================================
// INCOMING REQUEST CARD (Payee View - Confirm/Reject)
// ================================================================
class IncomingRequestCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  const IncomingRequestCard({
    super.key,
    required this.payment,
    required this.onConfirm,
    required this.onReject,
  });

  String _formatTimeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Recently';

    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';

      return DateFormat('MMM d').format(date);
    } catch (e) {
      return 'Recently';
    }
  }

  String _getPaymentDescription() {
    final relatedExpenses = payment['relatedExpenses'] as List?;
    if (relatedExpenses != null && relatedExpenses.isNotEmpty) {
      final firstExpense = relatedExpenses[0] as Map<String, dynamic>?;
      return firstExpense?['description'] ?? 'Expense payment';
    }

    final note = payment['note'] as String?;
    if (note != null && note.isNotEmpty) {
      return note;
    }

    return 'Direct payment';
  }

  @override
  Widget build(BuildContext context) {
    final payer = payment['payer'] as Map<String, dynamic>?;
    final payerName = payer?['name'] ?? 'Unknown User';
    final amount = (payment['amount'] ?? 0).toDouble();
    final createdAt = payment['createdAt'] as String?;
    final description = _getPaymentDescription();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF41A67E).withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              /// Avatar with gradient
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF41A67E), Color(0xFF5CC8A8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF41A67E).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    payerName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              /// Text Section - IMPROVED TITLE
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ NEW FORMAT: "Akshat paid ₹500 for Dinner"
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                        children: [
                          TextSpan(
                            text: payerName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const TextSpan(text: ' paid '),
                          TextSpan(
                            text: '₹${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF41A67E),
                            ),
                          ),
                          const TextSpan(text: ' for '),
                          TextSpan(
                            text: description,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimeAgo(createdAt),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          /// Action Buttons Row
          Row(
            children: [
              Expanded(child: _rejectButton(onReject)),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _confirmButton(onConfirm)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rejectButton(VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.close_rounded, size: 18, color: Color(0xFFE53935)),
              SizedBox(width: 6),
              Text(
                'Reject',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE53935),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _confirmButton(VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF41A67E), Color(0xFF5CC8A8)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF41A67E).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Confirm Payment',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// OUTGOING REQUEST CARD (Payer View - Cancel)
// ================================================================
class OutgoingRequestCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final VoidCallback onCancel;

  const OutgoingRequestCard({
    super.key,
    required this.payment,
    required this.onCancel,
  });

  String _formatTimeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Recently';

    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';

      return DateFormat('MMM d').format(date);
    } catch (e) {
      return 'Recently';
    }
  }

  String _getPaymentDescription() {
    final relatedExpenses = payment['relatedExpenses'] as List?;
    if (relatedExpenses != null && relatedExpenses.isNotEmpty) {
      final firstExpense = relatedExpenses[0] as Map<String, dynamic>?;
      return firstExpense?['description'] ?? 'Expense payment';
    }

    final note = payment['note'] as String?;
    if (note != null && note.isNotEmpty) {
      return note;
    }

    return 'Direct payment';
  }

  @override
  Widget build(BuildContext context) {
    final payee = payment['payee'] as Map<String, dynamic>?;
    final payeeName = payee?['name'] ?? 'Unknown User';
    final amount = (payment['amount'] ?? 0).toDouble();
    final createdAt = payment['createdAt'] as String?;
    final description = _getPaymentDescription();
    final status = payment['status'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF5B8DEE).withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          /// Avatar with gradient
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5B8DEE), Color(0xFF8AB4F8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5B8DEE).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                payeeName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          /// Text Section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                    children: [
                      const TextSpan(text: 'Pay '),
                      TextSpan(
                        text: payeeName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: '₹${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5B8DEE),
                        ),
                      ),
                      const TextSpan(text: ' for '),
                      TextSpan(
                        text: description,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTimeAgo(createdAt),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          /// Right side: Status/Cancel
          if (status == 'pending')
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onCancel,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE5E5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.cancel_outlined,
                        size: 16,
                        color: Color(0xFFE53935),
                      ),
                      SizedBox(width: 4),
                      Text(
                        "Cancel",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE53935),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStatusText(status),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF41A67E);
      case 'rejected':
        return const Color(0xFFE53935);
      case 'cancelled':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmed';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }
}
