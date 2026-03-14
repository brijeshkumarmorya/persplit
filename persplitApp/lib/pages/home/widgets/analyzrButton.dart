import 'package:flutter/material.dart';

/// ================= ANALYZE BUTTON ==================
class AnalyzeButton extends StatelessWidget {
  const AnalyzeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: width * 0.08, vertical: 2),
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF41A67E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () {},
        icon: const Icon(Icons.bar_chart, color: Colors.white),
        label: Text(
          "Analyze",
          style: TextStyle(
            fontSize: width * 0.045,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}