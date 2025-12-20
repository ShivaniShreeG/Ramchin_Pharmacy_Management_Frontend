import 'package:flutter/material.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class BottomNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final String role;

  const BottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    // Hide navbar for administrator role
    if (role == "ADMINISTRATOR") {
      return const SizedBox.shrink();
    }

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      backgroundColor: royal, // Olive Green 🌿
      selectedItemColor: Colors.white, // Muted Tan 🏺
      unselectedItemColor: Colors.white.withValues(alpha: 0.7), // lighter tan for unselected
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.miscellaneous_services),
          label: "Services",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: "Home",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.manage_accounts),
          label: "Manage",
        ),
      ],
    );
  }
}
