import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../services/payment_service.dart';
import 'payment_success_page.dart';

class PaymentExecutionPage extends StatefulWidget {
  final String payeeName;
  final double amount;
  final String payeeId;
  final String? expenseId;
  final String source;
  final String paymentMethod; // 'upi_intent', 'upi_qr', or 'cash'

  const PaymentExecutionPage({
    super.key,
    required this.payeeName,
    required this.amount,
    required this.payeeId,
    this.expenseId,
    required this.source,
    required this.paymentMethod,
  });

  @override
  State<PaymentExecutionPage> createState() => _PaymentExecutionPageState();
}

class _PaymentExecutionPageState extends State<PaymentExecutionPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool isLoading = false;
  bool paymentCompleted = false;
  bool isSubmitting = false;
  String? errorMessage;
  String upiIntent = '';
  final TextEditingController transactionIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animationController.forward();

    // Fetch payee details with amount for UPI/QR
    if (widget.paymentMethod == 'upi_intent' ||
        widget.paymentMethod == 'upi_qr') {
      _fetchPayeeDetailsWithAmount();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    transactionIdController.dispose();
    super.dispose();
  }

  Future<void> _fetchPayeeDetailsWithAmount() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final response = await PaymentService.getPayeeDetails(
      widget.payeeId,
      amount: widget.amount,
    );

    if (response['success'] == true) {
      upiIntent = response['upiIntent'] ?? "";
      setState(() {
        isLoading = false;
      });
      if (widget.paymentMethod == 'upi_intent') {
        _launchUpiIntent();
      }
    } else {
      setState(() {
        errorMessage = response['message'] ?? 'Failed to load payee details';
        isLoading = false;
      });
    }
  }

  Future<void> _launchUpiIntent() async {
    if (upiIntent.isEmpty) return;
    final uri = Uri.parse(upiIntent);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _submitPayment() async {
    if (isSubmitting) return;
    setState(() => isSubmitting = true);

    final response = await PaymentService.submitPayment(
      payeeId: widget.payeeId,
      expenseId: widget.expenseId,
      amount: widget.expenseId == null ? widget.amount : null,
      method: widget.paymentMethod == 'cash' ? 'cash' : 'upi',
      transactionId: transactionIdController.text.trim().isEmpty
          ? null
          : transactionIdController.text.trim(),
      note: 'Payment via ${widget.paymentMethod}',
    );

    setState(() => isSubmitting = false);

    if (response['success']) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PaymentSuccessPage(
              payeeName: widget.payeeName,
              amount: widget.amount,
              paymentMethod: widget.paymentMethod,
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to submit payment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final cardMaxWidth = isSmallScreen ? size.width - 32 : 480.0;
    final horizontalPadding = isSmallScreen ? 16.0 : 32.0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF41A67E).withOpacity(0.1),
              const Color(0xFFF8F9FA),
              const Color(0xFF41A67E).withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: isLoading
                    ? _buildLoadingState()
                    : errorMessage != null
                    ? _buildErrorState()
                    : Center(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: FadeTransition(
                            opacity: _animationController,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: cardMaxWidth,
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: horizontalPadding,
                              ),
                              child: Column(
                                children: [
                                  const SizedBox(height: 20),
                                  _buildMethodContent(),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Color(0xFF41A67E),
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: Text(
              _getMethodTitle(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D3748),
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  String _getMethodTitle() {
    switch (widget.paymentMethod) {
      case 'upi_intent':
        return 'UPI Payment';
      case 'upi_qr':
        return 'Scan QR Code';
      case 'cash':
        return 'Cash Payment';
      default:
        return 'Payment';
    }
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFF41A67E)),
          ),
          SizedBox(height: 20),
          Text(
            'Loading payment details...',
            style: TextStyle(fontSize: 16, color: Color(0xFF2D3748)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              errorMessage ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Color(0xFF2D3748)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF41A67E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodContent() {
    switch (widget.paymentMethod) {
      case 'upi_intent':
        return _buildUpiIntentContent();
      case 'upi_qr':
        return _buildUpiQrContent();
      case 'cash':
        return _buildCashContent();
      default:
        return const SizedBox();
    }
  }

  Widget _buildUpiIntentContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_iphone_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'UPI App Launched',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Complete the payment in your UPI app',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _launchUpiIntent,
            icon: const Icon(Icons.refresh),
            label: const Text('Reopen UPI App'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF41A67E),
              side: const BorderSide(color: Color(0xFF41A67E)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: paymentCompleted,
            onChanged: (val) => setState(() => paymentCompleted = val ?? false),
            title: const Text(
              "I've completed the payment",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3748),
              ),
            ),
            activeColor: const Color(0xFF41A67E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          if (paymentCompleted) ...[
            const SizedBox(height: 16),
            TextField(
              controller: transactionIdController,
              decoration: InputDecoration(
                labelText: 'Transaction ID (Optional)',
                hintText: 'e.g., UPI1234567890',
                prefixIcon: const Icon(
                  Icons.receipt_long,
                  color: Color(0xFF41A67E),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF41A67E),
                    width: 2,
                  ),
                ),
              ),
              maxLength: 30,
            ),
            const SizedBox(height: 8),
            Text(
              'Find this in your UPI transaction history',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: paymentCompleted && !isSubmitting
                  ? _submitPayment
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF41A67E),
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text(
                      'Submit Payment',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpiQrContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Scan QR Code',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 24),
          if (upiIntent.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF41A67E), width: 2),
              ),
              child: QrImageView(
                data: upiIntent,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
              ),
            )
          else
            Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFF41A67E)),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'Scan with any UPI app to pay ₹${widget.amount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: paymentCompleted,
            onChanged: (val) => setState(() => paymentCompleted = val ?? false),
            title: const Text(
              "I've completed the payment",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3748),
              ),
            ),
            activeColor: const Color(0xFF41A67E),
          ),
          if (paymentCompleted) ...[
            const SizedBox(height: 16),
            TextField(
              controller: transactionIdController,
              decoration: InputDecoration(
                labelText: 'Transaction ID (Optional)',
                hintText: 'e.g., UPI1234567890',
                prefixIcon: const Icon(
                  Icons.receipt_long,
                  color: Color(0xFF41A67E),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLength: 30,
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: paymentCompleted && !isSubmitting
                  ? _submitPayment
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF41A67E),
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text(
                      'Submit Payment',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF093FB), Color(0xFFF5576C)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.money_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Cash Payment',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Hand over ₹${widget.amount.toStringAsFixed(0)} to ${widget.payeeName}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 32),
          Text(
            'After handing over the cash, tap below to notify ${widget.payeeName}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: !isSubmitting ? _submitPayment : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF41A67E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text(
                      'Mark as Paid',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
