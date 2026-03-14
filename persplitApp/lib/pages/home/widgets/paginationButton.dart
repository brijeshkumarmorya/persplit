// lib/pages/home/widgets/paginationButton.dart

import 'package:flutter/material.dart';

class PaginationButtons extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Function(int) onPageChanged;

  const PaginationButtons({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous Button
          IconButton(
            onPressed: currentPage > 1
                ? () => onPageChanged(currentPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
            color: const Color(0xFF41A67E),
            disabledColor: Colors.grey.shade300,
            iconSize: 28,
          ),

          const SizedBox(width: 16),

          // Page Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF41A67E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$currentPage / $totalPages',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF41A67E),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Next Button
          IconButton(
            onPressed: currentPage < totalPages
                ? () => onPageChanged(currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
            color: const Color(0xFF41A67E),
            disabledColor: Colors.grey.shade300,
            iconSize: 28,
          ),
        ],
      ),
    );
  }
}
