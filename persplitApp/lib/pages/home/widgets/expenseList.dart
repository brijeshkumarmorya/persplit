import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExpenseList extends StatelessWidget {
  final List<Map<String, dynamic>> expenses;
  final String? currentUserId;

  const ExpenseList({super.key, required this.expenses, this.currentUserId});

  Map<String, dynamic> _getCategoryStyle(String category) {
    final categoryLower = category.toLowerCase();
    switch (categoryLower) {
      case 'food':
        return {'icon': Icons.restaurant, 'color': Colors.orange};
      case 'travel':
        return {'icon': Icons.local_taxi, 'color': Colors.blue};
      case 'shopping':
        return {'icon': Icons.shopping_cart, 'color': Colors.pink};
      case 'entertainment':
        return {'icon': Icons.movie, 'color': Colors.purple};
      case 'utilities':
        return {'icon': Icons.electrical_services, 'color': Colors.amber};
      case 'health':
        return {'icon': Icons.local_hospital, 'color': Colors.red};
      case 'education':
        return {'icon': Icons.school, 'color': Colors.indigo};
      case 'transport':
        return {'icon': Icons.directions_bus, 'color': Colors.cyan};
      default:
        return {'icon': Icons.attach_money, 'color': Colors.green};
    }
  }

  Color _getExpenseTypeColor(String type) {
    final lowerType = type.toLowerCase();
    switch (lowerType) {
      case 'instant':
        return Colors.blueAccent;
      case 'personal':
        return const Color(0xFF41A67E);
      case 'group':
        return Colors.deepPurpleAccent;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  double _getMyShare(Map<String, dynamic> expense) {
    if (currentUserId == null) return 0.0;

    final splitDetails = expense['splitDetails'] as List<dynamic>?;
    if (splitDetails == null) return 0.0;

    for (var split in splitDetails) {
      final user = split['user'] as Map<String, dynamic>?;
      if (user != null && user['_id'] == currentUserId) {
        return (split['finalShare'] ?? split['amount'] ?? 0).toDouble();
      }
    }
    return 0.0;
  }

  String _getPaidByName(Map<String, dynamic> expense) {
    final paidBy = expense['paidBy'] as Map<String, dynamic>?;
    return paidBy?['name'] ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double w = constraints.maxWidth;
        double scale = (w / 390).clamp(0.75, 1.35);

        return ListView.builder(
          itemCount: expenses.length,
          padding: EdgeInsets.symmetric(horizontal: 12 * scale),
          itemBuilder: (context, index) {
            final expense = expenses[index];

            final title =
                expense['title'] ?? expense['description'] ?? 'Untitled';
            final amount = expense['amount']?.toString() ?? '0';
            final date = _formatDate(expense['date'] ?? expense['createdAt']);
            final category = expense['category'] ?? 'Other';
            final type = expense['expenseType'] ?? 'personal';

            final paidByName = _getPaidByName(expense);
            final myShare = _getMyShare(expense);

            final categoryStyle = _getCategoryStyle(category);
            final categoryColor = categoryStyle['color'] as Color;
            final categoryIcon = categoryStyle['icon'] as IconData;
            final typeColor = _getExpenseTypeColor(type);

            return Container(
              margin: EdgeInsets.only(bottom: 10 * scale),
              padding: EdgeInsets.symmetric(vertical: 4 * scale),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14 * scale),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6 * scale,
                    offset: Offset(0, 2 * scale),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16 * scale,
                  vertical: 10 * scale,
                ),

                leading: CircleAvatar(
                  radius: 26 * scale,
                  backgroundColor: categoryColor.withOpacity(0.2),
                  child: Icon(
                    categoryIcon,
                    size: 26 * scale,
                    color: categoryColor,
                  ),
                ),

                title: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4 * scale),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            date,
                            style: TextStyle(
                              fontSize: 12.5 * scale,
                              color: Colors.black54,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 6 * scale),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6 * scale,
                            vertical: 3 * scale,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6 * scale),
                          ),
                          child: Text(
                            type.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10 * scale,
                              color: typeColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 4 * scale),

                    Row(
                      children: [
                        Text(
                          "Paid by: ",
                          style: TextStyle(
                            fontSize: 13 * scale,
                            color: Colors.black54,
                          ),
                        ),

                        Expanded(
                          child: Text(
                            paidByName,
                            style: TextStyle(
                              fontSize: 13 * scale,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        SizedBox(width: 6 * scale),

                        Text(
                          "• Total: ₹$amount",
                          style: TextStyle(
                            fontSize: 13 * scale,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // FIXED TRAILING (Never overflows)
                trailing: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "₹${myShare.toStringAsFixed(0)}",
                        style: TextStyle(
                          fontSize: 18 * scale,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF41A67E),
                        ),
                      ),
                      SizedBox(height: 4 * scale),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10 * scale,
                          vertical: 4 * scale,
                        ),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20 * scale),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 11 * scale,
                            color: categoryColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
