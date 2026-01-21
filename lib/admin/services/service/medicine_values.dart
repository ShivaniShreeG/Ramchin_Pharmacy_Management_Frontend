import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/config.dart';
import '../../../../public/main_navigation.dart';

const Color royal = Color(0xFF875C3F);

class MedicineValuePage extends StatefulWidget {
  const MedicineValuePage({super.key});

  @override
  State<MedicineValuePage> createState() => _MedicineValuePageState();
}

class _MedicineValuePageState extends State<MedicineValuePage> {
  bool loading = true;
  Map<String, dynamic>? valueData;
  Map<String, dynamic>? shopDetails;
  Map<String, dynamic>? stockSummary;

  @override
  void initState() {
    super.initState();
    fetchMedicineValue();
    fetchShopDetails();
    fetchStockSummary(); // ✅ ADD THIS
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: royal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> fetchShopDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");

    try {
      final url = Uri.parse('$baseUrl/shops/$shopId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        shopDetails = jsonDecode(response.body);
      }
    } catch (e) {
      _showMessage("Error fetching shop details: $e");
    } finally {
      setState(() {});
    }
  }

  Future<void> fetchMedicineValue() async {
    setState(() => loading = true);
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");

    if (shopId == null) return;

    try {
      // Overall
      final overallRes = await http.get(Uri.parse("$baseUrl/medicine-value/overall/$shopId"));
      final overallData = overallRes.statusCode == 200 ? jsonDecode(overallRes.body) : {"totalValue": 0};

      // Medicine-wise
      final medicineRes = await http.get(Uri.parse("$baseUrl/medicine-value/medicine-wise/$shopId"));
      final medicineWise = medicineRes.statusCode == 200 ? jsonDecode(medicineRes.body) : [];

      // Batch-wise
      final batchRes = await http.get(Uri.parse("$baseUrl/medicine-value/batch-wise/$shopId"));
      final batchWise = batchRes.statusCode == 200 ? jsonDecode(batchRes.body) : [];

      setState(() {
        valueData = {
          "overall": overallData["totalValue"] ?? 0,
          "medicineWise": medicineWise,
          "batchWise": batchWise,
        };
      });
    } catch (e) {
      _showMessage("Error fetching medicine values: $e");
    }

    setState(() => loading = false);
  }

  Future<void> fetchStockSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");

    if (shopId == null) return;

    try {
      final res = await http.get(
        Uri.parse("$baseUrl/medicine-value/stock-summary/$shopId"),
      );

      if (res.statusCode == 200) {
        setState(() {
          stockSummary = jsonDecode(res.body);
        });
      }
    } catch (e) {
      _showMessage("Error fetching stock summary");
    }
  }

  Widget _buildStockSummaryCard() {
    if (stockSummary == null) return const SizedBox.shrink();

    return Card(
      color: Colors.white,
      elevation: 4,
      shadowColor: royal.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: royal.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "📦 Stock Summary (Today)",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: royal,
              ),
            ),
            const SizedBox(height: 12),

            _row("Previous Stock", stockSummary!['previousStock']),
            _row("New Stock Today", stockSummary!['newStockToday']),
            _row("Total Stock Today", stockSummary!['totalStockToday']),
            const Divider(),
            _row("Sold Today", stockSummary!['stockSoldToday']),
            _row("Stock On Hand", stockSummary!['stockOnHand'], bold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, Map<String, dynamic> data, {bool bold = false}) {
    final qty = data['qty'] ?? 0;
    final value = (data['value'] ?? 0).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Qty: $qty",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              Text(
                "₹${value.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: royal,
                ),
              ),
            ],
          ),
        ],
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
        boxShadow: [BoxShadow(color: royal.withValues(alpha:0.15), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ClipOval(
            child: hall['logo'] != null
                ? Image.memory(base64Decode(hall['logo']), width: 70, height: 70, fit: BoxFit.cover)
                : Container(
              width: 70,
              height: 70,
              color: Colors.white,
              child: const Icon(Icons.home_work_rounded, color: royal, size: 35),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                hall['name']?.toString().toUpperCase() ?? "SHOP NAME",
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallValue() {
    if (valueData == null) return const SizedBox.shrink();
    final total = valueData!['overall'] ?? 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: royal.withValues(alpha:0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Overall Medicine Value", style: TextStyle(color:royal,fontWeight: FontWeight.w500, fontSize: 16)),
            Text("₹${total.toStringAsFixed(2)}", style: const TextStyle(color: royal, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineWiseList() {
    if (valueData == null || (valueData!['medicineWise'] as List).isEmpty) {
      return const SizedBox.shrink();
    }

    final medicineList = valueData!['medicineWise'] as List;
    final batchList = valueData!['batchWise'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Text(
            "Medicine-wise Value",
            style: TextStyle(
              color: royal,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...medicineList.map((med) {
          final medValue = (med['value'] ?? 0).toDouble();
          final medStock = med['totalStock'] ?? 0;

          // Filter batches for this medicine
          final relatedBatches = batchList
              .where((batch) =>
          batch['medicine'] == med['medicine'] &&
              (batch['value'] ?? 0).toDouble() != 0)
              .toList();

          return Card(
            elevation: 4,
            shadowColor: royal.withValues(alpha: 0.3),
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: royal.withValues(alpha: 0.35)),
            ),
            child: ExpansionTile(
              initiallyExpanded: false,
              leading: const Icon(Icons.medical_services, color: royal),
              title: Text(
                "${med['medicine']} (Stock: $medStock) - ₹${medValue.toStringAsFixed(2)}",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: royal),
              ),
              children: relatedBatches.isEmpty
                  ? [
                const ListTile(
                  title: Text(
                    "No batches with value",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              ]
                  : relatedBatches.map((batch) {
                final batchValue = (batch['value'] ?? 0).toDouble();
                final batchStock = batch['totalStock'] ?? 0;

                return Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: royal.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: royal.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${batch['batchNo']} (Stock: $batchStock)",
                        style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.black87),
                      ),
                      Text(
                        "₹${batchValue.toStringAsFixed(2)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: royal),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text("Stock Value ", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MainNavigation(initialIndex: 2))),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: royal))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (shopDetails != null) _buildHallCard(shopDetails!),
            const SizedBox(height: 16),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 600, // 👈 only form is constrained
            ),
            child: Column(
              children: [
                _buildOverallValue(),
                _buildStockSummaryCard(),
                _buildMedicineWiseList(),
                const SizedBox(height: 70),
              ],
            ),
          ),
        ),],),),);
  }
}
