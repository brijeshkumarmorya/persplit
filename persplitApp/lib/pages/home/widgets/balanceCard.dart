import 'package:flutter/material.dart';

class BalanceCards extends StatelessWidget {
  final bool isTablet;
  final double width;
  final double toReceive;
  final double toPay;

  const BalanceCards({
    super.key,
    required this.isTablet,
    required this.width,
    this.toReceive = 0.0,
    this.toPay = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? width * 0.15 : 16),
      child: Row(
        children: [
          Expanded(
            child: _InfoCard(
              title: "You will Receive",
              amount: "₹${toReceive.toStringAsFixed(2)}",
              color: Colors.green,
              icon: Icons.arrow_downward,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _InfoCard(
              title: "You will Pay",
              amount: "₹${toPay.toStringAsFixed(2)}",
              color: Colors.red,
              icon: Icons.arrow_upward,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;
  final IconData icon;

  const _InfoCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: width * 0.035,
                    color: Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                icon,
                color: color,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: TextStyle(
                fontSize: width * 0.055,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
