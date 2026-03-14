import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _selectedIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSelectedIndex();
  }

  void _updateSelectedIndex() {
    final String location = GoRouterState.of(context).uri.toString();
    setState(() {
      if (location == '/') {
        _selectedIndex = 0;
      } else if (location == '/groups') {
        _selectedIndex = 1;
      } else if (location == '/add') {
        _selectedIndex = 2;
      } else if (location == '/settle') {
        _selectedIndex = 3;
      } else if (location == '/friends') {
        _selectedIndex = 4;
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);

    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/groups');
        break;
      case 2:
        context.go('/add');
        break;
      case 3:
        context.go('/settle');
        break;
      case 4:
        context.go('/friends');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAF9),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_outlined, Icons.home, "Home", 0),
            _buildNavItem(Icons.groups_2_outlined, Icons.groups_2, "Groups", 1),
            _buildAddButton(),
            _buildNavItem(
                Icons.receipt_long_outlined, Icons.receipt_long, "Settle", 3),
            _buildNavItem(Icons.person_outline, Icons.person, "Friends", 4),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
      IconData outlinedIcon, IconData filledIcon, String label, int index) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? filledIcon : outlinedIcon,
              color: isSelected ? const Color(0xFF41A67E) : Colors.black45,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? const Color(0xFF41A67E) : Colors.black54,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: () => _onItemTapped(2),
      child: Container(
        height: 56,
        width: 56,
        decoration: const BoxDecoration(
          color: Color(0xFFE5F7EE),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.add,
          color: Color(0xFF41A67E),
          size: 30,
        ),
      ),
    );
  }
}
