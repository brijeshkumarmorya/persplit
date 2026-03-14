// // payment_page.dart - FIXED UPI VALIDATION

// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:url_launcher/url_launcher.dart';
// import '../../services/payment_service.dart';

// class PaymentPage extends StatefulWidget {
//   final String payeeName;
//   final double amount;
//   final String payeeId;
//   final String? expenseId;
//   final String source;

//   const PaymentPage({
//     super.key,
//     required this.payeeName,
//     required this.amount,
//     required this.payeeId,
//     this.expenseId,
//     required this.source,
//   });

//   @override
//   State<PaymentPage> createState() => _PaymentPageState();
// }

// class _PaymentPageState extends State<PaymentPage> {
//   late PaymentService _paymentService;
//   String _paymentId = '';
//   String _paymentStatus = 'created';
//   String _upiIntent = '';
//   Uint8List? _qrImageBytes;
//   String _qrDataUrl = '';
//   String? _errorMessage;
//   bool _isLoading = false;
//   bool _paymentCompleted = false;
//   bool _showTransactionIdInput = false;
//   bool _isSubmittingProof = false;
//   bool _upiIdMissing = false; // NEW: Track if UPI ID is missing
//   final TextEditingController _transactionIdController =
//       TextEditingController();

//   String _selectedMethod = 'upi';
//   final List<String> _paymentMethods = ['upi', 'cash'];

//   @override
//   void initState() {
//     super.initState();
//     _paymentService = PaymentService();
//     _initializePayment();
//   }

//   // Helper method to check if UPI intent is valid
//   bool _isValidUpiIntent(String? upi) {
//     if (upi == null || upi.isEmpty) return false;
//     if (upi == 'N/A' || upi.toLowerCase() == 'null') return false;
//     if (upi.length < 7) return false;
//     if (!upi.contains('upi://pay')) return false;
//     return true;
//   }

//   Future<void> _initializePayment() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//       _paymentStatus = 'created';
//       _paymentId = '';
//       _upiIntent = '';
//       _qrImageBytes = null;
//       _qrDataUrl = '';
//       _paymentCompleted = false;
//       _showTransactionIdInput = false;
//       _isSubmittingProof = false;
//       _upiIdMissing = false;
//     });

//     try {
//       final response = await PaymentService.createPayment(
//         payeeId: widget.payeeId,
//         expenseId: widget.expenseId,
//         amount: widget.amount > 0 ? widget.amount : null,
//         method: _selectedMethod,
//         source: widget.source,
//       );

//       if (response['success']) {
//         final payment = response['payment'] as Map;
//         Uint8List? qrBytes;
//         String qrData = payment['qrData'] ?? '';
//         String upiIntent = payment['upiIntent'] ?? '';

//         // Decode QR if available
//         if (qrData.isNotEmpty && qrData != 'N/A') {
//           try {
//             String base64String = qrData;
//             if (qrData.contains('base64,')) {
//               base64String = qrData.split('base64,')[1];
//             }
//             qrBytes = base64Decode(base64String);
//           } catch (e) {
//             debugPrint('QR decode error: $e');
//           }
//         }

//         // Check if UPI intent is valid
//         bool validUpi = _isValidUpiIntent(upiIntent);

//         setState(() {
//           _paymentId = payment['_id'] ?? '';
//           _paymentStatus = payment['status'] ?? 'created';
//           _upiIntent = upiIntent;
//           _qrDataUrl = qrData;
//           _qrImageBytes = qrBytes;
//           _isLoading = false;
//           _errorMessage = null;
//           _upiIdMissing = !validUpi && _selectedMethod == 'upi';
//         });

//         if (mounted && !_upiIdMissing) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: const Text('✅ Payment ready'),
//               backgroundColor: Colors.green.shade600,
//               duration: const Duration(seconds: 2),
//             ),
//           );
//         }
//       } else {
//         // Backend returned error
//         String errorMsg = response['message'] ?? 'Failed to initialize payment';

//         // Check if it's UPI ID error
//         bool isUpiError =
//             errorMsg.toLowerCase().contains('upi') &&
//             errorMsg.toLowerCase().contains('set');

