// lib/pages/payment/payment_method_selection_page.dart - METHOD SELECTION PAGE

import 'package:flutter/material.dart';
import 'payment_execution.dart';

class PaymentMethodSelectionPage extends StatefulWidget {
  final String payeeName;
  final double amount;
  final String payeeId;
  final String? expenseId;
  final String source;

  const PaymentMethodSelectionPage({
    super.key,
    required this.payeeName,
    required this.amount,
    required this.payeeId,
    this.expenseId,
    required this.source,
  });

  @override
  State<PaymentMethodSelectionPage> createState() => _PaymentMethodSelectionPageState();
}

class _PaymentMethodSelectionPageState extends State<PaymentMethodSelectionPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  String? _selectedMethod;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _selectMethod(String method) {
    setState(() => _selectedMethod = method);
    
    // Small delay for visual feedback
    Future.delayed(const Duration(milliseconds: 200), () {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => PaymentExecutionPage(
            payeeName: widget.payeeName,
            amount: widget.amount,
            payeeId: widget.payeeId,
            expenseId: widget.expenseId,
            source: widget.source,
            paymentMethod: method,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(position: animation.drive(tween), child: child);
          },
        ),
      );
    });
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
              // App Bar
              _buildAppBar(context),
              
              // Main Content
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Container(
                      constraints: BoxConstraints(maxWidth: cardMaxWidth),
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          
                          // Header Section
                          _buildHeaderSection(),
                          
                          const SizedBox(height: 40),
                          
                          // Payment Method Options
                          _buildMethodOption(
                            icon: Icons.phone_iphone_rounded,
                            title: 'UPI Intent',
                            subtitle: 'Pay directly via UPI app',
                            gradient: [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                            method: 'upi_intent',
                            delay: 0,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          _buildMethodOption(
                            icon: Icons.qr_code_2_rounded,
                            title: 'Scan QR Code',
                            subtitle: 'Scan with any UPI app',
                            gradient: [const Color(0xFF41A67E), const Color(0xFF35916B)],
                            method: 'upi_qr',
                            delay: 100,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          _buildMethodOption(
                            icon: Icons.money_rounded,
                            title: 'Cash Payment',
                            subtitle: 'Pay in cash manually',
                            gradient: [const Color(0xFFF093FB), const Color(0xFFF5576C)],
                            method: 'cash',
                            delay: 200,
                          ),
                          
                          const SizedBox(height: 40),
                        ],
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
              icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF41A67E), size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const Expanded(
            child: Text(
              'Select Payment Method',
              textAlign: TextAlign.center,
              style: TextStyle(
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

  Widget _buildHeaderSection() {
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
          Text(
            'Choose how you want to pay',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '₹',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF41A67E),
                  ),
                ),
              ),
              Text(
                widget.amount.toStringAsFixed(widget.amount.truncateToDouble() == widget.amount ? 0 : 2),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF41A67E),
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'to ${widget.payeeName}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required String method,
    required int delay,
  }) {
    final isSelected = _selectedMethod == method;
    
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(delay / 300, 1.0, curve: Curves.easeOut),
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(delay / 300, 1.0, curve: Curves.easeOut),
          ),
        ),
        child: AnimatedScale(
          scale: isSelected ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: gradient[0].withOpacity(0.3),
                  blurRadius: isSelected ? 25 : 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _selectMethod(method),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(icon, size: 32, color: Colors.white),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
