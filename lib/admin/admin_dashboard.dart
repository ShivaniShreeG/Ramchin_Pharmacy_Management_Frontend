import 'dart:convert';
import 'package:flutter/material.dart';
import 'services/service/customer_history.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../public/config.dart';
import 'services/accounts/add_income_page.dart';
import 'services/accounts/add_expense.dart';
import 'services/accounts/view_finance.dart';
import 'services/accounts/reports.dart';
import 'services/accounts/add_drawing.dart';
import 'services/service/billing.dart';
import 'services/service/billing_history.dart';
import 'services/service/medicine_history.dart';
import 'services/service/sales_summary.dart';
import 'services/service/medicine_values.dart';
import 'services/service/available_medicine.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? selectedHall;
  String? shopName;
  String? shopAddress;
  String? shopLogo;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHall();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isError? Colors.redAccent.shade400 : royal,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: royal,width: 2)
        ),
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _loadHall() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt('shopId');
    if (shopId != null) {
      await _fetchHallData();
    } else {
      setState(() => isLoading = false);
      _showMessage("No shop ID found in saved data", isError: true);
    }
  }

  Future<void> _fetchHallData() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");

    if (shopId == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final url = Uri.parse("$baseUrl/shops/$shopId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          shopName = data["name"];
          shopAddress = data["address"];
          shopLogo = data["logo"];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;
    // double textScale = (screenWidth / 390).clamp(0.8, 1.4);
    double boxScale  = (screenHeight / 840).clamp(0.8, 1.4);

    return Scaffold(
      backgroundColor: royalLight.withValues(alpha: 0.2),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(color: royal),
      )
          : SingleChildScrollView(
        child: Container(padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildHallCard(),
            SizedBox(height: 20 * boxScale),
            Align(
              alignment: Alignment.center,
              child: _buildBookingServiceCard(
                  screenWidth),

            ),
            SizedBox(height: 20 * boxScale),

            Align(
              alignment: Alignment.center,
              child: _buildExpenseCard(screenWidth),
            ),
          ],
        ),
      ),
    )
    );
  }

  Widget _buildHallCard() {
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive scale: phones → small, tablets/desktops → bigger
    double textScale = (screenWidth / 390).clamp(0.8, 1.4);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(
          color: royal,
          width: 1.5,
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 25 * textScale,
              backgroundColor: royalLight,
              backgroundImage: (shopLogo != null && shopLogo!.isNotEmpty)
                  ? MemoryImage(base64Decode(shopLogo!))
                  : null,
              child: (shopLogo == null || shopLogo!.isEmpty)
                  ? Icon(
                Icons.home_work_rounded,
                size: 25 * textScale,
                color: royal,
              )
                  : null,
            ),

            SizedBox(width: 16 * textScale),

            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shopName ?? "Unknown Shop",
                    style: TextStyle(
                      fontSize: 18 * textScale,   // ⬅ Responsive Title
                      fontWeight: FontWeight.bold,
                      color: royal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: 4 * textScale),

                  Text(
                    shopAddress ?? "No address available",
                    style: TextStyle(
                      fontSize: 14 * textScale,   // ⬅ Responsive Address
                      color: royal,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseCard(double screenWidth) {
    final buttonSize = 70.0;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(
          color: royal,
          width: 1.5,
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Accounts",
                  style: TextStyle(
                    color: royal,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: const Icon(
                    Icons.arrow_drop_down,
                    color: royal,
                    size: 40,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildManageButton(
                  icon: Icons.list_alt,
                  label: "Add Income",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddIncomePage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.add_chart,
                  label: "Add Expense ",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddExpensePage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.add_to_photos,
                  label: "Add Drawing",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddDrawingPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.analytics,
                  label: "View Finance",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ViewFinancePage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.contact_page,
                  label: "Reports",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ReportsPage()),
                    );
                  },
                  size: buttonSize,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingServiceCard(double screenWidth) {
    final double buttonSize = 70.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: royal, width: 1.5),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  "Services",
                  style: TextStyle(
                    color: royal,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: royal, size: 40),
              ],
            ),

            const SizedBox(height: 16),

            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildManageButton(
                  icon: Icons.file_copy,
                  label: "Billing",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => BillingPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.history,
                  label: "Billing History",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => BillingHistoryPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.medical_information_rounded,
                  label: "Medicines History",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => MedicineHistoryPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.bar_chart,
                  label: "Sales Report",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => SalesReportPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.medical_services, // ✅ medicine-related icon
                  label: "Medicine Value",      // Button label
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MedicineValuePage(), // your medicine value page
                      ),
                    );
                  },
                  size: buttonSize,
                ),

                _buildManageButton(
                  icon: Icons.add_box,
                  label: "Available Medicines",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => AvailableMedicinePage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.people_alt_rounded,
                  label: "Customer History",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => CustomerHistoryPage()),
                    );
                  },
                  size: buttonSize,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required double size,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: royalLight.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: royal,
                width: 1.5 ,
              ),
            ),
            child: Center(
              child: Icon(icon, size: 32, color:royal),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: size,
          height: 36,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style:  TextStyle(
                color: royal,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
