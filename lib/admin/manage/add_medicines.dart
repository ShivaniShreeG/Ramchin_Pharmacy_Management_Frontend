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
  int? selectedMedicineId;
  Map<String, dynamic>? selectedMedicine;

  bool showAddMedicine = false;
  bool showAddBatch = false;
  final medicineCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final reorderCtrl = TextEditingController(text: '10');
  final unitCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final profitCtrl = TextEditingController();
  final expiryCtrl = TextEditingController();
  final mfgCtrl = TextEditingController();
  final TextEditingController searchCtrl = TextEditingController();
  final batchCtrl = TextEditingController();

  List<Map<String, dynamic>> filteredMedicines = [];
  double totalPurchasePrice = 0;
  double stock = 0, purchase = 0, sell = 0;

  final List<String> medicineCategories = [
    "Tablets",
    "Syrups",
    "Drops",
    "Ointments",
    "Creams",
    "Soap",
    "Other",
  ];
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
    query = query.toLowerCase();

    setState(() {
      filteredMedicines = medicines.where((medicine) {
        final nameMatch =
            medicine['name']?.toLowerCase().contains(query) ?? false;

        final batchMatch = (medicine['batches'] as List).any((batch) {
          final expiry = batch['expiry_date'];
          if (expiry == null) return false;

          final formatted = formatDate(expiry).toLowerCase();
          return expiry.toLowerCase().contains(query) ||
              formatted.contains(query);
        });

        return nameMatch || batchMatch;
      }).toList();
    });
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
                                      if (shouldShow(batch['manufacture_date']))
                                        infoRow("Manufacture Date", formatDate(batch['manufacture_date'])),
                                      if (shouldShow(batch['expiry_date']))
                                        infoRow("Expiry Date", formatDate(batch['expiry_date'])),
                                      if (shouldShow(batch['HSN']))
                                        infoRow("HSN Code", batch['HSN'] ?? "-"),
                                      if (shouldShow(batch['quantity']))
                                        infoRow("Quantity", batch['quantity'].toString()),
                                      if (shouldShow(batch['unit']))
                                        infoRow("Unit", batch['unit'].toString()),
                                      if (shouldShow(batch['unit_price']))
                                        infoRow("Unit Price", "₹${batch['unit_price']}"),
                                      if (shouldShow(batch['single_price']))
                                        infoRow("Single Price", batch['single_price']?.toString() ?? "-"),
                                      if (shouldShow(batch['selling_price']))
                                        infoRow("Selling Price", "₹${batch['selling_price']}"),
                                      if (shouldShow(batch['profit']))
                                        infoRow("Profit", batch['profit']?.toString() ?? "-"),
                                      if (shouldShow(batch['gst']))
                                        infoRow("GST", batch['gst']?.toString() ?? "-"),
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
                                      if (shouldShow(batch['name'])) infoRow("Name", batch['name']),
                                      if (shouldShow(batch['phone'])) infoRow("Phone", batch['phone']),
                                      if (shouldShow(batch['purchase_price']))
                                        infoRow("Price", "₹${batch['purchase_price']}"),
                                      if (shouldShow(batch['purchase_stock']))
                                        infoRow("Stock", "${batch['purchase_stock']}"),
                                      if (shouldShow(batch['purchased_date']))
                                        infoRow("Date", formatDate(batch['purchased_date'])),
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

      // ✅ THIS is the ONLY place selection logic should be
      onSelected: (m) {
        setLocalState(() {
          selectedMedicine = m;
          selectedMedicineId = m['id'];

          // 🔥 RESET batch-related state
          batchCtrl.clear();
          isBatchTaken = false;
          debounce?.cancel();

          // OPTIONAL – reset calculations
          stock = 0;
          totalPurchasePrice = 0;
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
                    medicineCtrl.clear();
                    selectedMedicineId=null;
                    selectedMedicine=null;
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

  Widget addMedicineForm() {
    final nameCtrl = TextEditingController();
    bool isNameTaken = false; // to track if name exists
    final ndcCtrl = TextEditingController();
    final batchCtrl = TextEditingController(text: "01");
    final rackCtrl = TextEditingController();
    final quantityCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final purchasePriceCtrl = TextEditingController();
    final sellingPriceCtrl = TextEditingController();
    final profitCtrl = TextEditingController();
    final sellerCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final hsnCtrl = TextEditingController();

    String selectedCategory = medicineCategories.first;
    DateTime? mfgDate;
    DateTime? expDate;

    double stock = 0;
    double totalPurchasePrice = 0;
    final TextEditingController otherCategoryCtrl = TextEditingController();
    bool isOtherCategory = false;

    Widget confirmMedicineDialog() {
      final finalCategory = isOtherCategory ? otherCategoryCtrl.text.trim() : selectedCategory;

      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: royal, width: 1.3),
        ),
        title: const Center(
          child: Text(
            "Confirm Medicine Details",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: royal,
            ),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogRow("Name", nameCtrl.text),
              _dialogRow("Category", finalCategory),
              _dialogRow("NDC Code", ndcCtrl.text.isEmpty ? "-" : ndcCtrl.text),
              _dialogRow("Batch No", batchCtrl.text),
              _dialogRow("MFG Date", mfgDate != null ? mfgDate!.toLocal().toString().split(' ')[0] : "-"),
              _dialogRow("EXP Date", expDate != null ? expDate!.toLocal().toString().split(' ')[0] : "-"),
              _dialogRow("Rack No", rackCtrl.text.isEmpty ? "-" : rackCtrl.text),
              _dialogRow("Quantity", quantityCtrl.text),
              _dialogRow("Unit", unitCtrl.text),
              _dialogRow("Stock", stock.toString()),
              _dialogRow("Purchase Price", purchasePriceCtrl.text),
              _dialogRow("Profit %", profitCtrl.text),
              _dialogRow("Selling Price", sellingPriceCtrl.text),
              _dialogRow("Total Cost", "₹${totalPurchasePrice.toStringAsFixed(2)}"),
              _dialogRow("Seller Name", sellerCtrl.text),
              _dialogRow("Phone", phoneCtrl.text),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: royal,
              side: const BorderSide(color: royal),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: royal,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("OK"),
          ),
        ],
      );
    }

    bool isFormValid() {
      return nameCtrl.text.trim().isNotEmpty &&
          !isNameTaken && // ✅ disable if name exists
          selectedCategory.isNotEmpty &&
          (!isOtherCategory || otherCategoryCtrl.text.trim().isNotEmpty) &&
          batchCtrl.text.trim().isNotEmpty &&
          quantityCtrl.text.trim().isNotEmpty &&
          unitCtrl.text.trim().isNotEmpty &&
          purchasePriceCtrl.text.trim().isNotEmpty &&
          profitCtrl.text.trim().isNotEmpty &&
          sellingPriceCtrl.text.trim().isNotEmpty &&
          sellerCtrl.text.trim().isNotEmpty &&
          phoneCtrl.text.trim().isNotEmpty &&
          mfgDate != null &&
          expDate != null;
    }

    return StatefulBuilder(
      builder: (context, setLocalState) {
        void calculateStock() {
          final qty = double.tryParse(quantityCtrl.text) ?? 0;
          final unit = double.tryParse(unitCtrl.text) ?? 0;
          stock = qty * unit;

          final purchase = double.tryParse(purchasePriceCtrl.text) ?? 0;
          totalPurchasePrice = stock * purchase;

          setLocalState(() {});
        }
        bool isEditingProfit = false;
        bool isEditingSelling = false;

        void calculateSellingFromProfit() {
          if (isEditingSelling) return; // Prevent loop
          final purchase = double.tryParse(purchasePriceCtrl.text) ?? 0;
          final profitPercent = double.tryParse(profitCtrl.text) ?? 0;
          final selling = purchase + (purchase * profitPercent / 100);
          sellingPriceCtrl.text = selling.toStringAsFixed(2);
        }

        void calculateProfitFromSelling() {
          if (isEditingProfit) return; // Prevent loop
          final purchase = double.tryParse(purchasePriceCtrl.text) ?? 0;
          final selling = double.tryParse(sellingPriceCtrl.text) ?? 0;
          if (purchase != 0) {
            final profit = ((selling - purchase) / purchase) * 100;
            profitCtrl.text = profit.toStringAsFixed(2);
          }
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
                  child: Text(
                    "Add Medicine",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: royal,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                labeledField(
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
                            borderSide: const BorderSide(color: royal, width: 0.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: royal, width: 1.5),
                          ),
                          suffixIcon: isNameTaken
                              ? const Icon(Icons.error, color: Colors.red)
                              : const Icon(Icons.check, color: Colors.green),
                        ),
                        onChanged: (value) {
                          if (debounce?.isActive ?? false) debounce!.cancel();
                          debounce = Timer(const Duration(milliseconds: 500), () async {
                            if (value.trim().isEmpty) {
                              setLocalState(() => isNameTaken = false);
                              return;
                            }

                            try {
                              final url = Uri.parse("$baseUrl/inventory/medicine/check-name/$shopId?name=$value");
                              final response = await http.get(url);

                              if (response.statusCode == 200) {
                                final data = jsonDecode(response.body);
                                setLocalState(() => isNameTaken = data['exists'] ?? false);
                              } else {
                                setLocalState(() => isNameTaken = false);
                              }
                            } catch (_) {
                              setLocalState(() => isNameTaken = false);
                            }
                          });
                          setLocalState(() {}); // update UI for button
                        },
                      );
                    },
                  ),
                ),

                labeledField(
                  label: "Category",
                  field: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        iconEnabledColor: royal,
                        style: const TextStyle(color: royal),
                        decoration: _inputDecoration("Select category"),
                        items: medicineCategories
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) {
                          setLocalState(() {
                            selectedCategory = v!;
                            isOtherCategory = v == "Other";
                            if (!isOtherCategory) otherCategoryCtrl.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),

                if (isOtherCategory)
                  labeledField(
                    label: "Custom Category",
                    field: TextFormField(
                      controller: otherCategoryCtrl,
                      textCapitalization: TextCapitalization.words,
                      cursorColor: royal,
                      style: const TextStyle(color: royal),
                      onChanged: (_) => setLocalState(() {}), // ✅ update button state
                      decoration: _inputDecoration("Enter custom category"),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Custom category is required";
                        }
                        return null;
                      },
                    ),
                  ),

                labeledField(
                  label: "NDC",
                  field: TextFormField(
                    controller: ndcCtrl,
                    cursorColor: royal,
                    keyboardType: TextInputType.visiblePassword,
                    style: const TextStyle(color: royal),
                    decoration: _inputDecoration("Enter NDC code (optional)"),
                  ),
                ),
                labeledField(
                  label: "Batch No",
                  field: TextFormField(
                    controller: batchCtrl,
                    cursorColor: royal,
                    onChanged: (_) => setLocalState(() {}), // ✅ update button state
                    keyboardType: TextInputType.visiblePassword,
                    style: const TextStyle(color: royal),
                    decoration: _inputDecoration("Enter Batch no"),
                  ),
                ),

                labeledField(
                  label: "MFG Date",
                  field: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: royal,
                      backgroundColor: royal.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: royal, width: 0.5),
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
                                primary: royal,       // header & selected date
                                onPrimary: Colors.white, // selected date text
                                onSurface: royal,     // unselected dates
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(foregroundColor: royal),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) setLocalState(() => mfgDate = picked);
                    },
                    child: Text(
                      mfgDate == null ? "Select date" : mfgDate!.toLocal().toString().split(' ')[0],
                      style: TextStyle(color: royal),
                    ),
                  ),
                ),

                labeledField(
                  label: "EXP Date",
                  field: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: royal,
                      backgroundColor: royal.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: royal, width: 0.5),
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
                                style: TextButton.styleFrom(foregroundColor: royal),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) setLocalState(() => expDate = picked);
                    },
                    child: Text(
                      expDate == null ? "Select date" : expDate!.toLocal().toString().split(' ')[0],
                      style: TextStyle(color: royal),
                    ),
                  ),
                ),
                labeledField(
                  label: "Reorder-Level",
                  field: TextFormField(
                    cursorColor: royal,
                    style: TextStyle(color: royal),
                    keyboardType: TextInputType.number,
                    controller: reorderCtrl,
                    onChanged: (_) => setLocalState(() {}), // ✅ update button state
                    decoration: _inputDecoration("Re-order value"),
                  ),
                ),
                labeledField(
                  label: "Rack No",
                  field: TextFormField(
                    controller: rackCtrl,
                    cursorColor: royal,
                    keyboardType: TextInputType.visiblePassword,
                    style: const TextStyle(color: royal),
                    decoration: _inputDecoration("Optional"),
                  ),
                ),
                labeledField(
                  label: "HSN Code",
                  field: TextFormField(
                    cursorColor: royal,
                    style: TextStyle(color: royal),
                    controller: hsnCtrl,
                    onChanged: (_) => setLocalState(() {}), // ✅ update button state
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration("Enter HSN Code"),
                  ),
                ),
                labeledField(
                  label: "Quantity",
                  field: TextFormField(
                    controller: quantityCtrl,
                    keyboardType: TextInputType.number,
                    cursorColor: royal,
                    style: const TextStyle(color: royal),
                    decoration: _inputDecoration("Qty"),
                    onChanged: (_){
                      calculateStock();
                      setLocalState(() {});
                      },
                  ),
                ),
                labeledField(
                  label: "Unit",
                  field: TextFormField(
                    controller: unitCtrl,
                    keyboardType: TextInputType.number,
                    cursorColor: royal,
                    style: const TextStyle(color: royal),
                    decoration: _inputDecoration("Unit"),
                    onChanged: (_) {
                      calculateStock();
                      setLocalState(() {});
                      },
                  ),
                ),
                labeledField(
                  label: "Purchase ₹",
                  field: TextFormField(
                    controller: purchasePriceCtrl,
                    keyboardType: TextInputType.number,
                    cursorColor: royal,
                    style: TextStyle(color: royal),
                    decoration: _inputDecoration("Unit price"),
                    onChanged: (_) {
                      calculateStock();
                      calculateSellingFromProfit();
                      setLocalState(() {});
                    },
                  ),
                ),
                labeledField(
                  label: "Profit %",
                  field: TextFormField(
                    controller: profitCtrl,
                    cursorColor: royal,
                    style: TextStyle(color: royal),
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration("Profit"),
                    onChanged: (_) {
                      isEditingProfit = true;
                      calculateSellingFromProfit();
                      isEditingProfit = false;
                      setLocalState(() {});
                    },
                  ),
                ),
                labeledField(
                  label: "Selling ₹",
                  field: TextFormField(
                    controller: sellingPriceCtrl,
                    cursorColor: royal,
                    style: TextStyle(color: royal),
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration("Selling Price"),
                    onChanged: (_) {
                      isEditingSelling = true;
                      calculateProfitFromSelling();
                      isEditingSelling = false;
                      setLocalState(() {});
                    },
                  ),
                ),
                labeledField(
                  label: "Supplier Phone",
                  field: StatefulBuilder(
                    builder: (context, setLocalState) {
                      Timer? debounce;
                      return TextFormField(
                        controller: phoneCtrl,
                        cursorColor: royal,
                        style: TextStyle(color: royal),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: _inputDecoration("Enter Supplier Phone number"),
                        onChanged: (value) {
                          // Reset name if phone changes
                          setLocalState(() {
                            sellerCtrl.text = '';
                          });

                          if (debounce?.isActive ?? false) debounce!.cancel();
                          debounce = Timer(const Duration(milliseconds: 500), () async {
                            // ✅ Only call API when 10 digits entered
                            if (value.length != 10) return;

                            try {
                              final url = Uri.parse("$baseUrl/suppliers/search/by-phone/$shopId?phone=$value");
                              final response = await http.get(url);

                              if (response.statusCode == 200) {
                                final data = jsonDecode(response.body) as List;
                                if (data.isNotEmpty) {
                                  // Auto-fill the first supplier's name
                                  setLocalState(() {
                                    sellerCtrl.text = data[0]['name'] ?? '';
                                  });
                                }
                              }
                            } catch (e) {
                              // Ignore errors silently
                            }
                          });
                        },
                      );
                    },
                  ),
                ),

                labeledField(
                  label: "Supplier Name",
                  field: TextFormField(
                    cursorColor: royal,
                    style: TextStyle(color: royal),
                    controller: sellerCtrl,
                    onChanged: (_) => setLocalState(() {}), // ✅ update button state
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration("Enter Supplier name"),
                  ),
                ),
                const SizedBox(height: 10,),
                Center(
                  child: Text(
                    "Stock: $stock",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: royal,
                      fontSize: 14,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    "Total Cost: ₹${totalPurchasePrice.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: SizedBox(
                    width: 150,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFormValid() ? royal : Colors.grey, // enabled/disabled color
                        foregroundColor: isFormValid() ? Colors.white : royal, // text color
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
                            "unit": unitCtrl.text,
                            "reorder": int.tryParse(reorderCtrl.text),
                            "hsncode":hsnCtrl.text,
                            "stock": stock,
                            "total_cost":totalPurchasePrice.toStringAsFixed(2),
                            "profit": double.tryParse(profitCtrl.text) ?? 0,
                            "purchase_price": purchasePriceCtrl.text,
                            "selling_price": sellingPriceCtrl.text,
                            "seller_name": sellerCtrl.text,
                            "phone": phoneCtrl.text,
                          }),
                        );

                        fetchMedicines();
                        // ✅ Clear the form
                        nameCtrl.clear();
                        ndcCtrl.clear();
                        batchCtrl.text = "01";
                        rackCtrl.clear();
                        quantityCtrl.clear();
                        unitCtrl.clear();
                        purchasePriceCtrl.clear();
                        sellingPriceCtrl.clear();
                        profitCtrl.clear();
                        sellerCtrl.clear();
                        phoneCtrl.clear();
                        otherCategoryCtrl.clear();
                        selectedCategory = medicineCategories.first;
                        isOtherCategory = false;
                        mfgDate = null;
                        expDate = null;
                        stock = 0;
                        totalPurchasePrice = 0;
                        isNameTaken = false;
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
            ),
          ),
        );
      },
    );
  }

  Widget _dialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90, // fixed width for label
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: royal, // label color
              ),
            ),
          ),
          Expanded(
            child: Text(
              ":$value",
              style: const TextStyle(
                color: royal, // value color
              ),
            ),
          ),
        ],
      ),
    );
  }

  void calculate() {
    final q = double.tryParse(qtyCtrl.text) ?? 0;
    final u = double.tryParse(unitCtrl.text) ?? 0;
    final p = double.tryParse(priceCtrl.text) ?? 0;
    final pr = double.tryParse(profitCtrl.text) ?? 0;

    stock = q * u;
    purchase = stock * p;
    sell = p + (p * pr / 100);
    setState(() {});
  }

  Widget addBatchForm() {
    final rackCtrl = TextEditingController();
    final quantityCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final purchasePriceCtrl = TextEditingController();
    final sellingPriceCtrl = TextEditingController();
    final profitCtrl = TextEditingController();
    final sellerCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final hsnCtrl = TextEditingController();

    DateTime? mfgDate;
    DateTime? expDate;

    double stock = 0;

    return StatefulBuilder(
      builder: (context, setLocalState) {

        void calculateStock() {
          final qty = double.tryParse(quantityCtrl.text) ?? 0;
          final unit = double.tryParse(unitCtrl.text) ?? 0;
          stock = qty * unit;

          final purchase = double.tryParse(purchasePriceCtrl.text) ?? 0;
          totalPurchasePrice = stock * purchase;

          setLocalState(() {});
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

        void calculateSellingFromProfit() {
          if (isEditingSelling) return; // Prevent loop
          final purchase = double.tryParse(purchasePriceCtrl.text) ?? 0;
          final profitPercent = double.tryParse(profitCtrl.text) ?? 0;
          final selling = purchase + (purchase * profitPercent / 100);
          sellingPriceCtrl.text = selling.toStringAsFixed(2);
        }

        void calculateProfitFromSelling() {
          if (isEditingProfit) return; // Prevent loop
          final purchase = double.tryParse(purchasePriceCtrl.text) ?? 0;
          final selling = double.tryParse(sellingPriceCtrl.text) ?? 0;
          if (purchase != 0) {
            final profit = ((selling - purchase) / purchase) * 100;
            profitCtrl.text = profit.toStringAsFixed(2);
          }
        }

        bool isFormValid() {
          return selectedMedicineId != null &&
              batchCtrl.text.isNotEmpty &&
              !isBatchTaken &&   // ✅ disable if batch exists
              quantityCtrl.text.isNotEmpty &&
              unitCtrl.text.isNotEmpty &&
              purchasePriceCtrl.text.isNotEmpty &&
              sellingPriceCtrl.text.isNotEmpty &&
              sellerCtrl.text.isNotEmpty &&
              phoneCtrl.text.isNotEmpty &&
              mfgDate != null &&
              expDate != null;
        }

        Widget confirmBatchDialog() {

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: royal, width: 1.3),
            ),
            title: const Center(
              child: Text(
                "Confirm Batch Details",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: royal,
                ),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogRow("Medicine", selectedMedicine!['name']),
                  _dialogRow("Batch No", batchCtrl.text),
                  _dialogRow("MFG Date", mfgDate != null ? mfgDate!.toLocal().toString().split(' ')[0] : "-"),
                  _dialogRow("EXP Date", expDate != null ? expDate!.toLocal().toString().split(' ')[0] : "-"),
                  _dialogRow("Rack No", rackCtrl.text.isEmpty ? "-" : rackCtrl.text),
                  _dialogRow("Quantity", quantityCtrl.text),
                  _dialogRow("Unit", unitCtrl.text),
                  _dialogRow("Stock", stock.toString()),
                  _dialogRow("Purchase Price", purchasePriceCtrl.text),
                  _dialogRow("Profit %", profitCtrl.text),
                  _dialogRow("Selling Price", sellingPriceCtrl.text),
                  _dialogRow("Total Cost", "₹${totalPurchasePrice.toStringAsFixed(2)}"),
                  _dialogRow("Seller Name", sellerCtrl.text),
                  _dialogRow("Phone", phoneCtrl.text),
                ],
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: royal,
                  side: const BorderSide(color: royal),
                ),
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: royal,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("OK"),
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
                medicineAutocomplete(setLocalState), // ✅ pass it here

                if (selectedMedicine != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      "Current Stock: ${selectedMedicine!['stock']}",
                      style: const TextStyle(color: royal),
                    ),
                  ),
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

                      debounce = Timer(const Duration(milliseconds: 500), () async {
                        final batch = value.trim();

                        if (batch.isEmpty) {
                          setLocalState(() => isBatchTaken = false);
                          return;
                        }

                        final isValid = await validateBatchBackend(batch);

                        setLocalState(() {
                          isBatchTaken = !isValid; // ❌ taken when backend returns false
                        });
                      });
                    },
                  ),
                ),
                labeledField(
                  label: "MFG Date",
                  field: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: royal,
                      backgroundColor: royal.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: royal, width: 0.5),
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
                                primary: royal,       // header & selected date
                                onPrimary: Colors.white, // selected date text
                                onSurface: royal,     // unselected dates
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(foregroundColor: royal),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) setLocalState(() => mfgDate = picked);
                    },
                    child: Text(
                      mfgDate == null ? "Select date" : mfgDate!.toLocal().toString().split(' ')[0],
                      style: TextStyle(color: royal),
                    ),
                  ),
                ),

                labeledField(
                  label: "EXP Date",
                  field: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: royal,
                      backgroundColor: royal.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: royal, width: 0.5),
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
                                style: TextButton.styleFrom(foregroundColor: royal),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) setLocalState(() => expDate = picked);
                    },
                    child: Text(
                      expDate == null ? "Select date" : expDate!.toLocal().toString().split(' ')[0],
                      style: TextStyle(color: royal),
                    ),
                  ),
                ),

                labeledField(
                  label: "Rack No",
                  field: TextFormField(
                    controller: rackCtrl,
                    cursorColor: royal,
                    style: const TextStyle(color: royal),
                    decoration: _inputDecoration("Optional"),
                  ),
                ),
                labeledField(
                  label: "HSN Code",
                  field: TextFormField(
                    cursorColor: royal,
                    style: TextStyle(color: royal),
                    controller: hsnCtrl,
                    onChanged: (_) => setLocalState(() {}), // ✅ update button state
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration("Enter HSN Code"),
                  ),
                ),
                labeledField(
                  label: "Quantity",
                  field: TextFormField(
                    controller: quantityCtrl,
                    keyboardType: TextInputType.number,
                    cursorColor: royal,
                    style: const TextStyle(color: royal),
                    decoration: _inputDecoration("Qty"),
                    onChanged: (_){
                      calculateStock();
                      setLocalState(() {});
                    },
                  ),
                ),
                labeledField(
                  label: "Unit",
                  field: TextFormField(
                    controller: unitCtrl,
                    keyboardType: TextInputType.number,
                    cursorColor: royal,
                    style: const TextStyle(color: royal),
                    decoration: _inputDecoration("Unit"),
                    onChanged: (_) {
                      calculateStock();
                      setLocalState(() {});
                    },
                  ),
                ),
                labeledField(
                  label: "Purchase ₹",
                  field: TextFormField(
                    controller: purchasePriceCtrl,
                    keyboardType: TextInputType.number,
                    cursorColor: royal,
                    style: TextStyle(color: royal),
                    decoration: _inputDecoration("Unit price"),
                    onChanged: (_) {
                      calculateStock();
                      calculateSellingFromProfit();
                      setLocalState(() {});
                    },
                  ),
                ),
                labeledField(
                  label: "Profit %",
                  field: TextFormField(
                    controller: profitCtrl,
                    cursorColor: royal,
                    style: TextStyle(color: royal),
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration("Profit"),
                    onChanged: (_) {
                      isEditingProfit = true;
                      calculateSellingFromProfit();
                      isEditingProfit = false;
                      setLocalState(() {});
                    },
                  ),
                ),
                labeledField(
                  label: "Selling ₹",
                  field: TextFormField(
                    controller: sellingPriceCtrl,
                    cursorColor: royal,
                    style: TextStyle(color: royal),
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration("Selling Price"),
                    onChanged: (_) {
                      isEditingSelling = true;
                      calculateProfitFromSelling();
                      isEditingSelling = false;
                      setLocalState(() {});
                    },
                  ),
                ),
                labeledField(
                  label: "Supplier Phone",
                  field: StatefulBuilder(
                    builder: (context, setLocalState) {
                      Timer? debounce;
                      return TextFormField(
                        controller: phoneCtrl,
                        cursorColor: royal,
                        style: TextStyle(color: royal),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: _inputDecoration("Enter Supplier Phone number"),
                        onChanged: (value) {
                          // Reset name if phone changes
                          setLocalState(() {
                            sellerCtrl.text = '';
                          });

                          if (debounce?.isActive ?? false) debounce!.cancel();
                          debounce = Timer(const Duration(milliseconds: 500), () async {
                            // ✅ Only call API when 10 digits entered
                            if (value.length != 10) return;

                            try {
                              final url = Uri.parse("$baseUrl/suppliers/search/by-phone/$shopId?phone=$value");
                              final response = await http.get(url);

                              if (response.statusCode == 200) {
                                final data = jsonDecode(response.body) as List;
                                if (data.isNotEmpty) {
                                  // Auto-fill the first supplier's name
                                  setLocalState(() {
                                    sellerCtrl.text = data[0]['name'] ?? '';
                                  });
                                }
                              }
                            } catch (e) {
                              // Ignore errors silently
                            }
                          });
                        },
                      );
                    },
                  ),
                ),

                labeledField(
                  label: "Supplier Name",
                  field: TextFormField(
                    cursorColor: royal,
                    style: TextStyle(color: royal),
                    controller: sellerCtrl,
                    onChanged: (_) => setLocalState(() {}), // ✅ update button state
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration("Enter Supplier name"),
                  ),
                ),
                const SizedBox(height: 10),

                Center(
                  child: Text("Stock: $stock",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: royal)),
                ),

                Center(
                  child: Text("Total Cost: ₹${totalPurchasePrice.toStringAsFixed(2)}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent)),
                ),

                const SizedBox(height: 14),
                Center(
                  child: SizedBox(
                    width: 150,
                    child:  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFormValid() ? royal : Colors.grey, // enabled/disabled color
                        foregroundColor: isFormValid() ? Colors.white : royal, // text color
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
                        if (ok != true) return;
                        await http.post(
                          Uri.parse("$baseUrl/inventory/medicine/$selectedMedicineId/batch"),
                          headers: {"Content-Type": "application/json"},
                          body: jsonEncode({
                            "shop_id": shopId,
                            "batch_no": batchCtrl.text,
                            "mfg_date": mfgDate!.toIso8601String(),
                            "exp_date": expDate!.toIso8601String(),
                            "quantity": quantityCtrl.text,
                            "unit": unitCtrl.text,
                            "rack_no": rackCtrl.text,
                            "profit": profitCtrl.text,
                            "purchase_price": purchasePriceCtrl.text,
                            "selling_price": sellingPriceCtrl.text,
                            "stock_quantity": stock.toInt(),
                            "total_cost":totalPurchasePrice,
                            "hsncode":hsnCtrl.text,
                            "seller_name": sellerCtrl.text,
                            "seller_phone": phoneCtrl.text,
                            "reason": "New Batch",
                          }),
                        );

                        fetchMedicines();
                        medicineCtrl.clear();   // ✅ Clears autocomplete text
                        selectedMedicine = null;
                        selectedMedicineId = null;
                        batchCtrl.clear();
                        rackCtrl.clear();
                        quantityCtrl.clear();
                        unitCtrl.clear();
                        purchasePriceCtrl.clear();
                        sellingPriceCtrl.clear();
                        profitCtrl.clear();
                        sellerCtrl.clear();
                        phoneCtrl.clear();
                        mfgDate = null;
                        expDate = null;
                        stock = 0;
                        totalPurchasePrice = 0;

                        setState(() => showAddBatch = false);
                      }
                          : null,
                      child: const Text("Submit Batch"),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
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
            Padding(padding: const EdgeInsets.all(8), child: actionButtons()),
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
    );
  }
}
