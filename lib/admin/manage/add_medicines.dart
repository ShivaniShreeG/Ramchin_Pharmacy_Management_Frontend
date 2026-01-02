import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../public/config.dart';
import '../../../../public/main_navigation.dart';
import 'package:flutter/services.dart';
import 'dart:async';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  int? shopId;
  List<Map<String, dynamic>> medicines = [];
  bool isLoading = true;
  Map<String, dynamic>? shopDetails;
  bool showAddMedicine = false;
  bool showAddBatch = false;
  final TextEditingController searchCtrl = TextEditingController();

  List<Map<String, dynamic>> filteredMedicines = [];


  bool isEditingProfit = false;
  bool isEditingSelling = false;
  Timer? debounce;
  bool isBatchTaken = false;

  @override
  void initState() {
    super.initState();
    loadShopId();
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
    final numericQuery = query.replaceAll(RegExp(r'\D'), '');
    final lowerQuery = query.toLowerCase();

    setState(() {
      filteredMedicines = medicines.where((medicine) {
        final nameMatch =
            medicine['name']?.toLowerCase().contains(lowerQuery) ?? false;

        final batchMatch = (medicine['batches'] as List).any((batch) {
          final expiry = batch['expiry_date'];
          if (expiry == null) return false;

          final variants = normalizeDateVariants(expiry);

          return variants.any((v) =>
          v.replaceAll(RegExp(r'\D'), '').contains(numericQuery) ||
              v.toLowerCase().contains(lowerQuery));
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

  Widget batchTileImproved({
    required Map<String, dynamic> batch,
    required String medicineName,
  }) {
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
              child: Column(
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
                                  const Text(
                                    "Medicine Details",
                                    style: TextStyle(fontWeight: FontWeight.bold, color: royal),
                                  ),
                                  const SizedBox(height: 6),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
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
                                      if (shouldShow(batch['HSN']))
                                        infoRow("HSN Code", batch['HSN'] ?? "-"),
                                      if (shouldShow(batch['unit']))
                                        infoRow("Unit", batch['unit'].toString()),
                                      if (shouldShow(batch['purchase_price_quantity']))
                                        infoRow("Purchase Price/Quantity", "₹${batch['purchase_price_quantity']}"),
                                      if (shouldShow(batch['purchase_price_unit']))
                                        infoRow("Purchase Price/Unit", batch['purchase_price_unit']?.toString() ?? "-"),
                                      if (shouldShow(batch['selling_price_quantity']))
                                        infoRow("Selling Price/Quantity", "₹${batch['selling_price_quantity']}"),
                                      if (shouldShow(batch['selling_price_unit']))
                                        infoRow("Selling Price/Unit", "₹${batch['selling_price_unit']}"),
                                      if (shouldShow(batch['profit']))
                                        infoRow("Profit", batch['profit']?.toString() ?? "-"),
                                      if (shouldShow(batch['mrp']))
                                        infoRow("MRP", batch['mrp']?.toString() ?? "-"),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    "Purchased Details",
                                    style: TextStyle(fontWeight: FontWeight.bold, color: royal),
                                  ),
                                  const SizedBox(height: 6),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (shouldShow(batch['quantity']))
                                        infoRow("Purchased Quantity", batch['quantity'].toString()),
                                      if (shouldShow(batch['free_quantity']))
                                        infoRow("Free Quantity", batch['free_quantity'].toString()),
                                      if (shouldShow(batch['purchase_details']['rate_per_quantity']))
                                        infoRow("Rate/ Quantity", "₹${batch['purchase_details']['rate_per_quantity']}"),
                                      if (shouldShow(batch['purchase_details']['gst_percent']))
                                        infoRow("GST %/Quantity", "${batch['purchase_details']['gst_percent']}%"),
                                      if (shouldShow(batch['purchase_details']['gst_per_quantity']))
                                        infoRow("GST Amount/Quantity", "₹${batch['purchase_details']['gst_per_quantity']}"),
                                      if (shouldShow(batch['purchase_details']['base_amount']))
                                        infoRow("Base Amount", "₹${batch['purchase_details']['base_amount']}"),
                                      if (shouldShow(batch['purchase_details']['total_gst_amount']))
                                        infoRow("Total GST Amount", "₹${batch['purchase_details']['total_gst_amount']}"),
                                      if (shouldShow(batch['purchase_details']['purchase_price']))
                                        infoRow("Purchased price", "₹${batch['purchase_details']['purchase_price']}"),
                                      if (shouldShow(batch['supplier']?['name']))
                                        infoRow("Supplier Name", batch['supplier']?['name'] ?? "-",),
                                      if (shouldShow(batch['supplier']?['phone']))
                                        infoRow("Supplier Phone", batch['supplier']?['phone'] ?? "-",),
                                      if (shouldShow(batch['purchase_details']['purchase_date']))
                                        infoRow("Date", formatDate(batch['purchase_details']['purchase_date'])),
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

  Widget addMedicineForm() {
    final reorderCtrl = TextEditingController(text: '10');
    final nameCtrl = TextEditingController();
    bool isNameTaken = false; // to track if name exists
    final ndcCtrl = TextEditingController();
    final List<String> medicineCategories = [
      "Tablets",
      "Syrups",
      "Drops",
      "Ointments",
      "Creams",
      "Soap",
      "Other",
    ];
    String selectedCategory = medicineCategories.first;
    final batchCtrl = TextEditingController(text: "01");
    final rackCtrl = TextEditingController();
    final quantityCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final profitCtrl = TextEditingController();
    final sellerCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final hsnCtrl = TextEditingController();
    final mrpCtrl = TextEditingController();
    DateTime? mfgDate;
    DateTime? expDate;
    int? selectedSupplierId;     // ✅ real supplier id
    bool supplierFound = false; // ✅ for UI icon
    final freeQtyCtrl = TextEditingController();
    double totalQuantity = 0;
    double totalStock = 0; // ✅ FIX
    DateTime purchaseDate = DateTime.now(); // ✅ default today
    final ratePerQtyCtrl = TextEditingController();
    final gstCtrl = TextEditingController();
    double sellingPerUnit = 0;
    double sellingPerQuantity = 0;
    double purchasePerUnit = 0;
    double purchasePerQuantity = 0;
    double gstPerQuantity = 0;
    double baseAmount = 0;
    double totalGstAmount = 0;
    double purchasePrice = 0;
    final TextEditingController otherCategoryCtrl = TextEditingController();
    bool isOtherCategory = false;
    Timer? phoneDebounce;

    Widget confirmMedicineDialog() {
      final finalCategory =
      isOtherCategory ? otherCategoryCtrl.text.trim() : selectedCategory;
      Widget infoTile(String label, String value,
          {Color valueColor = royal}) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  "$label:",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: royal,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value.isEmpty ? "-" : value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return AlertDialog(
        insetPadding: const EdgeInsets.all(16),
        contentPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: royal, width: 1.2),
        ),
        title: const Center(
          child: Text(
            "Confirm Medicine Details",
            style: TextStyle(fontWeight: FontWeight.bold, color: royal),
          ),
        ),
        content: SingleChildScrollView(
          child: Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: royal, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// 🔹 BASIC INFO
                  infoTile("Name", nameCtrl.text),
                  infoTile("Category", finalCategory),
                  if (ndcCtrl.text.trim().isNotEmpty)
                    infoTile("NDC", ndcCtrl.text),
                  infoTile("Batch No", batchCtrl.text),
                  if (rackCtrl.text.trim().isNotEmpty)
                    infoTile("Rack No", rackCtrl.text),
                  if (hsnCtrl.text.trim().isNotEmpty)
                    infoTile("HSN Code", hsnCtrl.text),

                  const Divider(color: royal),

                  /// 🔹 DATES
                  infoTile("MFG Date",
                      mfgDate?.toLocal().toString().split(' ')[0] ?? "-"),
                  infoTile("EXP Date",
                      expDate?.toLocal().toString().split(' ')[0] ?? "-"),
                  infoTile("Purchase Date",
                      purchaseDate.toLocal().toString().split(' ')[0]),

                  const Divider(color: royal),

                  /// 🔹 STOCK
                  infoTile("Quantity", quantityCtrl.text),
                  if (freeQtyCtrl.text.trim().isNotEmpty &&
                      freeQtyCtrl.text.trim() != "0")
                    infoTile("Free Qty", freeQtyCtrl.text),
                  infoTile("Total Quantity", totalQuantity.toString()),
                  infoTile("Unit / Qty", unitCtrl.text),
                  infoTile("Total Stock", totalStock.toString()),

                  const Divider(color: royal),

                  /// 🔹 SUPPLIER
                  infoTile("Supplier Phone", phoneCtrl.text),
                  infoTile("Supplier Name", sellerCtrl.text),
                  infoTile("Supplier ID",
                      selectedSupplierId?.toString() ?? "-"),

                  const Divider(color: royal),

                  /// 🔹 PRICING
                  infoTile("Rate / Qty", "₹${ratePerQtyCtrl.text}"),
                  if (gstCtrl.text.trim().isNotEmpty)
                    infoTile("GST % / Qty", gstCtrl.text),
                  if (gstPerQuantity > 0)
                    infoTile(
                      "GST Amount / Qty",
                      "₹${gstPerQuantity.toStringAsFixed(2)}",
                    ),

                  infoTile("Base Amount",
                      "₹${baseAmount.toStringAsFixed(2)}"),
                  if (totalGstAmount > 0)
                    infoTile(
                      "Total GST",
                      "₹${totalGstAmount.toStringAsFixed(2)}",
                      valueColor: Colors.orange,
                    ),

                  const Divider(color: royal),

                  /// 🔹 PURCHASE & SELLING
                  infoTile("Purchase / Qty",
                      "₹${purchasePerQuantity.toStringAsFixed(2)}",
                      valueColor: Colors.red),
                  infoTile("Purchase / Unit",
                      "₹${purchasePerUnit.toStringAsFixed(2)}",
                      valueColor: Colors.red),
                  infoTile("Selling / Qty",
                      "₹${sellingPerQuantity.toStringAsFixed(2)}"),
                  infoTile("Selling / Unit",
                      "₹${sellingPerUnit.toStringAsFixed(2)}"),
                  infoTile("MRP / Quantity", mrpCtrl.text),
                  infoTile("Profit %",
                      profitCtrl.text),

                  const Divider(color:royal,thickness: 1.2),

                  /// 🔥 FINAL TOTAL
                  infoTile(
                    "Total Purchase Price",
                    "₹${purchasePrice.toStringAsFixed(2)}",
                    valueColor: Colors.green,
                  ),
                ],
              ),
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: royal), // ✅ outline color
              foregroundColor: royal,               // ✅ text & icon color
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel",style: TextStyle(color: royal),),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: royal,foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Confirm"),
          ),
        ],
      );
    }

    bool isFormValid() {
      return
        nameCtrl.text.trim().isNotEmpty &&
            !isNameTaken &&

            selectedCategory.isNotEmpty &&
            (!isOtherCategory || otherCategoryCtrl.text.trim().isNotEmpty) &&

            batchCtrl.text.trim().isNotEmpty &&

            quantityCtrl.text.trim().isNotEmpty &&
            (double.tryParse(quantityCtrl.text) ?? 0) > 0 &&

            unitCtrl.text.trim().isNotEmpty &&
            (double.tryParse(unitCtrl.text) ?? 0) > 0 &&

            ratePerQtyCtrl.text.trim().isNotEmpty &&
            (double.tryParse(ratePerQtyCtrl.text) ?? 0) > 0 &&

            profitCtrl.text.trim().isNotEmpty &&
            (double.tryParse(profitCtrl.text) ?? 0) >= 0 &&

            mrpCtrl.text.trim().isNotEmpty &&
            (double.tryParse(mrpCtrl.text) ?? 0) > 0 &&

            supplierFound &&
            selectedSupplierId != null &&

            phoneCtrl.text.length == 10 &&

            mfgDate != null &&
            expDate != null &&
            expDate!.isAfter(mfgDate!) ;

    }


    return StatefulBuilder(
      builder: (context, setLocalState) {

        void calculateStock() {
          final qty = double.tryParse(quantityCtrl.text) ?? 0;
          final freeQty = double.tryParse(freeQtyCtrl.text) ?? 0;
          final unit = double.tryParse(unitCtrl.text) ?? 0;

          totalQuantity = qty + freeQty;     // ✅ TOTAL QTY
          totalStock = totalQuantity * unit;      // ✅ TOTAL STOCK


          setLocalState(() {});
        }

        void calculatePurchaseValues() {
          final qty = double.tryParse(quantityCtrl.text) ?? 0;
          final rate = double.tryParse(ratePerQtyCtrl.text) ?? 0;
          final gstPercent = double.tryParse(gstCtrl.text) ?? 0;
          final unit = double.tryParse(unitCtrl.text) ?? 0;
          final mrp = double.tryParse(mrpCtrl.text) ?? 0;
          final profitPercent = double.tryParse(profitCtrl.text) ?? 0;


          if (qty <= 0 || unit <= 0) {
            purchasePerUnit = 0;
            purchasePerQuantity = 0;
            sellingPerUnit = 0;
            sellingPerQuantity = 0;
            setLocalState(() {});
            return;
          }
          baseAmount = qty * rate;

          // GST
          gstPerQuantity = rate * gstPercent / 100;
          totalGstAmount = gstPerQuantity * qty;

          // PURCHASE PRICE
          purchasePrice = baseAmount + totalGstAmount;
          purchasePerQuantity = purchasePrice / qty;   // ✔ strip price
          purchasePerUnit = purchasePerQuantity / unit; // ✔ tablet price
          if (purchasePerQuantity <= 0 || qty <= 0) return;

          // Profit-based selling
          final calculatedSelling =
              purchasePerQuantity + (purchasePerQuantity * profitPercent / 100);

          // ✅ MRP CAP
          sellingPerQuantity = calculatedSelling > mrp ? mrp : calculatedSelling;

          // Quantity price
          sellingPerUnit = sellingPerQuantity / unit;
          setLocalState(() {});
          // TOTAL STOCK

        }

        void resetForm() {
          nameCtrl.clear();
          ndcCtrl.clear();
          batchCtrl.text = "01";
          rackCtrl.clear();
          quantityCtrl.clear();
          freeQtyCtrl.clear();
          unitCtrl.clear();
          ratePerQtyCtrl.clear();
          gstCtrl.clear();
          mrpCtrl.clear();
          profitCtrl.clear();
          sellerCtrl.clear();
          phoneCtrl.clear();
          hsnCtrl.clear();
          reorderCtrl.clear();
          otherCategoryCtrl.clear();

          selectedCategory = medicineCategories.first;
          isOtherCategory = false;

          mfgDate = null;
          expDate = null;
          purchaseDate = DateTime.now();

          selectedSupplierId = null;
          supplierFound = false;

          totalQuantity = 0;
          totalStock = 0;
          gstPerQuantity = 0;
          baseAmount = 0;
          totalGstAmount = 0;
          purchasePrice = 0;
          purchasePerUnit = 0;
          purchasePerQuantity = 0;
          sellingPerUnit = 0;
          sellingPerQuantity = 0;
          isNameTaken = false;
          phoneDebounce?.cancel();
          setLocalState(() {});
        }

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.all(10),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: royal, // 👈 border color
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

            const Center(
            child: Text("Add Medicine & Batch",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: royal)),
          ),

          const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = MediaQuery
                    .of(context)
                    .size
                    .width >= 1000;

                double fieldWidth(BoxConstraints c) {
                  if (!isDesktop) return c.maxWidth;
                  return (c.maxWidth - 32) / 3; // 3 columns with spacing
                }
                int columnCount;
                if (constraints.maxWidth >= 1000) {
                  columnCount = 4; // large desktop
                } else if (constraints.maxWidth >= 800) {
                  columnCount = 3; // tablet
                } else if (constraints.maxWidth >= 600) {
                  columnCount = 2; // tablet
                } else {
                  columnCount = 1; // mobile
                }

                double columnWidth =
                    (constraints.maxWidth - ((columnCount - 1) * 16)) / columnCount;

                return Wrap(
                  spacing: 16,
                  runSpacing: 14,
                  children: [

                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Name",
                        field: StatefulBuilder(
                          builder: (context, setLocalState) {
                            Timer? debounce;
                            return TextFormField(
                              controller: nameCtrl,
                              style: TextStyle(color: royal),
                              cursorColor: royal,
                              decoration: InputDecoration(
                                hintText: "Enter Medicine name",
                                hintStyle: TextStyle(color: royal),
                                filled: true,
                                fillColor: royal.withValues(alpha: 0.1),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: royal, width: 0.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: royal, width: 1.5),
                                ),
                                suffixIcon: isNameTaken
                                    ? const Icon(
                                    Icons.error, color: Colors.red)
                                    : const Icon(
                                    Icons.check, color: Colors.green),
                              ),
                              onChanged: (value) {
                                if (debounce?.isActive ?? false) debounce!.cancel();
                                debounce = Timer(const Duration(
                                    milliseconds: 500), () async {
                                  if (value
                                      .trim()
                                      .isEmpty) {
                                    setLocalState(() =>
                                    isNameTaken = false);
                                    return;
                                  }
                                  try {
                                    final url = Uri.parse(
                                        "$baseUrl/inventory/medicine/check-name/$shopId?name=$value");
                                    final response = await http.get(url);
                                    if (response.statusCode == 200) {
                                      final data = jsonDecode(
                                          response.body);
                                      setLocalState(() =>
                                      isNameTaken =
                                          data['exists'] ?? false);
                                    } else {
                                      setLocalState(() =>
                                      isNameTaken = false);
                                    }
                                  } catch (_) {
                                    setLocalState(() =>
                                    isNameTaken = false);
                                  }
                                });
                                setLocalState(() {});
                              },
                            );
                          },
                        ),
                      ),
                    ),

                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Category",
                        field: DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          iconEnabledColor: royal,
                          style: const TextStyle(color: royal),
                          decoration: _inputDecoration("Select category"),
                          items: medicineCategories
                              .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) {
                            setLocalState(() {
                              selectedCategory = v!;
                              isOtherCategory = v == "Other";
                              if (!isOtherCategory) otherCategoryCtrl.clear();
                            });
                          },
                        ),
                      ),
                    ),

                    if (isOtherCategory)
                      SizedBox(
                        width: fieldWidth(constraints),
                        child: labeledField(
                          label: "Custom Category",
                          field: TextFormField(
                            controller: otherCategoryCtrl,
                            textCapitalization: TextCapitalization.words,
                            cursorColor: royal,
                            style: const TextStyle(color: royal),
                            onChanged: (_) => setLocalState(() {}),
                            decoration: _inputDecoration(
                                "Enter custom category"),
                          ),
                        ),
                      ),

                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "NDC",
                        field: TextFormField(
                          controller: ndcCtrl,
                          cursorColor: royal,
                          keyboardType: TextInputType.visiblePassword,
                          style: const TextStyle(color: royal),
                          decoration: _inputDecoration(
                              "Enter NDC code (optional)"),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Reorder-Level",
                        field: TextFormField(
                          cursorColor: royal,
                          style: TextStyle(color: royal),
                          keyboardType: TextInputType.number,
                          controller: reorderCtrl,
                          onChanged: (_) => setLocalState(() {}),
                          // ✅ update button state
                          decoration: _inputDecoration("Enter Re-order value"),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Batch No",
                        field: TextFormField(
                          controller: batchCtrl,
                          cursorColor: royal,
                          onChanged: (_) => setLocalState(() {}),
                          keyboardType: TextInputType.visiblePassword,
                          style: const TextStyle(color: royal),
                          decoration: _inputDecoration("Enter Batch no"),
                        ),
                      ),
                    ),

                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Rack No",
                        field: TextFormField(
                          controller: rackCtrl,
                          cursorColor: royal,
                          keyboardType: TextInputType.visiblePassword,
                          style: const TextStyle(color: royal),
                          decoration: _inputDecoration("Optional"),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "MFG Date",
                        field: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: royal,
                            backgroundColor: royal.withValues(alpha: 0.1),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            side: const BorderSide(
                                color: royal, width: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: royal,
                                      onPrimary: Colors.white,
                                      onSurface: royal,
                                    ),
                                    textButtonTheme: TextButtonThemeData(
                                      style: TextButton.styleFrom(
                                          foregroundColor: royal),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) setLocalState(() => mfgDate = picked);
                          },
                          child: Text(
                            mfgDate == null ? "Select date" : mfgDate!
                                .toLocal().toString().split(' ')[0],
                            style: TextStyle(color: royal),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "EXP Date",
                        field: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: royal,
                            backgroundColor: royal.withValues(alpha: 0.1),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            side: const BorderSide(
                                color: royal, width: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: royal,
                                      onPrimary: Colors.white,
                                      onSurface: royal,
                                    ),
                                    textButtonTheme: TextButtonThemeData(
                                      style: TextButton.styleFrom(
                                          foregroundColor: royal),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) setLocalState(() => expDate = picked);
                          },
                          child: Text(
                            expDate == null ? "Select date" : expDate!
                                .toLocal().toString().split(' ')[0],
                            style: TextStyle(color: royal),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "HSN Code",
                        field: TextFormField(
                          cursorColor: royal,
                          style: TextStyle(color: royal),
                          controller: hsnCtrl,
                          onChanged: (_) => setLocalState(() {}),
                          // ✅ update button state
                          textCapitalization: TextCapitalization.words,
                          decoration: _inputDecoration("Enter HSN Code"),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Quantity",
                        field: TextFormField(
                          controller: quantityCtrl,
                          keyboardType: TextInputType.number,
                          cursorColor: royal,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly, // ✅ allows only digits
                          ],
                          style: const TextStyle(color: royal),
                          decoration: _inputDecoration("Strips Count"),
                          onChanged: (_) {
                            calculateStock();
                            setLocalState(() {});
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Free Quantity",
                        field: TextFormField(
                          controller: freeQtyCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly, // ✅ allows only digits
                          ],
                          cursorColor: royal,
                          style: const TextStyle(color: royal),
                          decoration: _inputDecoration("Free Strips Count "),
                          onChanged: (_) => calculateStock(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Unit",
                        field: TextFormField(
                          controller: unitCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly, // ✅ allows only digits
                          ],
                          cursorColor: royal,
                          style: const TextStyle(color: royal),
                          decoration: _inputDecoration("Unit(per quantity)"),
                          onChanged: (_) {
                            calculateStock();
                            setLocalState(() {});
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Rate / Quantity (₹)",
                        field: TextFormField(
                          controller: ratePerQtyCtrl,
                          keyboardType: TextInputType.number,
                          cursorColor: royal,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')), // allows 2 decimals
                          ],
                          style: const TextStyle(color: royal),
                          decoration: _inputDecoration("Rate per quantity"),
                          onChanged: (_) => calculatePurchaseValues(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "GST % / Quantity",
                        field: TextFormField(
                          controller: gstCtrl,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')), // allows 2 decimals
                          ],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          cursorColor: royal,
                          style: const TextStyle(color: royal),
                          decoration: _inputDecoration("GST percentage (0–100)"),
                          onChanged: (value) {
                            final gst = double.tryParse(value);

                            if (gst != null && gst > 100) {
                              gstCtrl.text = '100';                 // ⛔ STOP at 100
                              gstCtrl.selection = TextSelection.collapsed(offset: 3);
                            }

                            calculatePurchaseValues();
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(label: "MRP / Quantity (₹)",
                        field: TextFormField(
                          controller: mrpCtrl,
                          keyboardType: TextInputType.number,
                          cursorColor: royal,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')), // allows 2 decimals
                          ],
                          style: const TextStyle(color: royal),
                          decoration: _inputDecoration(
                              "Maximum Retail Price"),
                          onChanged: (_) =>
                              calculatePurchaseValues(), // 🔥 REQUIRED
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Profit %",
                        field: TextFormField(
                          controller: profitCtrl,
                          keyboardType: TextInputType.number,
                          cursorColor: royal,
                          style: const TextStyle(color: royal),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')), // allows 2 decimals
                          ],
                          decoration: _inputDecoration("Profit percentage"),
                          onChanged: (_) =>
                              calculatePurchaseValues(), // 🔥 REQUIRED
                        ),
                      ),


                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Purchase Date",
                        field: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: royal,
                            backgroundColor: royal.withValues(alpha: 0.1),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            side: const BorderSide(
                                color: royal, width: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: purchaseDate,
                              // ✅ today by default
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: royal,
                                      onPrimary: Colors.white,
                                      onSurface: royal,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );

                            if (picked != null) {
                              setLocalState(() => purchaseDate = picked);
                            }
                          },
                          child: Text(
                            purchaseDate.toLocal().toString().split(' ')[0],
                            style: const TextStyle(color: royal),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Supplier Phone",
                        field: StatefulBuilder(
                          builder: (context, setPhoneState) {
                            return TextFormField(
                              controller: phoneCtrl,
                              cursorColor: royal,
                              style: TextStyle(color: royal),
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              decoration: _inputDecoration("Enter Supplier Phone number").copyWith(
                                suffixIcon: phoneCtrl.text.length == 10
                                    ? supplierFound
                                    ? const Icon(Icons.check_circle, color: Colors.green, size: 24)  // ✅ RIGHT
                                    : const Icon(Icons.error, color: Colors.red, size: 24)          // ❌ WRONG
                                    : null,
                              ),
                              onChanged: (value) {
                                setPhoneState(() {
                                  supplierFound = false;
                                  selectedSupplierId = null;
                                  sellerCtrl.clear();
                                });
                                setLocalState(() {});

                                if (value.length != 10) return;

                                phoneDebounce?.cancel();
                                phoneDebounce = Timer(const Duration(milliseconds: 500), () async {
                                  try {
                                    final url = Uri.parse("$baseUrl/suppliers/search/by-phone/$shopId?phone=$value");
                                    final response = await http.get(url);

                                    setPhoneState(() {
                                      if (response.statusCode == 200) {
                                        final data = jsonDecode(response.body) as List;
                                        if (data.isNotEmpty) {
                                          supplierFound = true;
                                          selectedSupplierId = data[0]['id'];
                                          sellerCtrl.text = data[0]['name'] ?? '';
                                        } else {
                                          supplierFound = false;  // ❌ Shows RED icon
                                        }
                                      } else {
                                        supplierFound = false;  // ❌ Shows RED icon
                                      }
                                    });
                                    setLocalState(() {});
                                  } catch (e) {
                                    setPhoneState(() => supplierFound = false);  // ❌ Shows RED icon
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [

                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
                            child: Text(
                              supplierFound
                                  ? "Supplier name: ${sellerCtrl.text}"
                                  : "No supplier found",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: supplierFound ? royal : Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
                            child: Text(
                              selectedSupplierId != null
                                  ? "Supplier ID: $selectedSupplierId"
                                  : "Supplier ID: Not Found",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: supplierFound ? royal : Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
                            child: Text(
                              "Total Quantity: $totalQuantity",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: royal),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
                            child: Text(
                              "Total Stock: $totalStock",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: royal),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
                            child: Text(
                              "GST Amount / Qty: ₹${gstPerQuantity.toStringAsFixed(2)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: royal),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
                            child: Text(
                              "Purchase / Quantity: ₹${purchasePerQuantity.toStringAsFixed(2)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: royal),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
                            child: Text(
                              "Purchase / Unit: ₹${purchasePerUnit.toStringAsFixed(2)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: royal),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
                            child: Text(
                              "Selling / Quantity: ₹${sellingPerQuantity.toStringAsFixed(2)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: royal),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
                            child: Text(
                              "Selling / Unit: ₹${sellingPerUnit.toStringAsFixed(2)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: royal),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
                            child: Text(
                              "Base Amount: ₹${baseAmount.toStringAsFixed(2)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: royal),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
                            child: Text(
                              "Total GST: ₹${totalGstAmount.toStringAsFixed(2)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: royal),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
                            child: Text(
                              "Purchase Price: ₹${purchasePrice.toStringAsFixed(2)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: royal),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: SizedBox(
                        width: 150,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFormValid() ? royal : Colors
                                .grey,
                            // enabled/disabled color
                            foregroundColor: isFormValid()
                                ? Colors.white
                                : royal,
                            // text color
                            elevation: 0,
                            side: BorderSide(
                              color: isFormValid() ? royal : Colors.grey
                                  .shade700,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                          onPressed: isFormValid()
                              ? () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => confirmMedicineDialog(),
                            );

                            if (confirmed != true) return;
                            final finalCategory = isOtherCategory
                                ? otherCategoryCtrl.text.trim()
                                : selectedCategory;

                            await http.post(
                              Uri.parse("$baseUrl/inventory/medicine"),
                              headers: {"Content-Type": "application/json"},
                              body: jsonEncode({
                                "shop_id": shopId,
                                "name": nameCtrl.text,
                                "category": finalCategory,
                                "ndc_code": ndcCtrl.text,
                                "batch_no": batchCtrl.text,
                                "mfg_date": mfgDate?.toIso8601String(),
                                "exp_date": expDate?.toIso8601String(),
                                "rack_no": rackCtrl.text,
                                "quantity": quantityCtrl.text,
                                "free_quantity": freeQtyCtrl.text,
                                "total_quantity": totalQuantity,
                                "unit": unitCtrl.text,
                                "total_stock": totalStock,
                                "mrp":mrpCtrl.text,
                                "supplier_id":selectedSupplierId,
                                "reorder": int.tryParse(reorderCtrl.text),
                                "hsncode": hsnCtrl.text,
                                "purchase_details": {
                                  "purchase_date": purchaseDate
                                      .toIso8601String(),
                                  "rate_per_quantity": double.tryParse(
                                      ratePerQtyCtrl.text) ?? 0,
                                  "gst_percent": double.tryParse(
                                      gstCtrl.text) ?? 0,
                                  "gst_per_quantity": gstPerQuantity,
                                  "base_amount": baseAmount,
                                  "total_gst_amount": totalGstAmount,
                                  "purchase_price": purchasePrice
                                },
                                "purchase_price_per_unit": purchasePerUnit,
                                "purchase_price_per_quantity": purchasePerQuantity,
                                "selling_price_per_unit": sellingPerUnit,
                                "selling_price_per_quantity": sellingPerQuantity,
                                "profit_percent": double.tryParse(
                                    profitCtrl.text) ?? 0
                              }),
                            );

                            fetchMedicines();
                            // ✅ Clear the form
                            resetForm();      // ✅ CLEAR EVERYTHING

                            setState(() => showAddMedicine = false);
                          }
                              : null,
                          child: const Text(
                            "Submit Medicine",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },),
        ],),),);
      },
    );
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
                    // Toggle medicine form
                    showAddMedicine = !showAddMedicine;

                    // Close batch form
                    showAddBatch = false;

                    // Clear forms when opening/closing
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
                    // Toggle batch form
                    showAddBatch = !showAddBatch;

                    // Close medicine form
                    showAddMedicine = false;

                  });
                },
                child: Text(
                  showAddBatch ? "Close Batch Form" : "Add Batch",
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget labeledField({
    required String label,
    required Widget field,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110, // 👈 FIXED LABEL WIDTH (adjust if needed)
            child: Text(
              label,
              style: const TextStyle(
                color: royal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: field),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: royal.withValues(alpha: 0.8)),
      filled: true,
      fillColor: royal.withValues(alpha: 0.1),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: royal, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: royal, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget addBatchForm() {
    final rackCtrl = TextEditingController();
    final quantityCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final profitCtrl = TextEditingController();
    final sellerCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final hsnCtrl = TextEditingController();
    final mrpCtrl = TextEditingController();
    DateTime? mfgDate;
    DateTime? expDate;
    int? selectedSupplierId;     // ✅ real supplier id
    bool supplierFound = false; // ✅ for UI icon
    final freeQtyCtrl = TextEditingController();
    double totalQuantity = 0;
    double totalStock = 0; // ✅ FIX
    DateTime purchaseDate = DateTime.now(); // ✅ default today
    final ratePerQtyCtrl = TextEditingController();
    final gstCtrl = TextEditingController();
    double sellingPerUnit = 0;
    double sellingPerQuantity = 0;
    double purchasePerUnit = 0;
    double purchasePerQuantity = 0;
    double gstPerQuantity = 0;
    double baseAmount = 0;
    double totalGstAmount = 0;
    double purchasePrice = 0;
    Timer? phoneDebounce;
    int? selectedMedicineId;
    Map<String, dynamic>? selectedMedicine;
    final batchCtrl = TextEditingController();
    final medicineCtrl = TextEditingController();


    return StatefulBuilder(
      builder: (context, setLocalState) {

        void resetForm() {
          medicineCtrl.clear();   // ✅ Clears autocomplete text
          selectedMedicine = null;
          selectedMedicineId = null;
          batchCtrl.clear();
          rackCtrl.clear();
          quantityCtrl.clear();
          freeQtyCtrl.clear();
          unitCtrl.clear();
          ratePerQtyCtrl.clear();
          gstCtrl.clear();
          mrpCtrl.clear();
          profitCtrl.clear();
          sellerCtrl.clear();
          phoneCtrl.clear();
          hsnCtrl.clear();

          mfgDate = null;
          expDate = null;
          purchaseDate = DateTime.now();

          selectedSupplierId = null;
          supplierFound = false;

          totalQuantity = 0;
          totalStock = 0;
          gstPerQuantity = 0;
          baseAmount = 0;
          totalGstAmount = 0;
          purchasePrice = 0;
          purchasePerUnit = 0;
          purchasePerQuantity = 0;
          sellingPerUnit = 0;
          sellingPerQuantity = 0;
          phoneDebounce?.cancel();
          setLocalState(() {});
        }

        Widget medicineAutocomplete(void Function(VoidCallback fn) setLocalState) {
          return RawAutocomplete<Map<String, dynamic>>(
            textEditingController: medicineCtrl,
            focusNode: FocusNode(),
            optionsBuilder: (TextEditingValue value) {
              if (value.text.isEmpty) return [];
              return medicines.where(
                    (m) => m['name']
                    .toLowerCase()
                    .contains(value.text.toLowerCase()),
              );
            },
            displayStringForOption: (m) => m['name'],
            onSelected: (m) {
              setLocalState(() {
                selectedMedicine = m;
                selectedMedicineId = m['id'];

                batchCtrl.clear();
                isBatchTaken = false;
                debounce?.cancel();
              });
            },

            fieldViewBuilder: (context, controller, focusNode, _) {
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                cursorColor: royal,
                style: const TextStyle(color: royal),
                decoration: _inputDecoration("Medicine Name"),
              );
            },

            optionsViewBuilder: (context, onSelected, options) {
              return Material(
                elevation: 4,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, i) {
                    final m = options.elementAt(i);
                    return ListTile(
                      title: Text(m['name']),
                      subtitle: Text("Stock: ${m['stock']}"),

                      // ✅ JUST call onSelected
                      onTap: () => onSelected(m),
                    );
                  },
                ),
              );
            },
          );
        }

        void calculateStock() {
          final qty = double.tryParse(quantityCtrl.text) ?? 0;
          final freeQty = double.tryParse(freeQtyCtrl.text) ?? 0;
          final unit = double.tryParse(unitCtrl.text) ?? 0;

          totalQuantity = qty + freeQty;     // ✅ TOTAL QTY
          totalStock = totalQuantity * unit;      // ✅ TOTAL STOCK


          setLocalState(() {});
        }

        void calculatePurchaseValues() {
          final qty = double.tryParse(quantityCtrl.text) ?? 0;
          final rate = double.tryParse(ratePerQtyCtrl.text) ?? 0;
          final gstPercent = double.tryParse(gstCtrl.text) ?? 0;
          final unit = double.tryParse(unitCtrl.text) ?? 0;
          final mrp = double.tryParse(mrpCtrl.text) ?? 0;
          final profitPercent = double.tryParse(profitCtrl.text) ?? 0;


          if (qty <= 0 || unit <= 0) {
            purchasePerUnit = 0;
            purchasePerQuantity = 0;
            sellingPerUnit = 0;
            sellingPerQuantity = 0;
            setLocalState(() {});
            return;
          }
          baseAmount = qty * rate;

          // GST
          gstPerQuantity = rate * gstPercent / 100;
          totalGstAmount = gstPerQuantity * qty;

          // PURCHASE PRICE
          purchasePrice = baseAmount + totalGstAmount;
          purchasePerQuantity = purchasePrice / qty;   // ✔ strip price
          purchasePerUnit = purchasePerQuantity / unit; // ✔ tablet price
          if (purchasePerQuantity <= 0 || qty <= 0) return;

          // Profit-based selling
          final calculatedSelling =
              purchasePerQuantity + (purchasePerQuantity * profitPercent / 100);

          // ✅ MRP CAP
          sellingPerQuantity = calculatedSelling > mrp ? mrp : calculatedSelling;

          // Quantity price
          sellingPerUnit = sellingPerQuantity / unit;
          setLocalState(() {});
          // TOTAL STOCK

        }

        Future<bool> validateBatchBackend(String batchNo) async {
          if (selectedMedicineId == null || batchNo.isEmpty) {
            return true; // allow typing
          }

          try {
            final url = Uri.parse(
              "$baseUrl/inventory/medicine/$shopId/$selectedMedicineId/validate-batch?batch_no=$batchNo",
            );

            final response = await http.get(url);

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              return data['is_valid'] == true;
            }
          } catch (_) {}

          return true; // fallback allow
        }

        bool isFormValid() {
          return selectedMedicineId != null &&
              batchCtrl.text.isNotEmpty &&
              !isBatchTaken &&   // ✅ disable if batch exists
              quantityCtrl.text.trim().isNotEmpty &&
              (double.tryParse(quantityCtrl.text) ?? 0) > 0 &&

              unitCtrl.text.trim().isNotEmpty &&
              (double.tryParse(unitCtrl.text) ?? 0) > 0 &&

              ratePerQtyCtrl.text.trim().isNotEmpty &&
              (double.tryParse(ratePerQtyCtrl.text) ?? 0) > 0 &&

              profitCtrl.text.trim().isNotEmpty &&
              (double.tryParse(profitCtrl.text) ?? 0) >= 0 &&

              mrpCtrl.text.trim().isNotEmpty &&
              (double.tryParse(mrpCtrl.text) ?? 0) > 0 &&

              supplierFound &&
              selectedSupplierId != null &&

              phoneCtrl.text.length == 10 &&

              mfgDate != null &&
              expDate != null &&
              expDate!.isAfter(mfgDate!) ;

        }

        Widget confirmBatchDialog() {
          Widget infoTile(String label, String value,
              {Color valueColor = royal}) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      "$label:",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: royal,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value.isEmpty ? "-" : value,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: valueColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return AlertDialog(
            insetPadding: const EdgeInsets.all(16),
            contentPadding: const EdgeInsets.all(12),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: royal, width: 1.2),
            ),
            title: const Center(
              child: Text(
                "Confirm Batch Details",
                style: TextStyle(fontWeight: FontWeight.bold, color: royal),
              ),
            ),
            content: SingleChildScrollView(
                child: Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: royal, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        infoTile("Medicine", selectedMedicine!['name']),
                        infoTile("Batch No", batchCtrl.text),
                        if (rackCtrl.text.trim().isNotEmpty)
                          infoTile("Rack No", rackCtrl.text),
                        if (hsnCtrl.text.trim().isNotEmpty)
                          infoTile("HSN Code", hsnCtrl.text),

                        const Divider(color: royal),

                        /// 🔹 DATES
                        infoTile("MFG Date",
                            mfgDate?.toLocal().toString().split(' ')[0] ?? "-"),
                        infoTile("EXP Date",
                            expDate?.toLocal().toString().split(' ')[0] ?? "-"),
                        infoTile("Purchase Date",
                            purchaseDate.toLocal().toString().split(' ')[0]),

                        const Divider(color: royal),

                        /// 🔹 STOCK
                        infoTile("Quantity", quantityCtrl.text),
                        if (freeQtyCtrl.text.trim().isNotEmpty &&
                            freeQtyCtrl.text.trim() != "0")
                          infoTile("Free Qty", freeQtyCtrl.text),
                        infoTile("Total Quantity", totalQuantity.toString()),
                        infoTile("Unit / Qty", unitCtrl.text),
                        infoTile("Total Stock", totalStock.toString()),

                        const Divider(color: royal),

                        /// 🔹 SUPPLIER
                        infoTile("Supplier Phone", phoneCtrl.text),
                        infoTile("Supplier Name", sellerCtrl.text),
                        infoTile("Supplier ID",
                            selectedSupplierId?.toString() ?? "-"),

                        const Divider(color: royal),

                        /// 🔹 PRICING
                        infoTile("Rate / Qty", "₹${ratePerQtyCtrl.text}"),
                        if (gstCtrl.text.trim().isNotEmpty)
                          infoTile("GST % / Qty", gstCtrl.text),
                        if (gstPerQuantity > 0)
                          infoTile(
                            "GST Amount / Qty",
                            "₹${gstPerQuantity.toStringAsFixed(2)}",
                          ),

                        infoTile("Base Amount",
                            "₹${baseAmount.toStringAsFixed(2)}"),
                        if (totalGstAmount > 0)
                          infoTile(
                            "Total GST",
                            "₹${totalGstAmount.toStringAsFixed(2)}",
                            valueColor: Colors.orange,
                          ),

                        const Divider(color: royal),

                        /// 🔹 PURCHASE & SELLING
                        infoTile("Purchase / Qty",
                            "₹${purchasePerQuantity.toStringAsFixed(2)}",
                            valueColor: Colors.red),
                        infoTile("Purchase / Unit",
                            "₹${purchasePerUnit.toStringAsFixed(2)}",
                            valueColor: Colors.red),
                        infoTile("Selling / Qty",
                            "₹${sellingPerQuantity.toStringAsFixed(2)}"),
                        infoTile("Selling / Unit",
                            "₹${sellingPerUnit.toStringAsFixed(2)}"),
                        infoTile("MRP / Quantity", mrpCtrl.text),
                        infoTile("Profit %",
                            profitCtrl.text),

                        const Divider(color:royal,thickness: 1.2),

                        /// 🔥 FINAL TOTAL
                        infoTile(
                          "Total Purchase Price",
                          "₹${purchasePrice.toStringAsFixed(2)}",
                          valueColor: Colors.green,

                        ),
        ],
        ),
        ),
        ),
        ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: royal), // ✅ outline color
                  foregroundColor: royal,               // ✅ text & icon color
                ),
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel",style: TextStyle(color: royal),),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: royal,foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Confirm"),
              ),
            ],
          );
        }

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: royal),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const Center(
                  child: Text("Add Batch",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: royal)),
                ),

                const SizedBox(height: 14),

                // 🔍 MEDICINE AUTOCOMPLETE

        LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = MediaQuery
              .of(context)
              .size
              .width >= 1000;

          double fieldWidth(BoxConstraints c) {
            if (!isDesktop) return c.maxWidth;
            return (c.maxWidth - 32) / 3; // 3 columns with spacing
          }
          int columnCount;
          if (constraints.maxWidth >= 1000) {
            columnCount = 4; // large desktop
          } else if (constraints.maxWidth >= 800) {
            columnCount = 3; // tablet
          } else if (constraints.maxWidth >= 600) {
            columnCount = 2; // tablet
          } else {
            columnCount = 1; // mobile
          }

          double columnWidth =
              (constraints.maxWidth - ((columnCount - 1) * 16)) / columnCount;

          return Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              SizedBox(
                  width: fieldWidth(constraints),
                  child:labeledField(
                    label: "Medicine",
                    field: medicineAutocomplete(setLocalState),
                  ),
              ),
              SizedBox(
              width: fieldWidth(constraints),
              child:
              labeledField(
                label: "Batch No",
                field: TextFormField(
                  controller: batchCtrl,
                  cursorColor: royal,
                  keyboardType: TextInputType.visiblePassword,
                  style: const TextStyle(color: royal),
                  decoration: InputDecoration(
                    hintText: "Enter Batch no",
                    filled: true,
                    hintStyle: TextStyle(color: royal),
                    fillColor: royal.withAlpha(25),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: royal, width: 0.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: royal, width: 1.5),
                    ),
                    suffixIcon: batchCtrl.text.isEmpty
                        ? null
                        : isBatchTaken
                        ? const Icon(Icons.error, color: Colors.red)
                        : const Icon(Icons.check_circle, color: Colors.green),
                  ),
                  onChanged: (value) {
                    debounce?.cancel();

                    debounce =
                        Timer(const Duration(milliseconds: 500), () async {
                          final batch = value.trim();

                          if (batch.isEmpty) {
                            setLocalState(() => isBatchTaken = false);
                            return;
                          }

                          final isValid = await validateBatchBackend(batch);

                          setLocalState(() {
                            isBatchTaken =
                            !isValid; // ❌ taken when backend returns false
                          });
                        });
                  },
                ),
              ),
              ),
              SizedBox(
                width: fieldWidth(constraints),
                child: labeledField(
                  label: "Rack No",
                  field: TextFormField(
                    controller: rackCtrl,
                    cursorColor: royal,
                    keyboardType: TextInputType.visiblePassword,
                    style: const TextStyle(color: royal),
                    decoration: _inputDecoration("Optional"),
                  ),
                ),
              ),
              SizedBox(
                width: fieldWidth(constraints),
                child: labeledField(
                  label: "MFG Date",
                  field: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: royal,
                      backgroundColor: royal.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14),
                      side: const BorderSide(
                          color: royal, width: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: royal,
                                onPrimary: Colors.white,
                                onSurface: royal,
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                    foregroundColor: royal),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) setLocalState(() => mfgDate = picked);
                    },
                    child: Text(
                      mfgDate == null ? "Select date" : mfgDate!
                          .toLocal().toString().split(' ')[0],
                      style: TextStyle(color: royal),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: fieldWidth(constraints),
                child: labeledField(
                  label: "EXP Date",
                  field: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: royal,
                      backgroundColor: royal.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14),
                      side: const BorderSide(
                          color: royal, width: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: royal,
                                onPrimary: Colors.white,
                                onSurface: royal,
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                    foregroundColor: royal),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) setLocalState(() => expDate = picked);
                    },
                    child: Text(
                      expDate == null ? "Select date" : expDate!
                          .toLocal().toString().split(' ')[0],
                      style: TextStyle(color: royal),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: fieldWidth(constraints),
                child: labeledField(
                  label: "HSN Code",
                  field: TextFormField(
                    cursorColor: royal,
                    style: TextStyle(color: royal),
                    controller: hsnCtrl,
                    onChanged: (_) => setLocalState(() {}),
                    // ✅ update button state
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration("Enter HSN Code"),
                  ),
                ),
              ),
              SizedBox(
                width: fieldWidth(constraints),
                child: labeledField(
                  label: "Quantity",
                  field: TextFormField(
                    controller: quantityCtrl,
                    keyboardType: TextInputType.number,
                    cursorColor: royal,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      // ✅ allows only digits
                    ],
                    style: const TextStyle(color: royal),
                    decoration: _inputDecoration("Strips Count"),
                    onChanged: (_) {
                      calculateStock();
                      setLocalState(() {});
                    },
                  ),
                ),
              ),
              SizedBox(
                width: fieldWidth(constraints),
                child: labeledField(
                  label: "Free Quantity",
                  field: TextFormField(
                    controller: freeQtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      // ✅ allows only digits
                    ],
                    cursorColor: royal,
                    style: const TextStyle(color: royal),
                    decoration: _inputDecoration("Free Strips Count "),
                    onChanged: (_) => calculateStock(),
                  ),
                ),
              ),
              SizedBox(
                width: fieldWidth(constraints),
                child: labeledField(
                  label: "Unit",
                  field: TextFormField(
                    controller: unitCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      // ✅ allows only digits
                    ],
                    cursorColor: royal,
                    style: const TextStyle(color: royal),
                    decoration: _inputDecoration("Unit(per quantity)"),
                    onChanged: (_) {
                      calculateStock();
                      setLocalState(() {});
                    },
                  ),
                ),
              ),
              SizedBox(
                width: fieldWidth(constraints),
                child: labeledField(
                  label: "Rate / Quantity (₹)",
                  field: TextFormField(
                    controller: ratePerQtyCtrl,
                    keyboardType: TextInputType.number,
                    cursorColor: royal,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')), // allows 2 decimals
                    ],
                    style: const TextStyle(color: royal),
                    decoration: _inputDecoration("Rate per quantity"),
                    onChanged: (_) => calculatePurchaseValues(),
                  ),
                ),
              ),
              SizedBox(
                width: fieldWidth(constraints),
                child: labeledField(
                  label: "GST % / Quantity",
                  field: TextFormField(
                    controller: gstCtrl,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')), // allows 2 decimals
                    ],
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    cursorColor: royal,
                    style: const TextStyle(color: royal),
                    decoration: _inputDecoration("GST percentage (0–100)"),
                    onChanged: (value) {
                      final gst = double.tryParse(value);

                      if (gst != null && gst > 100) {
                        gstCtrl.text = '100'; // ⛔ STOP at 100
                        gstCtrl.selection = TextSelection.collapsed(offset: 3);
                      }

                      calculatePurchaseValues();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: fieldWidth(constraints),
                child: labeledField(label: "MRP / Quantity (₹)",
                  field: TextFormField(
                    controller: mrpCtrl,
                    keyboardType: TextInputType.number,
                    cursorColor: royal,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')), // allows 2 decimals
                    ],
                    style: const TextStyle(color: royal),
                    decoration: _inputDecoration(
                        "Maximum Retail Price"),
                    onChanged: (_) =>
                        calculatePurchaseValues(), // 🔥 REQUIRED
                  ),
                ),
              ),
              SizedBox(
                width: fieldWidth(constraints),
                child: labeledField(
                  label: "Profit %",
                  field: TextFormField(
                    controller: profitCtrl,
                    keyboardType: TextInputType.number,
                    cursorColor: royal,
                    style: const TextStyle(color: royal),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')), // allows 2 decimals
                    ],
                    decoration: _inputDecoration("Profit percentage"),
                    onChanged: (_) =>
                        calculatePurchaseValues(), // 🔥 REQUIRED
                  ),
                ),


              ),
              SizedBox(
                width: fieldWidth(constraints),
                child: labeledField(
                  label: "Purchase Date",
                  field: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: royal,
                      backgroundColor: royal.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14),
                      side: const BorderSide(
                          color: royal, width: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: purchaseDate,
                        // ✅ today by default
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: royal,
                                onPrimary: Colors.white,
                                onSurface: royal,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );

                      if (picked != null) {
                        setLocalState(() => purchaseDate = picked);
                      }
                    },
                    child: Text(
                      purchaseDate.toLocal().toString().split(' ')[0],
                      style: const TextStyle(color: royal),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: fieldWidth(constraints),
                child: labeledField(
                  label: "Supplier Phone",
                  field: StatefulBuilder(
                    builder: (context, setPhoneState) {
                      return TextFormField(
                        controller: phoneCtrl,
                        cursorColor: royal,
                        style: TextStyle(color: royal),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: _inputDecoration(
                            "Enter Supplier Phone number").copyWith(
                          suffixIcon: phoneCtrl.text.length == 10
                              ? supplierFound
                              ? const Icon(
                              Icons.check_circle, color: Colors.green,
                              size: 24) // ✅ RIGHT
                              : const Icon(Icons.error, color: Colors.red,
                              size: 24) // ❌ WRONG
                              : null,
                        ),
                        onChanged: (value) {
                          setPhoneState(() {
                            supplierFound = false;
                            selectedSupplierId = null;
                            sellerCtrl.clear();
                          });
                          setLocalState(() {});

                          if (value.length != 10) return;

                          phoneDebounce?.cancel();
                          phoneDebounce = Timer(
                              const Duration(milliseconds: 500), () async {
                            try {
                              final url = Uri.parse(
                                  "$baseUrl/suppliers/search/by-phone/$shopId?phone=$value");
                              final response = await http.get(url);

                              setPhoneState(() {
                                if (response.statusCode == 200) {
                                  final data = jsonDecode(
                                      response.body) as List;
                                  if (data.isNotEmpty) {
                                    supplierFound = true;
                                    selectedSupplierId = data[0]['id'];
                                    sellerCtrl.text = data[0]['name'] ?? '';
                                  } else {
                                    supplierFound = false; // ❌ Shows RED icon
                                  }
                                } else {
                                  supplierFound = false; // ❌ Shows RED icon
                                }
                              });
                              setLocalState(() {});
                            } catch (e) {
                              setPhoneState(() =>
                              supplierFound = false); // ❌ Shows RED icon
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [

                  SizedBox(
                    width: columnWidth,
                    child: Align(
                      alignment: isDesktop ? Alignment.centerLeft : Alignment
                          .center,
                      child: Text(
                        supplierFound
                            ? "Supplier name: ${sellerCtrl.text}"
                            : "No supplier found",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: supplierFound ? royal : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: columnWidth,
                    child: Align(
                      alignment: isDesktop ? Alignment.centerLeft : Alignment
                          .center,
                      child: Text(
                        selectedSupplierId != null
                            ? "Supplier ID: $selectedSupplierId"
                            : "Supplier ID: Not Found",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: supplierFound ? royal : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: columnWidth,
                    child: Align(
                      alignment: isDesktop ? Alignment.centerLeft : Alignment
                          .center,
                      child: Text(
                        "Total Quantity: $totalQuantity",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: royal),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: columnWidth,
                    child: Align(
                      alignment: isDesktop ? Alignment.centerLeft : Alignment
                          .center,
                      child: Text(
                        "Total Stock: $totalStock",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: royal),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: columnWidth,
                    child: Align(
                      alignment: isDesktop ? Alignment.centerLeft : Alignment
                          .center,
                      child: Text(
                        "GST Amount / Qty: ₹${gstPerQuantity.toStringAsFixed(
                            2)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: royal),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: columnWidth,
                    child: Align(
                      alignment: isDesktop ? Alignment.centerLeft : Alignment
                          .center,
                      child: Text(
                        "Purchase / Quantity: ₹${purchasePerQuantity
                            .toStringAsFixed(2)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: royal),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: columnWidth,
                    child: Align(
                      alignment: isDesktop ? Alignment.centerLeft : Alignment
                          .center,
                      child: Text(
                        "Purchase / Unit: ₹${purchasePerUnit.toStringAsFixed(
                            2)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: royal),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: columnWidth,
                    child: Align(
                      alignment: isDesktop ? Alignment.centerLeft : Alignment
                          .center,
                      child: Text(
                        "Selling / Quantity: ₹${sellingPerQuantity
                            .toStringAsFixed(2)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: royal),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: columnWidth,
                    child: Align(
                      alignment: isDesktop ? Alignment.centerLeft : Alignment
                          .center,
                      child: Text(
                        "Selling / Unit: ₹${sellingPerUnit.toStringAsFixed(2)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: royal),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: columnWidth,
                    child: Align(
                      alignment: isDesktop ? Alignment.centerLeft : Alignment
                          .center,
                      child: Text(
                        "Base Amount: ₹${baseAmount.toStringAsFixed(2)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: royal),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: columnWidth,
                    child: Align(
                      alignment: isDesktop ? Alignment.centerLeft : Alignment
                          .center,
                      child: Text(
                        "Total GST: ₹${totalGstAmount.toStringAsFixed(2)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: royal),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: columnWidth,
                    child: Align(
                      alignment: isDesktop ? Alignment.centerLeft : Alignment
                          .center,
                      child: Text(
                        "Purchase Price: ₹${purchasePrice.toStringAsFixed(2)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: royal),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Center(
                child: SizedBox(
                  width: 150,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFormValid() ? royal : Colors.grey,
                      // enabled/disabled color
                      foregroundColor: isFormValid() ? Colors.white : royal,
                      // text color
                      elevation: 0,
                      side: BorderSide(
                        color: isFormValid() ? royal : Colors.grey.shade700,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: isFormValid()
                        ? () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => confirmBatchDialog(),
                      );
                      double d2(double value) =>
                          double.parse(value.toStringAsFixed(2));
                      if (ok != true) return;
                      await http.post(
                        Uri.parse(
                            "$baseUrl/inventory/medicine/$selectedMedicineId/batch"),
                        headers: {"Content-Type": "application/json"},
                        body: jsonEncode({
                          "shop_id": shopId,
                          "batch_no": batchCtrl.text,
                          "mfg_date": mfgDate?.toIso8601String(),
                          "exp_date": expDate?.toIso8601String(),
                          "rack_no": rackCtrl.text,
                          "quantity": int.parse(quantityCtrl.text),
                          "free_quantity": int.tryParse(freeQtyCtrl.text) ?? 0,
                          "total_quantity": d2(totalQuantity),
                          "unit": int.parse(unitCtrl.text),
                          "total_stock": d2(totalStock),
                          "mrp": d2(double.parse(mrpCtrl.text)),
                          "supplier_id": selectedSupplierId,
                          "hsncode": hsnCtrl.text,

                          "purchase_details": {
                            "purchase_date": purchaseDate.toIso8601String(),
                            "rate_per_quantity": d2(double.parse(ratePerQtyCtrl.text)),
                            "gst_percent": d2(double.tryParse(gstCtrl.text) ?? 0),
                            "gst_per_quantity": d2(gstPerQuantity),
                            "base_amount": d2(baseAmount),
                            "total_gst_amount": d2(totalGstAmount),
                            "purchase_price": d2(purchasePrice),
                          },

                          "purchase_price_per_unit": d2(purchasePerUnit),
                          "purchase_price_per_quantity": d2(purchasePerQuantity),
                          "selling_price_per_unit": d2(sellingPerUnit),
                          "selling_price_per_quantity": d2(sellingPerQuantity),
                          "profit_percent": d2(double.tryParse(profitCtrl.text) ?? 0),
                          "reason": "New Batch",
                        }),
                      );

                      fetchMedicines();
                      resetForm();


                      setState(() => showAddBatch = false);
                    }
                        : null,
                    child: const Text("Submit Batch"),
                  ),
                ),
              ),
            ],
          );
        },),
          ],),
        ),);
      },
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
            if (showAddMedicine) addMedicineForm(),
            if (showAddBatch) addBatchForm(),
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
    ],),),);
  }
}
