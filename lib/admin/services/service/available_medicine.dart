import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/config.dart';
import '../../../../public/main_navigation.dart';
import 'dart:async';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);

class AvailableMedicinePage extends StatefulWidget {
  const AvailableMedicinePage({super.key});

  @override
  State<AvailableMedicinePage> createState() => _AvailableMedicinePageState();
}

class _AvailableMedicinePageState extends State<AvailableMedicinePage> {
  int? shopId;
  List<Map<String, dynamic>> medicines = [];
  bool isLoading = true;
  Map<String, dynamic>? shopDetails;
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
        "Short-Dated (${daysLeft(expiryDate)} days left)",
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
      final url = Uri.parse("$baseUrl/medicine/available/shop/$shopId");
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
              if (batch['expiry_date'] != null)
                expiryBadge(batch['expiry_date']),
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
          "Medicines Available",
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
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 600, // 👈 only form is constrained
                ),
                child: Column(
                  children: [
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
    ),],),),);
  }
}
