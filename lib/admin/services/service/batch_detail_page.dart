import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/config.dart';
import '../../../../public/main_navigation.dart';
import 'package:intl/intl.dart';

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

  Future<void> _handleBillReference(String reference) async {
    // Example: "Bill-2"
    final billId = int.tryParse(reference.replaceAll('Bill-', ''));
    final shopId = shopDetails?['shop_id']; // ✅ FIXED
    if (billId == null) return;

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/billing/$shopId/$billId'),
      );

      if (res.statusCode == 200) {
        final bill = jsonDecode(res.body);
        _showBillDetailsBottomSheet(bill);
      } else {
        _showMessage("Unable to load bill details");
      }
    } catch (e) {
      _showMessage("Error loading bill: $e");
    }
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
          Text(label),//style: const TextStyle(color:),
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

  void _showBillDetailsBottomSheet(Map<String, dynamic> bill) {
    final items = List<Map<String, dynamic>>.from(bill['items'] ?? []);
    final date = DateTime.tryParse(bill['created_at'] ?? '');
    final paymentMode = bill['payment_mode'] ?? 'CASH';
    final paymentColor = paymentMode.toUpperCase() == 'ONLINE' ? Colors.green : Colors.orange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Top Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    height: 60,
                    decoration: const BoxDecoration(
                      color: royal,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Bill #${bill['bill_id']} Details",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: paymentColor.withValues(alpha:0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            paymentMode.toUpperCase(),
                            style: TextStyle(
                              color: paymentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bill Info
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: royal.withValues(alpha:0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: royal.withValues(alpha:0.2)),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Customer: ${bill['customer_name'] ?? '-'}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Phone: ${bill['phone'] ?? '-'}', style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('Date: ${date != null ? DateFormat('dd/MM/yyyy').format(date) : '-'}',
                              style: const TextStyle(fontSize: 14)),
                          Text('Doctor: ${bill['doctor_name'] ?? '-'}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Total: ₹${bill['total']?.toStringAsFixed(2) ?? '0.0'}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),

                  const Divider(height: 1, thickness: 1),

                  // Items List
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (_, index) {
                        final item = items[index];
                        final name = item['medicine']?['name'] ?? item['name'] ?? 'Unnamed Medicine';
                        final batch = item['batch']?['batch_no'] ?? item['batch'] ?? '-';
                        final qty = item['unit'] ?? 0;
                        final unitPrice = (item['unit_price'] ?? 0).toDouble();
                        final total = qty * unitPrice;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: royal.withValues(alpha:0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: royal.withValues(alpha:0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87)),
                                    const SizedBox(height: 4),
                                    Text('Batch: $batch | Qty: $qty',
                                        style: const TextStyle(fontSize: 14, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Text('₹$total',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, color: royal, fontSize: 16)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool shouldShow(dynamic value) {
    if (value == null) return false;
    if (value is String && value.trim().isEmpty) return false;
    if (value is num && value == 0) return false;
    return true;
  }

  Widget _infoCard() {
    final m = widget.medicine;
    final b = widget.batch;
    final Map<String, dynamic>? purchaseDetails =
    b['purchase_details'] as Map<String, dynamic>?;
    final bool hasPurchasedDetails =
        shouldShow(b['quantity']) ||
            shouldShow(b['free_quantity']) ||
            (purchaseDetails != null && shouldShow(purchaseDetails['rate_per_quantity'])) ||
            (purchaseDetails != null && shouldShow(purchaseDetails['gst_percent'])) ||
            (purchaseDetails != null && shouldShow(purchaseDetails['gst_per_quantity'])) ||
            (purchaseDetails != null && shouldShow(purchaseDetails['base_amount'])) ||
            (purchaseDetails != null && shouldShow(purchaseDetails['total_gst_amount'])) ||
            (purchaseDetails != null && shouldShow(purchaseDetails['purchase_price'])) ||
            (purchaseDetails != null && shouldShow(purchaseDetails['purchase_date'])) ||
            shouldShow(b['supplier']?['name']) ||
            shouldShow(b['supplier']?['phone']) ||
            shouldShow(b['HSN']);

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
            _infoRowIfNotEmpty("Total Stock", b['total_stock']),
            _infoRowIfNotEmpty("Total Quantity", b['total_quantity']),
            _infoRowIfNotEmpty("Unit", b['unit']),

            const Divider(height: 24,color: royal,),

            /// ───── PRICING ─────
            _cardSectionTitle("Pricing", Icons.currency_rupee),
            _infoRowIfNotEmpty(
              "Purchase Price/Quantity",
              b['purchase_price_quantity'] != null ? "₹${b['purchase_price_quantity']}" : null,
            ),
            _infoRowIfNotEmpty(
              "Purchase Price/Unit",
              b['purchase_price_unit'] != null ? "₹${b['purchase_price_unit']}" : null,
            ),
            _infoRowIfNotEmpty(
              "Selling Price/Quantity",
              b['selling_price_quantity'] != null ? "₹${b['selling_price_quantity']}" : null,
            ),
            _infoRowIfNotEmpty(
              "Selling Price/Unit",
              b['selling_price_unit'] != null ? "₹${b['selling_price_unit']}" : null,
            ),
            _infoRowIfNotEmpty(
              "MRP",
              b['mrp'] != null ? "₹${b['mrp']}" : null,
            ),
            _infoRowIfNotEmpty(
              "Profit %",
              b['profit'] != null ? "${b['profit']}%" : null,
            ),
            if(hasPurchasedDetails)
              const Divider(height: 24,color: royal,),

            if(hasPurchasedDetails)
              _cardSectionTitle("Purchased Details", Icons.store),
            _infoRowIfNotEmpty("Supplier Name", b['supplier']?['name']),
            _infoRowIfNotEmpty("Supplier Phone", b['supplier']?['phone']),
            _infoRowIfNotEmpty("HSN Code", b['HSN']),
            _infoRowIfNotEmpty("Purchased Quantity", b['quantity']),
            _infoRowIfNotEmpty("Free Quantity", b['free_quantity']),
            _infoRowIfNotEmpty(
              "Rate/ Quantity",
              purchaseDetails?['rate_per_quantity'] != null
                  ? "₹${purchaseDetails?['rate_per_quantity']}"
                  : null,
            ),
            _infoRowIfNotEmpty(
              "GST %/Quantity",
              purchaseDetails?['gst_percent'] != null
                  ? "${purchaseDetails?['gst_percent']}%"
                  : null,
            ),
            _infoRowIfNotEmpty(
              "GST Amount/Quantity",
              purchaseDetails?['gst_per_quantity'] != null
                  ? "₹${purchaseDetails?['gst_per_quantity']}"
                  : null,
            ),
            _infoRowIfNotEmpty(
              "Base Amount",
              purchaseDetails?['base_amount'] != null
                  ? "₹${purchaseDetails?['base_amount']}"
                  : null,
            ),
            _infoRowIfNotEmpty(
              "Total GST Amount",
              purchaseDetails?['total_gst_amount'] != null
                  ? "₹${purchaseDetails?['total_gst_amount']}"
                  : null,
            ),
            _infoRowIfNotEmpty(
              "Purchase Price",
              purchaseDetails?['purchase_price'] != null
                  ? "₹${purchaseDetails?['purchase_price']}"
                  : null,
            ),
            _infoRowIfNotEmpty(
              "Purchase Date",
              _formatDate(purchaseDetails?['purchase_date']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _movementTile(Map m) {
    final isIn = m['movement_type'] == 'IN';
    final color = isIn ? Colors.green : Colors.red;
    final reference = m['reference']; // ✅ FIXED

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
        trailing: reference != null && reference.startsWith('Bill-')
            ? InkWell(
          onTap: () => _handleBillReference(reference),
          child: Text(
            reference,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.teal,
            ),
          ),
        )
            : Text(
          reference ?? '-',
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
