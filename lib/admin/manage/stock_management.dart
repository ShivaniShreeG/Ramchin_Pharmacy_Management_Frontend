import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../public/config.dart';
import '../../../../public/main_navigation.dart';

const Color royalblue = Color(0xFF854929);

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  int? shopId;
  List<Map<String, dynamic>> medicines = [];
  bool isLoading = true;
  Map<String, dynamic>? shopDetails;
  int? selectedMedicineId;
  Map<String, dynamic>? selectedMedicine;
  String selectedType = 'expired'; // expired | deactivated

  bool showAddMedicine = false;
  bool showAddBatch = false;
  final TextEditingController searchCtrl = TextEditingController();

  List<Map<String, dynamic>> filteredMedicines = [];

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
      final endpoint = selectedType == 'expired'
          ? "expired"
          : "deactivated";

      final url = Uri.parse(
        "$baseUrl/medicine-batch/$endpoint/$shopId",
      );

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
        _showMessage("❌ Failed to load $endpoint medicines");
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

  void confirmRemove(Map<String, dynamic> batch) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Batch", style: TextStyle(color: royal)),
        content: Text(
          "Remove batch ${batch['batch_no']} of ${batch['medicine']['name']}?",
          style: const TextStyle(color: royal),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: royal)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Remove", style: TextStyle(color: royal)),
          ),
        ],
      ),
    );

    if (ok == true) {
      removeBatch(batch);
    }
  }

  Future<void> removeBatch(Map<String, dynamic> batch) async {
    try {
      await http.patch(
        Uri.parse("$baseUrl/medicine-batch/remove/$shopId"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "medicine_id": batch['medicine_id'],
          "batch_id": batch['id'],
        }),
      );

      _showMessage("Batch removed successfully");
      fetchMedicines();
    } catch (e) {
      _showMessage("Failed to remove batch");
    }
  }

  Widget batchCardFullUI(Map<String, dynamic> batch) {
    final medicine = batch['medicine'];

    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: royal),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// 🔹 Header: Medicine name + REMOVE
            Row(
              children: [
                Expanded(
                  child: Text(
                    medicine['name'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: royalblue,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => confirmRemove(batch),
                ),
              ],
            ),

            const SizedBox(height: 6),

            /// 🔹 Chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (shouldShow(medicine['id']))
                  badge(Icons.lock, "Medicine-ID", medicine['id'].toString(), Colors.teal),
                badge(Icons.category, "Category", medicine['category'], Colors.orange),
                badge(Icons.inventory_2, "Stock", batch['total_stock'].toString(), Colors.green),
                badge(Icons.batch_prediction_outlined, "Batch", batch['batch_no'], Colors.blue),
              ],
            ),

            const SizedBox(height: 12),
            Divider(color: royal.withValues(alpha: 0.4)),

            /// 🔹 Expandable batch details
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: royal.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: royal.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent, // ❌ removes default ExpansionTile line
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  iconColor: royalblue,
                  collapsedIconColor: royal,
                  title: const Text(
                    "Batch Details",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: royal,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
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
                    ),
                  ],
                ),
              ),
            ),


            /// 🔹 Purchase details
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: royal.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: royal.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent, // 🚫 remove default divider
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  iconColor: royalblue,
                  collapsedIconColor: royal,
                  title: const Text(
                    "Purchase Details",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: royal,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
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
                    ),
                  ],
                ),
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

  Widget infoRow(String label, dynamic value) {
    if (value == null) return const SizedBox.shrink();
    if (value is String && value.trim().isEmpty) return const SizedBox.shrink();
    if (value is num && value == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: royalblue,
              ),
            ),
          ),
          Expanded(
            child: Text(
              ": $value",
              style: const TextStyle(color: royal),
            ),
          ),
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
          "Stock",
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
            const SizedBox(height: 10),
            if (shopDetails != null) _buildHallCard(shopDetails!),
            const SizedBox(height: 16),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 600, // constrain width
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text("Expired"),
                              selected: selectedType == 'expired',
                              selectedColor: Colors.red.withValues(alpha: 0.2),
                              onSelected: (_) {
                                setState(() => selectedType = 'expired');
                                fetchMedicines();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text("Deactivated"),
                              selected: selectedType == 'deactivated',
                              selectedColor: Colors.orange.withValues(alpha: 0.2),
                              onSelected: (_) {
                                setState(() => selectedType = 'deactivated');
                                fetchMedicines();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (medicines.isEmpty)
                        Center(
                          child:
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text("No medicines found",style: TextStyle(color: royal),),
                        ),
                        ),
                      if (medicines.isNotEmpty) searchBar(),
                      const SizedBox(height: 18),
                      ...filteredMedicines.map(
                            (batch) => Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: batchCardFullUI(batch),
                        ),
                      ),
                      const SizedBox(height: 70),

                    ],
                  ),
                ),
              ),
            )

          ],
        ),

      ),
    );
  }
}
