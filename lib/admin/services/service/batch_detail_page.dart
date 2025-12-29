import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../public/config.dart';
import '../../../../public/main_navigation.dart';
import 'package:intl/intl.dart';


const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);

class BatchDetailPage extends StatefulWidget {
  final Map medicine;
  final Map batch;

  const BatchDetailPage({
    super.key,
    required this.medicine,
    required this.batch,
  });

  @override
  State<BatchDetailPage> createState() => _BatchDetailPageState();
}
class _BatchDetailPageState extends State<BatchDetailPage> {
  Map<String, dynamic>? shopDetails;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchHallDetails();
  }

  String? _formatDate(dynamic date) {
    if (date == null) return null;
    return DateFormat('dd MMM yyyy').format(DateTime.parse(date));
  }

  Widget _cardSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: royal, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: royal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRowIfNotEmpty(String label, dynamic value) {
    if (value == null) return const SizedBox.shrink();
    if (value is String && value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, ),//style: const TextStyle(color:),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value.toString(),
              textAlign: TextAlign.right,
              style: const TextStyle(color:royal,fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard() {
    final m = widget.medicine;
    final b = widget.batch;

    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: royal)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// ───── MEDICINE HEADER ─────
            Row(
              children: [
                const Icon(Icons.medical_services, color: royal, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    m['name'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: royal,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 24,color: royal,),

            /// ───── BATCH INFO ─────
            _cardSectionTitle("Batch Information", Icons.inventory_2),
            _infoRowIfNotEmpty("Batch No", b['batch_no']),
            _infoRowIfNotEmpty(
              "Status",
              b['is_active'] == true ? "Active" : "Inactive",
            ),
            _infoRowIfNotEmpty("Rack No", b['rack_no']),
            _infoRowIfNotEmpty("Manufacture Date", _formatDate(b['manufacture_date'])),
            _infoRowIfNotEmpty("Expiry Date", _formatDate(b['expiry_date'])),

            const Divider(height: 24,color: royal,),

            /// ───── STOCK DETAILS ─────
            _cardSectionTitle("Stock Details", Icons.bar_chart),
            _infoRowIfNotEmpty("Quantity", b['quantity']),
            _infoRowIfNotEmpty("Unit", b['unit']),
            _infoRowIfNotEmpty("Total Stock", b['total_stock']),

            const Divider(height: 24,color: royal,),

            /// ───── PRICING ─────
            _cardSectionTitle("Pricing", Icons.currency_rupee),
            _infoRowIfNotEmpty(
              "Unit Price",
              b['unit_price'] != null ? "₹${b['unit_price']}" : null,
            ),
            _infoRowIfNotEmpty(
              "Selling Price",
              b['selling_price'] != null ? "₹${b['selling_price']}" : null,
            ),
            _infoRowIfNotEmpty("Profit %", b['profit']),

            const Divider(height: 24,color: royal,),

            /// ───── PURCHASE & SUPPLIER ─────
            _cardSectionTitle("Purchased Details", Icons.store),
            _infoRowIfNotEmpty("Supplier Name", b['name']),
            _infoRowIfNotEmpty("Supplier Phone", b['phone']),
            _infoRowIfNotEmpty("HSN Code", b['HSN']),
            _infoRowIfNotEmpty("Purchased Stock", b['purchase_stock']),
            _infoRowIfNotEmpty(
              "Purchase Price",
              b['purchase_price'] != null ? "₹${b['purchase_price']}" : null,
            ),
            _infoRowIfNotEmpty("Purchase Date", _formatDate(b['purchased_date'])),

          ],
        ),
      ),
    );
  }

  Widget _movementTile(Map m) {
    final isIn = m['movement_type'] == 'IN';
    final color = isIn ? Colors.green : Colors.red;

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: royal.withValues(alpha: 0.6), // green for IN, red for OUT
          width: 1.2,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha:0.1),
          child: Icon(
            isIn ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
          ),
        ),
        title: Text(
          "Qty: ${m['quantity']}",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          "${m['reason']}\n${DateFormat('dd MMM yyyy').format(
            DateTime.parse(m['movement_date']),
          )}",
        ),
        trailing: Text(
          m['reference'] ?? '-',
          style: const TextStyle(fontWeight: FontWeight.w500),
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

  @override
  Widget build(BuildContext context) {
    final movements = List<Map>.from(widget.batch['movements'] ?? []);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title: Text(
          "${widget.medicine['name']}-${widget.batch['batch_no']}",
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if(shopDetails!=null)_buildHallCard(shopDetails!),
          const SizedBox(height: 16),
          Center(
          child: ConstrainedBox(
          constraints: const BoxConstraints(
          maxWidth: 600, // 👈 only form is constrained
          ),
          child: Column(
          children: [
          _infoCard(),
          const SizedBox(height: 16),
          Center(
            child: Text(
              "Stock Movements",
              style: const TextStyle(
                color: royal,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...movements.map(_movementTile),
          const SizedBox(height: 70),
        ],
      ),
    ),),],),);
  }
}