//         setState(() {
//           _isLoading = false;
//           _errorMessage = errorMsg;
//           _upiIdMissing = isUpiError;
//         });

//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(errorMsg),
//               backgroundColor: Colors.red.shade600,
//               duration: const Duration(seconds: 3),
//             ),
//           );
//         }
//       }
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//         _errorMessage = 'Network error, please try again.';
//       });
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: const Text('Network error, please try again.'),
//             backgroundColor: Colors.red.shade600,
//           ),
//         );
//       }
//     }
//   }

//   Future<void> _openUPILink() async {
//     if (!_isValidUpiIntent(_upiIntent)) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text('UPI Link not available'),
//           backgroundColor: Colors.red.shade600,
//         ),
//       );
//       return;
//     }

//     try {
//       final uri = Uri.parse(_upiIntent);
//       if (await canLaunchUrl(uri)) {
//         await launchUrl(uri, mode: LaunchMode.externalApplication);
//       } else {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: const Text('Could not open UPI app'),
//               backgroundColor: Colors.red.shade600,
//             ),
//           );
//         }
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Could not open UPI app: $e'),
//             backgroundColor: Colors.red.shade600,
//           ),
//         );
//       }
//     }
//   }

//   Future<void> _markPaymentComplete() async {
//     if (_selectedMethod == 'upi') {
//       if (_transactionIdController.text.trim().isEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: const Text('Please enter transaction ID'),
//             backgroundColor: Colors.orange.shade600,
//           ),
//         );
//         return;
//       }
//     }

//     setState(() {
//       _isSubmittingProof = true;
//     });

//     try {
//       final response = await PaymentService.submitPaymentProof(
//         paymentId: _paymentId,
//         transactionId: _selectedMethod == 'cash'
//             ? 'cash_paid'
//             : _transactionIdController.text.trim(),
//       );

//       if (response['success']) {
//         final payment = response['payment'] as Map;
//         setState(() {
//           _paymentStatus = payment['status'] ?? 'pending';
//           _paymentCompleted = true;
//           _isSubmittingProof = false;
//           _showTransactionIdInput = false;
//         });

//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: const Text(
//                 '✅ Payment submitted! Waiting for confirmation...',
//               ),
//               backgroundColor: Colors.green.shade600,
//               duration: const Duration(seconds: 3),
//             ),
//           );
//           Future.delayed(const Duration(milliseconds: 500), () {
//             if (mounted) _displayPaymentPendingDialog();
//           });
//         }
//       } else {
//         setState(() {
//           _isSubmittingProof = false;
//         });
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 response['message'] ?? 'Failed to submit payment proof',
//               ),
//               backgroundColor: Colors.red.shade600,
//             ),
//           );
//         }
//       }
//     } catch (e) {
//       setState(() {
//         _isSubmittingProof = false;
//       });
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error: $e'),
//             backgroundColor: Colors.red.shade600,
//           ),
//         );
//       }
//     }
//   }

//   Future<void> _cancelPayment() async {
//     final confirmed = await showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         title: const Text('Cancel Payment?'),
//         content: const Text('Are you sure you want to cancel this payment?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text('No', style: TextStyle(color: Colors.grey)),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(context, true),
//             child: const Text('Yes', style: TextStyle(color: Colors.red)),
//           ),
//         ],
//       ),
//     );

//     if (confirmed != true) return;

//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       final response = await PaymentService.cancelPayment(
//         paymentId: _paymentId,
//       );

//       if (response['success']) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: const Text('Payment cancelled'),
//               backgroundColor: Colors.orange.shade600,
//             ),
//           );
//           context.pop();
//         }
//       } else {
//         setState(() {
//           _isLoading = false;
//         });
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(response['message'] ?? 'Failed to cancel payment'),
//               backgroundColor: Colors.red.shade600,
//             ),
//           );
//         }
//       }
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//       });
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error: $e'),
//             backgroundColor: Colors.red.shade600,
//           ),
//         );
//       }
//     }
//   }

