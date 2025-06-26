import 'package:flutter/material.dart';

class FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const FloatingNavBar({
    Key? key,
    required this.selectedIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color selectedBg = isDark ? Colors.white : const Color(0xFF0A0E25);
    final Color selectedIcon = isDark ? const Color(0xFF0A0E25) : Colors.white;
    final Color unselectedBg = isDark
        ? Colors.white.withOpacity(0.07)
        : const Color(0xFFF2F4F7); // light grey for unselected
    final Color unselectedIcon = isDark
        ? Colors.white // white for dark mode
        : const Color(0xFF0A0E25); // dark blue for light mode
    final Color navBarBg = isDark
        ? Theme.of(context).cardColor // dark mode: match card color
        : Colors.white; // light mode: white
    final BoxShadow navBarShadow = isDark
        ? BoxShadow(
            color: Colors.white.withOpacity(0.09),
            blurRadius: 18,
            offset: const Offset(0, 4),
          )
        : BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 18,
            offset: const Offset(0, 4),
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: navBarBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [navBarShadow],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(
            context,
            icon: Icons.home_rounded,
            index: 0,
            selectedIndex: selectedIndex,
            selectedBg: selectedBg,
            selectedIcon: selectedIcon,
            unselectedBg: unselectedBg,
            unselectedIcon: unselectedIcon,
          ),
          _buildNavItem(
            context,
            icon: Icons.bar_chart_rounded,
            index: 1,
            selectedIndex: selectedIndex,
            selectedBg: selectedBg,
            selectedIcon: selectedIcon,
            unselectedBg: unselectedBg,
            unselectedIcon: unselectedIcon,
          ),
          _buildNavItem(
            context,
            icon: Icons.trending_up_rounded,
            index: 2,
            selectedIndex: selectedIndex,
            selectedBg: selectedBg,
            selectedIcon: selectedIcon,
            unselectedBg: unselectedBg,
            unselectedIcon: unselectedIcon,
          ),
          _buildNavItem(
            context,
            icon: Icons.person_outline_rounded,
            index: 3,
            selectedIndex: selectedIndex,
            selectedBg: selectedBg,
            selectedIcon: selectedIcon,
            unselectedBg: unselectedBg,
            unselectedIcon: unselectedIcon,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required int index,
    required int selectedIndex,
    required Color selectedBg,
    required Color selectedIcon,
    required Color unselectedBg,
    required Color unselectedIcon,
  }) {
    final bool isSelected = index == selectedIndex;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : unselectedBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          size: 28,
          color: isSelected ? selectedIcon : unselectedIcon,
        ),
      ),
    );
  }
} 