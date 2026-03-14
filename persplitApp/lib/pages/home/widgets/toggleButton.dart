/// toggleButton.dart
import 'package:flutter/material.dart';

class ToggleButtonsRow extends StatefulWidget {
  /// List of tab labels
  final List<String> tabs;

  /// Initially selected tab index (default: 0)
  final int initialIndex;

  /// Callback when tab changes
  final ValueChanged<int>? onTabSelected;

  const ToggleButtonsRow({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
    this.onTabSelected,
  });

  @override
  State<ToggleButtonsRow> createState() => _ToggleButtonsRowState();
}

class _ToggleButtonsRowState extends State<ToggleButtonsRow> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(widget.tabs.length, (index) {
          final isSelected = _selectedIndex == index;
          final tab = widget.tabs[index];

          return GestureDetector(
            onTap: () {
              setState(() => _selectedIndex = index);
              if (widget.onTabSelected != null) {
                widget.onTabSelected!(index);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: EdgeInsets.symmetric(
                horizontal: width * 0.05,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF41A67E) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tab,
                style: TextStyle(
                  fontSize: width * 0.035,
                  color: isSelected ? Colors.white : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