//   void _displayPaymentPendingDialog() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => Dialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         child: Container(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.blue.shade100,
//                   shape: BoxShape.circle,
//                 ),
//                 child: Icon(
//                   Icons.hourglass_top,
//                   size: 48,
//                   color: Colors.blue.shade700,
//                 ),
//               ),
//               const SizedBox(height: 16),
//               const Text(
//                 'Payment Submitted',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.black87,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 'Waiting for ${widget.payeeName} to verify your payment...',
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   color: Colors.black54,
//                   height: 1.5,
//                 ),
//               ),
//               const SizedBox(height: 24),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () {
//                     Navigator.pop(context);
//                     context.pop();
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF41A67E),
//                     padding: const EdgeInsets.symmetric(vertical: 12),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                   ),
//                   child: const Text(
//                     'Done',
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   void _displayQRFullScreen() {
//     if (_qrImageBytes == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text('QR Code not available'),
//           backgroundColor: Colors.red.shade600,
//         ),
//       );
//       return;
//     }

//     showDialog(
//       context: context,
//       builder: (context) => Dialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         child: Container(
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Text(
//                 'Scan to Pay',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.black87,
//                 ),
//               ),
//               const SizedBox(height: 20),
//               Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   border: Border.all(color: Colors.grey.shade300),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: GestureDetector(
//                   onTap: () => Navigator.pop(context),
//                   child: Image.memory(
//                     _qrImageBytes!,
//                     width: 280,
//                     height: 280,
//                     fit: BoxFit.contain,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               Text(
//                 'Tap to close • Scan with any UPI app',
//                 style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
//               ),
//               const SizedBox(height: 16),
//               Text(
//                 '₹${widget.amount.toStringAsFixed(2)} to ${widget.payeeName}',
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.black87,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final mediaWidth = MediaQuery.of(context).size.width;
//     double cardMaxWidth = mediaWidth < 600 ? mediaWidth - 32 : 480;
//     double paddingSize = mediaWidth < 600 ? 12.0 : 32.0;

//     return WillPopScope(
//       onWillPop: () async {
//         if (_paymentStatus == 'pending' || _paymentStatus == 'confirmed') {
//           return false;
//         }
//         return true;
//       },
//       child: Scaffold(
//         backgroundColor: const Color(0xFFF8F9FA),
//         appBar: AppBar(
//           backgroundColor: Colors.white,
//           elevation: 0.5,
//           leading: _paymentStatus != 'pending' && _paymentStatus != 'confirmed'
//               ? IconButton(
//                   icon: const Icon(
//                     Icons.arrow_back_ios_new,
//                     color: Colors.black87,
//                   ),
//                   onPressed: () => context.pop(),
//                 )
//               : null,
//           centerTitle: true,
//           title: const Text(
//             'Payment Details',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.w600,
//               color: Colors.black87,
//             ),
//           ),
//         ),
//         body: _isLoading
//             ? Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const CircularProgressIndicator(color: Color(0xFF41A67E)),
//                     const SizedBox(height: 16),
//                     const Text(
//                       'Initializing payment...',
//                       style: TextStyle(fontSize: 16, color: Colors.black54),
//                     ),
//                   ],
//                 ),
//               )
//             : Center(
//                 child: SingleChildScrollView(
//                   child: Center(
//                     child: ConstrainedBox(
//                       constraints: BoxConstraints(maxWidth: cardMaxWidth),
//                       child: Padding(
//                         padding: EdgeInsets.all(paddingSize),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             _buildPaymentCard(),
//                             const SizedBox(height: 24),
//                             _buildPaymentMethodSelector(),
//                             const SizedBox(height: 24),
//                             if (_paymentStatus == 'created') ...[
//                               _buildPaymentMethodsSection(),
//                             ],
//                             if (_paymentStatus == 'pending') ...[
//                               _buildPendingSection(),
//                             ],
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//       ),
//     );
//   }

//   Widget _buildPaymentCard() {
//     return Container(
//       padding: const EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.08),
//             blurRadius: 16,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           CircleAvatar(
//             radius: 52,
//             backgroundColor: const Color(0xFF41A67E).withOpacity(0.12),
//             child: Text(
//               widget.payeeName[0].toUpperCase(),
//               style: const TextStyle(
//                 fontSize: 36,
//                 fontWeight: FontWeight.w700,
//                 color: Color(0xFF41A67E),
//               ),
//             ),
//           ),
//           const SizedBox(height: 20),
//           Text(
//             'Pay ${widget.payeeName}',
//             style: const TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.w500,
//               color: Colors.black54,
//             ),
//           ),
//           const SizedBox(height: 12),
//           RichText(
//             text: TextSpan(
//               children: [
//                 const TextSpan(
//                   text: '₹',
//                   style: TextStyle(
//                     fontSize: 32,
//                     fontWeight: FontWeight.w600,
//                     color: Color(0xFF41A67E),
//                   ),
//                 ),
//                 TextSpan(
//                   text: widget.amount.toStringAsFixed(0),
//                   style: const TextStyle(
//                     fontSize: 48,
//                     fontWeight: FontWeight.w700,
//                     color: Color(0xFF41A67E),
//                   ),
//                 ),
//                 if (widget.amount.toString().contains('.'))
//                   TextSpan(
//                     text: '.${widget.amount.toString().split('.')[1]}',
//                     style: const TextStyle(
//                       fontSize: 28,
//                       fontWeight: FontWeight.w600,
//                       color: Color(0xFF41A67E),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 16),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             decoration: BoxDecoration(
//               color: const Color(0xFFEFF4EF),
//               borderRadius: BorderRadius.circular(20),
//             ),
//             child: Text(
//               widget.source == 'splitwise' ? '💰 Splitwise' : '👥 Friendwise',
//               style: const TextStyle(
//                 fontSize: 13,
//                 fontWeight: FontWeight.w600,
//                 color: Color(0xFF41A67E),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPaymentMethodSelector() {
//     return Row(
//       children: _paymentMethods.map((method) {
//         final isSelected = _selectedMethod == method;
//         return Expanded(
//           child: GestureDetector(
//             onTap: () {
//               if (!isSelected) {
//                 setState(() {
//                   _selectedMethod = method;
//                   _transactionIdController.clear();
//                   _initializePayment();
//                 });
//               }
//             },
//             child: Container(
//               margin: const EdgeInsets.symmetric(horizontal: 6),
//               padding: const EdgeInsets.symmetric(vertical: 14),
//               decoration: BoxDecoration(
//                 color: isSelected
//                     ? const Color(0xFF41A67E).withOpacity(0.10)
//                     : Colors.white,
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(
//                   color: isSelected
//                       ? const Color(0xFF41A67E)
//                       : Colors.grey.shade300,
//                   width: isSelected ? 2 : 1.2,
//                 ),
//               ),
//               child: Center(
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(
//                       method == 'upi' ? Icons.phone_iphone : Icons.money,
//                       color: isSelected
//                           ? const Color(0xFF41A67E)
//                           : Colors.grey.shade600,
//                       size: 22,
//                     ),
//                     const SizedBox(width: 8),
//                     Text(
//                       method.toUpperCase(),
//                       style: TextStyle(
//                         fontWeight: FontWeight.w700,
//                         fontSize: 15,
//                         color: isSelected
//                             ? const Color(0xFF41A67E)
//                             : Colors.grey.shade800,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         );
//       }).toList(),
//     );
//   }

//   Widget _buildPaymentMethodsSection() {
//     if (_selectedMethod == 'upi') {
//       // Check if UPI ID is missing/invalid
//       if (_upiIdMissing || !_isValidUpiIntent(_upiIntent)) {
//         return Container(
//           margin: const EdgeInsets.only(top: 8, bottom: 8),
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: Colors.orange.shade50,
//             border: Border.all(color: Colors.orange.shade200, width: 1.3),
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Icon(
//                     Icons.warning_amber,
//                     color: Colors.orange.shade800,
//                     size: 28,
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           'UPI ID not set properly',
//                           style: TextStyle(
//                             color: Colors.orange.shade900,
//                             fontSize: 15,
//                             fontWeight: FontWeight.w700,
//                           ),
//                         ),
//                         const SizedBox(height: 6),
//                         Text(
//                           'To make the payment, ${widget.payeeName} must first set up their UPI ID in their profile.',
//                           style: TextStyle(
//                             color: Colors.orange.shade800,
//                             fontSize: 13,
//                             fontWeight: FontWeight.w500,
//                             height: 1.4,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 14),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () => context.pop(),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.orange.shade700,
//                     elevation: 0,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                   ),
//                   child: const Text(
//                     'Go Back',
//                     style: TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       }

//       // UPI ID exists, show payment options
//       return Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Payment Method',
//             style: TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.w600,
//               color: Colors.black87,
//             ),
//           ),
//           const SizedBox(height: 16),
//           SizedBox(
//             width: double.infinity,
//             height: 56,
//             child: ElevatedButton.icon(
//               onPressed: _openUPILink,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFF41A67E),
//                 elevation: 0,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//               icon: const Icon(Icons.link, size: 22),
//               label: const Text(
//                 'Pay via UPI Link',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(height: 12),
//           if (_qrImageBytes != null)
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: Colors.grey.shade300, width: 1.5),
//               ),
//               child: Column(
//                 children: [
//                   const Text(
//                     'Or Scan QR Code',
//                     style: TextStyle(
//                       fontSize: 15,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.black87,
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Container(
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       border: Border.all(color: Colors.grey.shade200),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: GestureDetector(
//                       onTap: _displayQRFullScreen,
//                       child: Image.memory(
//                         _qrImageBytes!,
//                         width: 170,
//                         height: 170,
//                         fit: BoxFit.contain,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   Text(
//                     'Tap to enlarge • Scan with any UPI app',
//                     style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
//                   ),
//                 ],
//               ),
//             ),
//           const SizedBox(height: 24),
//           Container(
//             height: 1,
//             color: Colors.grey.shade300,
//             margin: const EdgeInsets.symmetric(vertical: 12),
//           ),
//           const SizedBox(height: 12),
//           Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(
//                 color: _paymentCompleted
//                     ? const Color(0xFF41A67E)
//                     : Colors.grey.shade300,
//                 width: 1.5,
//               ),
//             ),
//             child: Row(
//               children: [
//                 Checkbox(
//                   value: _paymentCompleted,
//                   onChanged: (value) {
//                     setState(() {
//                       _paymentCompleted = value ?? false;
//                       if (_paymentCompleted) {
//                         _showTransactionIdInput = true;
//                       } else {
//                         _showTransactionIdInput = false;
//                         _transactionIdController.clear();
//                       }
//                     });
//                   },
//                   activeColor: const Color(0xFF41A67E),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 const Expanded(
//                   child: Text(
//                     "I've completed my payment",
//                     style: TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.w500,
//                       color: Colors.black87,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           if (_showTransactionIdInput) ...[
//             const SizedBox(height: 16),
//             TextField(
//               controller: _transactionIdController,
//               decoration: InputDecoration(
//                 labelText: 'UPI Transaction ID',
//                 hintText: 'e.g., UPI1234567890ABC',
//                 prefixIcon: const Icon(
//                   Icons.receipt_long,
//                   color: Color(0xFF41A67E),
//                 ),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                   borderSide: BorderSide(
//                     color: Colors.grey.shade300,
//                     width: 1.5,
//                   ),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                   borderSide: const BorderSide(
//                     color: Color(0xFF41A67E),
//                     width: 2,
//                   ),
//                 ),
//                 counterText: '',
//               ),
//               maxLines: 1,
//               maxLength: 30,
//             ),
//             const SizedBox(height: 8),
//             const Padding(
//               padding: EdgeInsets.only(left: 12),
//               child: Text(
//                 'Find this in your UPI app under transaction details',
//                 style: TextStyle(
//                   fontSize: 11,
//                   color: Colors.grey,
//                   fontStyle: FontStyle.italic,
//                 ),
//               ),
//             ),
//           ],
//           const SizedBox(height: 24),
//           SizedBox(
//             width: double.infinity,
//             height: 56,
//             child: ElevatedButton(
//               onPressed: _paymentCompleted && !_isSubmittingProof
//                   ? _markPaymentComplete
//                   : null,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: _paymentCompleted
//                     ? const Color(0xFF41A67E)
//                     : Colors.grey.shade400,
//                 elevation: 0,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//               child: _isSubmittingProof
//                   ? const SizedBox(
//                       height: 24,
//                       width: 24,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2.5,
//                         valueColor: AlwaysStoppedAnimation(Colors.white),
//                       ),
//                     )
//                   : const Text(
//                       'Mark as Paid',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w600,
//                         color: Colors.white,
//                       ),
//                     ),
//             ),
//           ),
//           const SizedBox(height: 12),
//           SizedBox(
//             width: double.infinity,
//             height: 48,
//             child: OutlinedButton(
//               onPressed: _cancelPayment,
//               style: OutlinedButton.styleFrom(
//                 side: BorderSide(color: Colors.grey.shade400),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//               child: const Text(
//                 'Cancel Payment',
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.black87,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       );
//     } else {
//       // Cash payment
//       return Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Cash Payment',
//             style: TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.w600,
//               color: Colors.black87,
//             ),
//           ),
//           const SizedBox(height: 16),
//           Container(
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: Colors.grey.shade300, width: 1.5),
//             ),
//             child: Column(
//               children: [
//                 Text(
//                   'Hand over the cash to ${widget.payeeName}',
//                   style: const TextStyle(
//                     fontSize: 15,
//                     fontWeight: FontWeight.w600,
//                     color: Colors.black87,
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 Text(
//                   'Once payment is received, tap below to mark as paid.',
//                   style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 22),
//           SizedBox(
//             width: double.infinity,
//             height: 56,
//             child: ElevatedButton(
//               onPressed: !_isSubmittingProof ? _markPaymentComplete : null,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFF41A67E),
//                 elevation: 0,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//               child: _isSubmittingProof
//                   ? const SizedBox(
//                       height: 24,
//                       width: 24,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2.5,
//                         valueColor: AlwaysStoppedAnimation(Colors.white),
//                       ),
//                     )
//                   : const Text(
//                       'Mark Cash Paid',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w600,
//                         color: Colors.white,
//                       ),
//                     ),
//             ),
//           ),
//           const SizedBox(height: 12),
//           SizedBox(
//             width: double.infinity,
//             height: 48,
//             child: OutlinedButton(
//               onPressed: _cancelPayment,
//               style: OutlinedButton.styleFrom(
//                 side: BorderSide(color: Colors.grey.shade400),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//               child: const Text(
//                 'Cancel Payment',
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.black87,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       );
//     }
//   }

//   Widget _buildPendingSection() {
//     return Container(
//       padding: const EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         color: Colors.blue.shade50,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: Colors.blue.shade200, width: 1.5),
//       ),
//       child: Column(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.blue.shade100,
//               shape: BoxShape.circle,
//             ),
//             child: Icon(
//               Icons.hourglass_top,
//               size: 48,
//               color: Colors.blue.shade700,
//             ),
//           ),
//           const SizedBox(height: 20),
//           const Text(
//             'Payment Submitted',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.w600,
//               color: Colors.black87,
//             ),
//           ),
//           const SizedBox(height: 12),
//           Text(
//             'Waiting for ${widget.payeeName} to verify your payment.',
//             textAlign: TextAlign.center,
//             style: const TextStyle(
//               fontSize: 14,
//               color: Colors.black54,
//               height: 1.6,
//             ),
//           ),
//           const SizedBox(height: 24),
//           SizedBox(
//             height: 4,
//             child: LinearProgressIndicator(
//               backgroundColor: Colors.blue.shade200,
//               valueColor: AlwaysStoppedAnimation(Colors.blue.shade700),
//             ),
//           ),
//           const SizedBox(height: 24),
//           SizedBox(
//             width: double.infinity,
//             height: 48,
//             child: ElevatedButton(
//               onPressed: () => context.pop(),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFF41A67E),
//                 elevation: 0,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//               child: const Text(
//                 'Go Back',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _transactionIdController.dispose();
//     super.dispose();
//   }
// }
