import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart';
import 'app_payment.dart';
import 'default_value_page.dart';
import 'add_peak_hour.dart';
import 'add_instruction_page.dart';
import 'submit.dart';
import 'add_facilitator.dart';
import 'add_room.dart';

const Color royalblue = Color(0xFF376EA1);
const Color royal = Color(0xFF19527A);
const Color royalLight = Color(0xFF629AC1);

class OtherManagePage extends StatefulWidget {
  const OtherManagePage({super.key});

  @override
  State<OtherManagePage> createState() => _OtherManagePageState();
}

class _OtherManagePageState extends State<OtherManagePage> {
  String? lodgeName;
  String? lodgeAddress;
  String? lodgeLogo;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHallData();
  }

  Future<void> _fetchHallData() async {
    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");

    if (lodgeId == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final url = Uri.parse("$baseUrl/lodges/$lodgeId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          lodgeName = data["name"];
          lodgeAddress = data["address"];
          lodgeLogo = data["logo"];
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
              if (lodgeName != null) _buildHallCard(),
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
              backgroundImage: (lodgeLogo != null && lodgeLogo!.isNotEmpty)
                  ? MemoryImage(base64Decode(lodgeLogo!))
                  : null,
              child: (lodgeLogo == null || lodgeLogo!.isEmpty)
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
                    lodgeName ?? "Unknown Lodge",
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
                    lodgeAddress ?? "No address available",
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
                  icon: Icons.room_preferences,
                  label: "Rooms",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RoomsPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.access_time,
                  label: "Peak Hours",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PeakHoursPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.attach_money,
                  label: "Charges",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DefaultValuesPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.rule,
                  label: "Instruction",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HallInstructionsPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.domain_add,
                  label: "Facilitator",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddFacilitatorPage()),
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
              color: royalLight.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: royal,
                width: 1.5 ,
              ),
              boxShadow: [
                BoxShadow(
                  color: royal.withValues(alpha:0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, size: 32, color:Colors.white),
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
              style: const TextStyle(
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
