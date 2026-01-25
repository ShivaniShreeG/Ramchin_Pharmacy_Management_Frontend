import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/config.dart';
import '../../../../public/main_navigation.dart';
import 'dart:async';
import 'Medicine/existinng_medicine.dart';
import 'Medicine/new_medicine.dart';
import 'Medicine/new_batch.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => InventoryPageState();
}

class InventoryPageState extends State<InventoryPage> {
  int? shopId;
  List<Map<String, dynamic>> medicines = [];
  bool isLoading = true;
  Map<String, dynamic>? shopDetails;
  bool showAddMedicine = false;
  bool showAddBatch = false;
  final TextEditingController searchCtrl = TextEditingController();
  List<Map<String, dynamic>> filteredMedicines = [];
  List<String> backendCategories = [];
  bool isCategoryLoading = false;
  bool showExistingMedicine = false;


  @override
  void initState() {
    super.initState();
    loadShopId();
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    setState(() => isCategoryLoading = true);
    final prefs = await SharedPreferences.getInstance();
    shopId = prefs.getInt('shopId');
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/inventory/medicine/categories/$shopId"),
      );

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);

        setState(() {
          backendCategories = data.map((e) => e.toString()).toList();
        });
      }
    } catch (_) {}
    finally {
      setState(() => isCategoryLoading = false);
    }
  }

  bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 900;
  }

  Future loadShopId() async {
    final prefs = await SharedPreferences.getInstance();
    shopId = prefs.getInt('shopId');
    _fetchHallDetails();
    if (shopId != null) fetchMedicines();
    setState(() {});
  }

  Future<void> _fetchHallDetails() async {
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

  Future<void> updateInventoryStatus({
    required int medicineId,
    int? batchId,
    required bool isActive,
  }) async {
    try {
      await http.patch(
        Uri.parse("$baseUrl/inventory/status"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "shop_id": shopId,
          "medicine_id": medicineId,
          if (batchId != null) "batch_id": batchId,
          "is_active": isActive,
        }),
      );

      fetchMedicines();
      _showMessage(isActive ? "Activated successfully" : "Deactivated successfully");

    } catch (e) {
      _showMessage("Status update failed");
    }
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

  Future<void> fetchMedicines() async {
    if (shopId == null) return;

    setState(() => isLoading = true);

    try {
      final url = Uri.parse("$baseUrl/inventory/medicine/shop/$shopId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        setState(() {
          medicines = data
              .map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e),
          )
              .toList();

          filteredMedicines = medicines;
        });
      } else {
        _showMessage("❌ Failed to load medicines");
      }
    } catch (e) {
      _showMessage("❌ Error fetching medicines: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void searchMedicines(String query) {
    final trimmedQuery = query.trim();
    final lowerQuery = trimmedQuery.toLowerCase();
    final numericQuery = trimmedQuery.replaceAll(RegExp(r'\D'), '');

    setState(() {
      filteredMedicines = medicines.where((medicine) {
        // 🔍 NAME MATCH
        final name = (medicine['name'] ?? '').toString().toLowerCase().trim();
        final nameMatch =
            lowerQuery.isNotEmpty && name.contains(lowerQuery);

        // 📅 BATCH EXPIRY MATCH
        final List batches = medicine['batches'] ?? [];

        final batchMatch = numericQuery.isNotEmpty &&
            batches.any((batch) {
              final expiry = batch['expiry_date'];
              if (expiry == null) return false;

              final variants = normalizeDateVariants(expiry);

              return variants.any((v) =>
                  v.replaceAll(RegExp(r'\D'), '').contains(numericQuery));
            });

        return nameMatch || batchMatch;
      }).toList();
    });
  }

  List<String> normalizeDateVariants(String date) {
    try {
      final d = DateTime.parse(date);

      final dd = d.day.toString().padLeft(2, '0');
      final mm = d.month.toString().padLeft(2, '0');
      final yyyy = d.year.toString();
      final yy = yyyy.substring(2);

      return [
        // 🔢 numeric only
        "$dd$mm$yyyy", // DDMMYYYY
        "$mm$dd$yyyy", // MMDDYYYY
        "$yyyy$mm$dd", // YYYYMMDD
        "$yyyy$dd$mm", // YYYYDDMM
        "$dd$mm$yy",   // DDMMYY
        "$mm$dd$yy",   // MMDDYY
        "$yy$mm$dd",   // YYMMDD
        "$yy$dd$mm",   // YYDDMM

        // 📅 with separators
        "$dd/$mm/$yyyy",
        "$mm/$dd/$yyyy",
        "$yyyy/$mm/$dd",
        "$yyyy/$dd/$mm",

        "$dd-$mm-$yyyy",
        "$mm-$dd-$yyyy",
        "$yyyy-$mm-$dd",
        "$yyyy-$dd-$mm",
      ];
    } catch (_) {
      return [];
    }
  }

  Widget medicineCard(Map<String, dynamic> medicine) {
    final batches = medicine['batches'] as List<dynamic>;

    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: BorderSide(color:royal )),
      shadowColor: royal.withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Medicine Name + Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    safeValue(medicine['name']),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: royalblue,
                    ),
                  ),
                ),
                Switch(
                  value: medicine['is_active'] ?? false,
                  activeThumbColor: royalblue,
                  activeTrackColor: royalblue.withValues(alpha: 0.4),
                  inactiveThumbColor: Colors.grey.shade600,
                  inactiveTrackColor: Colors.grey.shade400,
                  onChanged: (val) async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(
                          val ? "Activate Medicine" : "Deactivate Medicine",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: royal,
                          ),
                        ),
                        content: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.black87),
                            children: [
                              const TextSpan(
                                text: "Medicine: ",
                                style: TextStyle(color: royal),
                              ),
                              TextSpan(
                                text: medicine['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: royal,
                                ),
                              ),
                              TextSpan(
                                text:
                                "\n\nDo you want to ${val ? "activate" : "deactivate"} this medicine?",
                                style: const TextStyle(color: royal),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(color: royal),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              "OK",
                              style: TextStyle(color: royal),
                            ),
                          ),
                        ],
                      ),
                    );

                    // ❌ Cancel pressed → revert switch
                    if (result != true) return;

                    // ✅ Proceed after OK
                    updateInventoryStatus(
                      medicineId: medicine['id'],
                      isActive: val,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Chips / Badges
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (shouldShow(medicine['id']))
                  badge(Icons.lock, "Medicine-ID", medicine['id'].toString(), Colors.teal),
                if (shouldShow(medicine['category']))
                  badge(Icons.category, "Category", medicine['category'], Colors.orange),
                if (shouldShow(medicine['stock']))
                  badge(Icons.inventory_2, "Stock", medicine['stock'].toString(), Colors.green),
                if (shouldShow(medicine['ndc_code']))
                  badge(Icons.qr_code, "NDC", medicine['ndc_code'], Colors.blue),
                if (shouldShow(medicine['reorder']))
                  badge(Icons.restart_alt, "Re-Order", medicine['reorder'].toString(), Colors.red),
              ],
            ),
            const SizedBox(height: 12),

            // Divider
            if (batches.isNotEmpty)
              Divider(color: royal.withValues(alpha: 0.4), thickness: 1),

            // Batch list
            if (batches.isNotEmpty)
              ...batches.map(
                    (b) => batchTileImproved(
                  batch: b,
                  medicineName: medicine['name'],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget badge(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            "$label: $value",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  bool isExpired(String expiryDate) {
    final expiry = DateTime.parse(expiryDate);
    return expiry.isBefore(DateTime.now());
  }

  bool isShortDated(String expiryDate, {int thresholdDays = 60}) {
    final expiry = DateTime.parse(expiryDate);
    final now = DateTime.now();
    final diff = expiry.difference(now).inDays;
    return diff > 0 && diff <= thresholdDays;
  }

  int daysLeft(String expiryDate) {
    final expiry = DateTime.parse(expiryDate);
    return expiry.difference(DateTime.now()).inDays;
  }

  Widget expiryBadge(String expiryDate) {
    if (isExpired(expiryDate)) {
      return _badge("Expired", Colors.red);
    }

    if (isShortDated(expiryDate)) {
      return _badge(
        "${daysLeft(expiryDate)} days left",
        Colors.orange,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget responsiveDetails({
    required BuildContext context,
    required List<Widget> left,
    required List<Widget> right,
  }) {
    if (!isDesktop(context)) {
      // Mobile → single column
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [...left, ...right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: left,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: right,
          ),
        ),
      ],
    );
  }

  Widget batchTileImproved({
    required Map<String, dynamic> batch,
    required String medicineName,

  })
  {
    final Map<String, dynamic>? purchaseDetails =
    batch['purchase_details'] as Map<String, dynamic>?;
    final bool hasPurchasedDetails =
        shouldShow(batch['quantity']) ||
            shouldShow(batch['free_quantity']) ||
            (purchaseDetails != null && shouldShow(purchaseDetails['rate_per_quantity'])) ||
            (purchaseDetails != null && shouldShow(purchaseDetails['gst_percent'])) ||
            (purchaseDetails != null && shouldShow(purchaseDetails['gst_per_quantity'])) ||
            (purchaseDetails != null && shouldShow(purchaseDetails['base_amount'])) ||
            (purchaseDetails != null && shouldShow(purchaseDetails['total_gst_amount'])) ||
            (purchaseDetails != null && shouldShow(purchaseDetails['purchase_price'])) ||
            (purchaseDetails != null && shouldShow(purchaseDetails['purchase_date'])) ||
            shouldShow(batch['supplier']?['name']) ||
            shouldShow(batch['supplier']?['phone']) ||
            shouldShow(batch['HSN']);

    return Container(


      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: royal.withValues(alpha: 0.6)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12), // 👈 FIX
        child: ExpansionTile(
          backgroundColor: royal.withValues(alpha: 0.05),
          collapsedBackgroundColor: Colors.white,
          iconColor: royalblue,
          collapsedIconColor: royal,
          textColor: royalblue,
          collapsedTextColor: royal,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            children: [

              Expanded(
                child: Text(
                  "${batch['batch_no']}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: royal,
                  ),
                ),
              ),
              if (batch['expiry_date'] != null)
                expiryBadge(batch['expiry_date']),
              Switch(
                activeThumbColor: royalblue,
                activeTrackColor: royalblue.withValues(alpha: 0.4),
                inactiveThumbColor: Colors.grey.shade600,
                inactiveTrackColor: Colors.grey.shade400,
                value: batch['is_active'] ?? true,
                onChanged: (val) async {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(
                        val ? "Activate Batch" : "Deactivate Batch",
                        style: const TextStyle(fontWeight: FontWeight.bold,color: royal),
                      ),
                      content: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black87),
                          children: [
                            const TextSpan(text: "Medicine: ",style: TextStyle(color: royal)),
                            TextSpan(
                              text: medicineName,
                              style: const TextStyle(fontWeight: FontWeight.bold,color: royal),
                            ),
                            const TextSpan(text: "\nBatch: ",style: TextStyle(color: royal)),
                            TextSpan(
                              text: batch['batch_no'],
                              style: const TextStyle(fontWeight: FontWeight.bold,color: royal),
                            ),
                            TextSpan(
                                text:
                                "\n\nDo you want to ${val ? "activate" : "deactivate"} this batch?",
                                style: TextStyle(color: royal)
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancel",style: TextStyle(color: royal)),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("OK",style: TextStyle(color: royal)),
                        ),
                      ],
                    ),
                  );

                  // ❌ Cancel → nothing happens
                  if (result != true) return;

                  // ✅ Proceed
                  updateInventoryStatus(
                    medicineId: batch['medicine_id'],
                    batchId: batch['id'],
                    isActive: val,
                  );
                },
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child:isDesktop(context)
                  ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= MEDICINE DETAILS =================
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            "Medicine Details",
                            style: TextStyle(fontWeight: FontWeight.bold, color: royal),
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (shouldShow(batch['rack_no']))
                          infoRow("Rack No", batch['rack_no'] ?? "-"),
                        if (shouldShow(batch['total_stock']))
                          infoRow("Total Stock", batch['total_stock'].toString()),
                        if (shouldShow(batch['total_quantity']))
                          infoRow("Total Quantity", batch['total_quantity'].toString()),
                        if (shouldShow(batch['manufacture_date']))
                          infoRow("Manufacture Date", formatDate(batch['manufacture_date'])),
                        if (shouldShow(batch['expiry_date']))
                          infoRow("Expiry Date", formatDate(batch['expiry_date'])),
                        if (shouldShow(batch['unit']))
                          infoRow("Unit", batch['unit'].toString()),
                        if (shouldShow(batch['purchase_price_quantity']))
                          infoRow("Purchase Price/Qty", "₹${batch['purchase_price_quantity']}"),
                        if (shouldShow(batch['purchase_price_unit']))
                          infoRow("Purchase Price/Unit", batch['purchase_price_unit']?.toString() ?? "-"),
                        if (shouldShow(batch['selling_price_quantity']))
                          infoRow("Selling Price/Qty", "₹${batch['selling_price_quantity']}"),
                        if (shouldShow(batch['selling_price_unit']))
                          infoRow("Selling Price/Unit", "₹${batch['selling_price_unit']}"),
                        if (shouldShow(batch['profit']))
                          infoRow("Profit", batch['profit']?.toString() ?? "-"),
                        if (shouldShow(batch['mrp']))
                          infoRow("MRP", batch['mrp']?.toString() ?? "-"),
                      ],
                    ),
                  ),

                  const SizedBox(width: 32),

                  // ================= PURCHASED DETAILS =================
                  if (hasPurchasedDetails)
                    Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child:
                          Text(
                            "Purchased Details",
                            style: TextStyle(fontWeight: FontWeight.bold, color: royal),
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (shouldShow(batch['quantity']))
                          infoRow("Purchased Quantity", batch['quantity'].toString()),
                        if (shouldShow(batch['free_quantity']))
                          infoRow("Free Quantity", batch['free_quantity'].toString()),
                        if (purchaseDetails != null && shouldShow(purchaseDetails['rate_per_quantity']))
                          infoRow(
                            "Rate / Quantity",
                            "₹${purchaseDetails['rate_per_quantity']}",
                          ),
                        if (purchaseDetails != null && shouldShow(purchaseDetails['gst_percent']))
                          infoRow(
                            "GST %",
                            "${purchaseDetails['gst_percent']}%",
                          ),
                        if (purchaseDetails != null && shouldShow(purchaseDetails['gst_per_quantity']))
                          infoRow(
                            "GST Amount / Qty",
                            "₹${purchaseDetails['gst_per_quantity']}",
                          ),
                        if (purchaseDetails != null && shouldShow(purchaseDetails['base_amount']))
                          infoRow(
                            "Base Amount",
                            "₹${purchaseDetails['base_amount']}",
                          ),
                        if (purchaseDetails != null && shouldShow(purchaseDetails['total_gst_amount']))
                          infoRow(
                            "Total GST Amount",
                            "₹${purchaseDetails['total_gst_amount']}",
                          ),
                        if (purchaseDetails != null && shouldShow(purchaseDetails['purchase_price']))
                          infoRow(
                            "Purchased Price",
                            "₹${purchaseDetails['purchase_price']}",
                          ),
                        if (shouldShow(batch['supplier']?['name']))
                          infoRow("Supplier Name", batch['supplier']?['name'] ?? "-"),
                        if (shouldShow(batch['supplier']?['phone']))
                          infoRow("Supplier Phone", batch['supplier']?['phone'] ?? "-"),
                        if (shouldShow(batch['HSN']))
                          infoRow("HSN Code", batch['HSN'] ?? "-"),
                        if (purchaseDetails != null && shouldShow(purchaseDetails['purchase_date']))
                          infoRow(
                            "Purchase Date",
                            formatDate(purchaseDetails['purchase_date']),
                          ),
                      ],
                    ),
                  ),
                ],
              )

                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Medicine Details Section
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Center(
                                    child:
                                    const Text(
                                      "Medicine Details",
                                      style: TextStyle(fontWeight: FontWeight.bold, color: royal),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (shouldShow(batch['rack_no']))
                                        infoRowMob("Rack No", batch['rack_no'] ?? "-"),
                                      if (shouldShow(batch['total_stock']))
                                        infoRowMob("Total Stock", batch['total_stock'].toString()),
                                      if (shouldShow(batch['total_quantity']))
                                        infoRowMob("Total Quantity", batch['total_quantity'].toString()),
                                      if (shouldShow(batch['manufacture_date']))
                                        infoRowMob("Manufacture Date", formatDate(batch['manufacture_date'])),
                                      if (shouldShow(batch['expiry_date']))
                                        infoRowMob("Expiry Date", formatDate(batch['expiry_date'])),
                                      if (shouldShow(batch['HSN']))
                                        infoRowMob("HSN Code", batch['HSN'] ?? "-"),
                                      if (shouldShow(batch['unit']))
                                        infoRowMob("Unit", batch['unit'].toString()),
                                      if (shouldShow(batch['purchase_price_quantity']))
                                        infoRowMob("Purchase Price/Qty", "₹${batch['purchase_price_quantity']}"),
                                      if (shouldShow(batch['purchase_price_unit']))
                                        infoRowMob("Purchase Price/Unit", batch['purchase_price_unit']?.toString() ?? "-"),
                                      if (shouldShow(batch['selling_price_quantity']))
                                        infoRowMob("Selling Price/Qty", "₹${batch['selling_price_quantity']}"),
                                      if (shouldShow(batch['selling_price_unit']))
                                        infoRowMob("Selling Price/Unit", "₹${batch['selling_price_unit']}"),
                                      if (shouldShow(batch['profit']))
                                        infoRowMob("Profit", batch['profit']?.toString() ?? "-"),
                                      if (shouldShow(batch['mrp']))
                                        infoRowMob("MRP", batch['mrp']?.toString() ?? "-"),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),
                              if (hasPurchasedDetails)
                                Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Center(
                                    child:
                                    const Text(
                                      "Purchased Details",
                                      style: TextStyle(fontWeight: FontWeight.bold, color: royal),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (shouldShow(batch['quantity']))
                                        infoRowMob("Purchased Quantity", batch['quantity'].toString()),
                                      if (shouldShow(batch['free_quantity']))
                                        infoRowMob("Free Quantity", batch['free_quantity'].toString()),
                                      if (purchaseDetails != null && shouldShow(purchaseDetails['rate_per_quantity']))
                                        infoRowMob("Rate/ Quantity", "₹${purchaseDetails['rate_per_quantity']}"),
                                      if (purchaseDetails != null && shouldShow(purchaseDetails['gst_percent']))
                                        infoRowMob("GST %/Quantity", "${purchaseDetails['gst_percent']}%"),
                                      if (purchaseDetails != null && shouldShow(purchaseDetails['gst_per_quantity']))
                                        infoRowMob("GST Amount/Quantity", "₹${purchaseDetails['gst_per_quantity']}"),
                                      if (purchaseDetails != null && shouldShow(purchaseDetails['base_amount']))
                                        infoRowMob("Base Amount", "₹${purchaseDetails['base_amount']}"),
                                      if (purchaseDetails != null && shouldShow(purchaseDetails['total_gst_amount']))
                                        infoRowMob("Total GST Amount", "₹${purchaseDetails['total_gst_amount']}"),
                                      if (purchaseDetails != null && shouldShow(purchaseDetails['purchase_price']))
                                        infoRowMob("Purchased price", "₹${purchaseDetails['purchase_price']}"),
                                      if (shouldShow(batch['supplier']?['name']))
                                        infoRowMob("Supplier Name", batch['supplier']?['name'] ?? "-",),
                                      if (shouldShow(batch['supplier']?['phone']))
                                        infoRowMob("Supplier Phone", batch['supplier']?['phone'] ?? "-",),
                                      if (purchaseDetails != null && shouldShow(purchaseDetails['purchase_date']))
                                        infoRowMob("Date", formatDate(purchaseDetails['purchase_date'])),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String normalizeDate(String date) {
    try {
      final d = DateTime.parse(date);

      final day = d.day.toString().padLeft(2, '0');
      final month = d.month.toString().padLeft(2, '0');
      final year = d.year.toString();

      return "$day$month$year"; // 30022026
    } catch (_) {
      return "";
    }
  }

  Widget infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: royalblue),
            ),
          ),
          Expanded(child: Text(":$value", style: const TextStyle(color: royal))),
        ],
      ),
    );
  }

  Widget infoRowMob(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: royalblue),
            ),
          ),
          Expanded(child: Text(":$value", style: const TextStyle(color: royal))),
        ],
      ),
    );
  }

  String safeValue(dynamic value) {
    if (value == null) return "-";
    if (value is String && value.trim().isEmpty) return "-";
    return value.toString();
  }

  bool shouldShow(dynamic value) {
    if (value == null) return false;
    if (value is String && value.trim().isEmpty) return false;
    if (value is num && value == 0) return false;
    return true;
  }

  String formatDate(String? date) {
    if (date == null || date.isEmpty) return "-";
    try {
      final d = DateTime.parse(date);
      return "${d.day}-${d.month}-${d.year}";
    } catch (_) {
      return "-";
    }
  }

  Widget searchBar() {
    return TextField(
      controller: searchCtrl,
      onChanged: searchMedicines,
      cursorColor: royal,
      style: TextStyle(color: royal),
      decoration: InputDecoration(
        hintText: "Search by medicine name or expiry date",
        hintStyle: TextStyle(color: royal),
        prefixIcon: const Icon(Icons.search),
        prefixIconColor: royal,
        suffixIcon: searchCtrl.text.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            searchCtrl.clear();
            setState(() => filteredMedicines = medicines);
          },
        )
            : null,
        suffixIconColor: royal,
        filled: true,
        fillColor: royal.withValues(alpha: 0.1),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: royal, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: royal, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  final ButtonStyle outlinedRoyalButton = ElevatedButton.styleFrom(
    backgroundColor: Colors.white, // white background
    foregroundColor: royal,        // text & icon color
    elevation: 0,
    side: const BorderSide(color: royal, width: 1.5),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    padding: const EdgeInsets.symmetric(vertical: 14),
  );

  Widget actionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: outlinedRoyalButton,
                onPressed: () {
                  setState(() {
                    showAddMedicine = !showAddMedicine;
                    showAddBatch = false;
                    showExistingMedicine = false;
                  });
                },
                child: Text(
                  showAddMedicine ? "Close Medicine Form" : "Add Medicine",
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: outlinedRoyalButton,
                onPressed: () {
                  setState(() {
                    showAddBatch = !showAddBatch;
                    showAddMedicine = false;
                    showExistingMedicine = false;
                  });
                },
                child: Text(
                  showAddBatch ? "Close Batch Form" : "Add Batch",
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // 🔹 NEW BUTTON
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: SizedBox(
            width: double.infinity,  // ← makes button full-width
            child: ElevatedButton(
              style: outlinedRoyalButton,
              onPressed: () {
                setState(() {
                  showExistingMedicine = !showExistingMedicine;
                  showAddMedicine = false;
                  showAddBatch = false;
                });
              },
              child: Text(
                showExistingMedicine
                    ? "Close Existing Medicines"
                    : "Add Existing Medicine",
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (shopId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text(
          "Medicines",
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
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: royal))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child:
        Column(
          children: [
            const SizedBox(height: 16),
            if (shopDetails != null) _buildHallCard(shopDetails!),
            const SizedBox(height: 16),
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: actionButtons(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  if (showAddMedicine)
                    AddMedicineForm(
                      shopId: shopId.toString(),
                      fetchMedicines: fetchMedicines,
                      onClose: (val) => setState(() => showAddMedicine = val),
                      categories: backendCategories,
                    ),
                  if (showExistingMedicine)
                    ExistingMedicineWidget(
                      shopId: shopId.toString(),
                      fetchMedicines: fetchMedicines,
                      onClose: (val) => setState(() => showExistingMedicine = val),
                      categories: backendCategories,
                    ),
                  if (showAddBatch)
                    AddBatchForm(
                      shopId: shopId.toString(),
                      fetchMedicines: fetchMedicines,
                      onClose: (val) => setState(() => showAddBatch = val),
                      medicines: medicines,
                    ),
                  const Divider(color: royal,),
                  if (medicines.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text("No medicines found",style: TextStyle(color: royal),),
                    ),
                  if (medicines.isNotEmpty)
                    searchBar(),
                  const SizedBox(height: 18),
                  ...filteredMedicines.map(
                        (medicine) => Padding(
                      padding: const EdgeInsets.only(bottom: 18.0),
                      child: medicineCard(medicine),
                    ),
                  ),
                  const SizedBox(height: 70),
                ],
              ),

            ),
          ],),),
    );
  }
}