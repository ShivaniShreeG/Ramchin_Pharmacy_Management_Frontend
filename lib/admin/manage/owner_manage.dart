import 'dart:convert';
import 'package:flutter/material.dart';
import 'supplier.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart';
import 'create_admin.dart';
import 'app_payment.dart';
import 'submit.dart';
import 'stock_management.dart';
import 'add_medicines.dart';
import 'reorder/reorder_list.dart';
import 'bulk_upload.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class OwnerPage extends StatefulWidget {
  const OwnerPage({super.key});

  @override
  State<OwnerPage> createState() => _OwnerPageState();
}

class _OwnerPageState extends State<OwnerPage> {
  String? shopName;
  String? shopAddress;
  String? shopLogo;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHallData();
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
    final screenWidth = MediaQuery.of(context).size.width;

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: royal)),
      );
    }

    return Scaffold(
      backgroundColor: royalLight.withValues(alpha: 0.2),
      body: SingleChildScrollView(
        child: Container(padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (shopName != null) _buildHallCard(),
              const SizedBox(height: 20),
              _buildManageCard(screenWidth),
              const SizedBox(height: 20),
              _buildExpenseCard(screenWidth),
            ],
          ),
        ),
      ),
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
                  "Service",
                  style: TextStyle(
                    color: royal,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                  },
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
                  icon: Icons.payment,
                  label: "App Payment",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AppPaymentPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.confirmation_num,
                  label: "Submit Tickets",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SubmitTicketPage()),
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

  Widget _buildManageCard(double screenWidth) {
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
                  "Manage",
                  style: TextStyle(
                    color: royal,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                  },
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
                  icon: Icons.admin_panel_settings,
                  label: "Admin",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CreateAdminPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.local_hospital,
                  label: "Medicines",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const InventoryPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon:Icons.upload_file,
                  label: "Bulk Upload Medicine",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const BulkUploadPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.inventory_2_outlined,
                  label: "Stock",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const StockPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.storage,
                  label: "Reorder Medicine",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ReorderPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.people_alt_rounded,
                  label: "Supplier",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SupplierPage()),
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
