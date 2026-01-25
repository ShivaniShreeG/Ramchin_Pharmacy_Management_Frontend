import 'package:flutter/material.dart';
import '../../public/main_navigation.dart';
import 'bulk_upload_exist.dart';
import 'bulk_upload_medicine.dart'; // import your medicine page
import 'bulk_upload_batch.dart'; // import your batch page

class BulkUploadPage extends StatefulWidget {
  const BulkUploadPage({super.key});

  @override
  State<BulkUploadPage> createState() => _BulkUploadPageState();
}

class _BulkUploadPageState extends State<BulkUploadPage> {
  int _selectedIndex = 0;

  final Color royal = const Color(0xFF875C3F);

  final List<String> _appBarTitles = const [
    "Medicine Bulk Upload",
    "Batch Bulk Upload",
    "Exist Medicine Bulk Upload"
  ];

  final List<Widget> _pages = const [
    BulkUploadMedicinePage(),
    BulkUploadBatchPage(),
    BulkUploadMedicineExistPage(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: royal,
        title: Text(
          _appBarTitles[_selectedIndex],
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MainNavigation(initialIndex: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        backgroundColor: royal, // Olive Green 🌿
        selectedItemColor: Colors.white, // Muted Tan 🏺
        unselectedItemColor: Colors.white.withValues(alpha: 0.7), // lighter tan for unselected
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services_outlined),
            label: "Medicine",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload_file),
            label: "Batch",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload_rounded),
            label: "Exist_Medicine",
          ),
        ],
      ),
    );
  }
}
