import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/main_navigation.dart';
import '../../services/config.dart';

const Color royal = Color(0xFF875C3F);

class AdminStatusPage extends StatefulWidget {
  const AdminStatusPage({super.key});

  @override
  State<AdminStatusPage> createState() => _AdminStatusPageState();
}

class _AdminStatusPageState extends State<AdminStatusPage> {
  List<Map<String, dynamic>> _admins = [];
  bool _isLoading = true;
  Map<String, dynamic>? shopDetails;
  int? shopId;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _loadShopIdAndFetch();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: royal)),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: royal),
        ),
      ),
    );
  }

  Widget _buildHallCard(Map<String, dynamic> hall) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      padding: const EdgeInsets.all(16),
      height: 95,
      decoration: BoxDecoration(
        color: royal,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: royal, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: royal.withValues(alpha:0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ClipOval(
            child: hall['logo'] != null
                ? Image.memory(
              base64Decode(hall['logo']),
              width: 70,
              height: 70,
              fit: BoxFit.cover,
            )
                : Container(
              width: 70,
              height: 70,
              color: Colors.white,
              child: const Icon(
                Icons.home_work_rounded,
                color: royal,
                size: 35,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                hall['name']?.toString().toUpperCase() ?? "SHOP NAME",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadShopIdAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    shopId = prefs.getInt('shopId');
    currentUserId = prefs.getString('userId'); // 👈 ADD THIS

    if (shopId != null) {
      await _fetchAdmins();
      await _fetchHallDetails();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _fetchHallDetails() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/shops/$shopId'),
      );

      if (res.statusCode == 200) {
        shopDetails = jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint("Error fetching shop details: $e");
    }
  }

  Future<void> _fetchAdmins() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    if (shopId == null) return;

    try {
      final res = await http.get(Uri.parse("$baseUrl/admins/user/details/active/$shopId"));
      if (res.statusCode == 200) {
        setState(() {
          _admins = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        });
      }
    } catch (e) {
      _showMessage("Error loading admins");
    }
  }

  Future<void> _toggleStatus(String userId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    if (shopId == null) return;

    try {
      final res = await http.patch(
        Uri.parse("$baseUrl/admins/$shopId/admin/$userId/status/update"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"is_active": value}),
      );

      if (res.statusCode == 200) {
        setState(() {
          final admin = _admins.firstWhere((a) => a["user_id"] == userId);
          admin["is_active"] = value;
        });
        _showMessage("Status updated");
      } else {
        final data = jsonDecode(res.body);
        _showMessage(data["message"]);
      }
    } catch (e) {
      _showMessage("Failed to update status");
    }
  }

  Widget _buildAdminCard(Map<String, dynamic> admin) {
    final bool isActive = admin["is_active"] == true;
    final bool isCurrentUser = admin["user_id"] == currentUserId;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: royal, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.person, color: royal, size: 40),
            const SizedBox(width: 12),

            /// ADMIN DETAILS
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "User ID: ${admin["user_id"] ?? "N/A"}",
                    style: const TextStyle(
                      color: royal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text("Name: ${admin["name"] ?? "-"}", style: const TextStyle(color: royal)),
                  Text("Phone: ${admin["phone"] ?? "-"}", style: const TextStyle(color: royal)),
                  Text("Email: ${admin["email"] ?? "-"}", style: const TextStyle(color: royal)),
                  Text("Designation: ${admin["designation"] ?? "-"}",
                      style: const TextStyle(color: royal)),
                ],
              ),
            ),

            /// 🔁 ACTIVE / INACTIVE TOGGLE
            if (!isCurrentUser)
              Column(
                children: [
                  Switch(
                    value: isActive,
                    onChanged: (value) {
                      _toggleStatus(admin["user_id"], value);
                    },

                    // 🔘 Thumb (circle)
                    thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return Colors.white;
                    }),

                    // 🟤 Track (background)
                    trackColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return royal; // ACTIVE
                      }
                      return royal.withValues(alpha: 0.35); // INACTIVE
                    }),

                    // ✨ Optional: subtle border effect
                    trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
                      return royal;
                    }),
                  ),
                  Text(
                    isActive ? "Active" : "Inactive",
                    style: TextStyle(
                      color: isActive ? royal : royal.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else
            /// 🔒 CURRENT USER LABEL
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Text(
                  "You",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminsResponsive(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // breakpoint
    final isWide = screenWidth >= 700;

    // card width
    final cardWidth = isWide
        ? (screenWidth - 16 * 2 - 12) / 2 // 2 per row
        : screenWidth; // 1 per row

    // Filter out the current user
    final adminsToShow = _admins.where((admin) => admin["user_id"] != currentUserId).toList();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: adminsToShow.map((admin) {
        return SizedBox(
          width: isWide ? cardWidth : double.infinity,
          child: _buildAdminCard(admin),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Status"),
        backgroundColor: royal,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MainNavigation(initialIndex: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// 🔷 SHOP / HALL CARD (TOP)
            if (shopDetails != null)
              _buildHallCard(shopDetails!),

            const SizedBox(height: 16),

            /// 🔷 ADMINS LIST
            _buildAdminsResponsive(context),
          ],
        ),
      ),

    );
  }
}
