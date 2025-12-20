import 'package:flutter/material.dart';
import 'home_page/manage_hall.dart';
import 'home_page/dashboard_page.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class HomePageWithSelectedHall extends StatefulWidget {
  final dynamic selectedHall;
  const HomePageWithSelectedHall({super.key, this.selectedHall});

  @override
  State<HomePageWithSelectedHall> createState() => _HomePageWithSelectedHallState();
}

class _HomePageWithSelectedHallState extends State<HomePageWithSelectedHall> {
  int _selectedIndex = 0;
  dynamic _selectedHall;

  @override
  void initState() {
    super.initState();
    _selectedHall = widget.selectedHall;
  }

  List<Widget> get _pages => [
    DashboardPage(selectedHall: _selectedHall),
    ManagePage(selectedHall: _selectedHall),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: royal,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white.withValues(alpha:0.7),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Manage',
          ),
        ],
      ),
    );
  }
}
