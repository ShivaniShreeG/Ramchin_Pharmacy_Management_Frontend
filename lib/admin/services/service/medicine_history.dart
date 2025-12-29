import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../public/config.dart';
import '../../../../public/main_navigation.dart';
import 'package:intl/intl.dart';
import 'batch_detail_page.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);

class MedicineHistoryPage extends StatefulWidget {
  const MedicineHistoryPage({super.key});

  @override
  State<MedicineHistoryPage> createState() => _MedicineHistoryPageState();
}

class _MedicineHistoryPageState extends State<MedicineHistoryPage> {
  bool loading = true;
  List medicines = [];
  final TextEditingController _searchCtrl = TextEditingController();
  List filteredMedicines = [];
  Map<String, dynamic>? shopDetails;

  @override
  void initState() {
    super.initState();
    fetchMedicines();
    _fetchHallDetails();
  }

  Future<void> fetchMedicines() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");

    final res = await http.get(
      Uri.parse("$baseUrl/inventory/history/$shopId"),
    );

    if (res.statusCode == 200) {
      medicines = jsonDecode(res.body);
      filteredMedicines = medicines;
    }


    setState(() => loading = false);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        backgroundColor: royal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _fetchHallDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");

    try {
      final url = Uri.parse('$baseUrl/shops/$shopId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        shopDetails = jsonDecode(response.body);
      }
    } catch (e) {
      _showMessage("Error fetching hall details: $e");
    } finally {
      setState(() {});
    }
  }

  void _filterMedicines(String query) {
    if (query.isEmpty) {
      filteredMedicines = medicines;
    } else {
      final q = query.toLowerCase();

      filteredMedicines = medicines.where((med) {
        final name = med['name'].toString().toLowerCase();
        return name.contains(q);
      }).toList();
    }
    setState(() {});
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      cursorColor: royal,
      style: TextStyle(color: royal),
      onChanged: _filterMedicines,
      decoration: InputDecoration(
        hintText: "Search medicine...",
        hintStyle: TextStyle(color: royal),
        prefixIcon: const Icon(Icons.search),
        prefixIconColor: royal,
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            _searchCtrl.clear();
            _filterMedicines('');
          },
        )
            : null,
        suffixIconColor: royal,
        filled: true,
        fillColor: royal.withValues(alpha: 0.1),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: royal, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: royal, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildHallCard(Map<String, dynamic> hall) {
    return Container(
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
              color: Colors.white, // 👈 soft teal background
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
                hall['name']?.toString().toUpperCase() ?? "HALL NAME",
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

  Widget _buildMedicineCard(Map medicine) {
    final batches = List<Map>.from(medicine['batches'] ?? []);
    final String? ndc =
    medicine['ndc_code']?.toString().trim().isNotEmpty == true
        ? medicine['ndc_code']
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: royal.withValues(alpha: 0.6)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        iconColor: royal,
        collapsedIconColor: royal,

        /// 🔹 HEADER
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    medicine['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: royal,
                    ),
                  ),
                ),
                _buildStockChip(medicine['stock']),
              ],
            ),

            const SizedBox(height: 6),

            /// Category + NDC
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildInfoChip(
                  Icons.category,
                  medicine['category'],
                ),
                if (ndc != null)
                  _buildInfoChip(
                    Icons.qr_code_2,
                    "NDC: $ndc",
                  ),
              ],
            ),
          ],
        ),

        /// 🔹 BATCH LIST
        children: batches.map((batch) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: royal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: royal.withValues(alpha: 0.35), // 👈 BORDER ADDED
                width: 1,
              ),
            ),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.inventory_2, color: royal),
              title: Text(
                "Batch ${batch['batch_no']}",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              subtitle: Text(
                "Qty: ${batch['total_stock']}  •  Exp: ${DateFormat('dd MMM yyyy').format(
                  DateTime.parse(batch['expiry_date']),
                )}",
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: royal,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BatchDetailPage(
                      medicine: medicine,
                      batch: batch,
                    ),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStockChip(int stock) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: stock > 0 ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "Stock: $stock",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: stock > 0 ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: royal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: royal),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: royal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text(
          "Medicine History",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: 2)),
              );
            },
          ),
        ],
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: royal))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// 🏪 Shop Card
            if (shopDetails != null) ...[
              _buildHallCard(shopDetails!),
              const SizedBox(height: 16),
            ],
    Center(
    child: ConstrainedBox(
    constraints: const BoxConstraints(
      maxWidth: 600, // 👈 only form is constrained
    ),
    child: Column(
    children: [
            /// 🔍 Search Bar
            _buildSearchBar(),
            const SizedBox(height: 16),

            /// ❌ No Data
            if (filteredMedicines.isEmpty) ...[
              const SizedBox(height: 80),
              Icon(
                Icons.medical_services_outlined,
                size: 64,
                color: royal,
              ),
              const SizedBox(height: 12),
              const Text(
                "No medicine history found",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: royal,
                ),
              ),
            ]

            /// 💊 Medicine List
            else ...List.generate(filteredMedicines.length, (index) {
              return Column(
                children: [
                  _buildMedicineCard(filteredMedicines[index]),
                ],
              );
            }),

            /// Bottom spacing (for FAB / navbar safety)
            const SizedBox(height: 80),
          ],
        ),
      ),
    ),
          ],
        ),
      ),
    );
  }
}