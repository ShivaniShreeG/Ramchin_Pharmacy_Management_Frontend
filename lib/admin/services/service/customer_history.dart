import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../public/config.dart';
import '../../../public/main_navigation.dart';

const Color royal = Color(0xFF875C3F);

class CustomerHistoryPage extends StatefulWidget {
  const CustomerHistoryPage({super.key});

  @override
  State<CustomerHistoryPage> createState() => _CustomerHistoryPageState();
}

class _CustomerHistoryPageState extends State<CustomerHistoryPage> {
  bool _isFetching = true;
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> filteredCustomers = [];
  Map<String, dynamic>? shopDetails;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    if (shopId != null) {
      await _fetchShopDetails(shopId);
      await _fetchBillingHistory(shopId);
      _filterCustomers();
    }
  }

  Future<void> _fetchShopDetails(int shopId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/shops/$shopId"));
      if (response.statusCode == 200) {
        shopDetails = jsonDecode(response.body);
      }
    } catch (e) {
      _showMessage("Error fetching shop details: $e");
    } finally {
      setState(() {});
    }
  }

  Future<void> _fetchBillingHistory(int shopId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/billing/history/grouped/$shopId"),
      );

      if (response.statusCode == 200) {
        customers =
        List<Map<String, dynamic>>.from(jsonDecode(response.body));
        filteredCustomers = customers;
      }
    } catch (e) {
      _showMessage("Error fetching history: $e");
    } finally {
      setState(() => _isFetching = false);
    }
  }

  void _filterCustomers() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      filteredCustomers = customers.where((c) {
        final name = c['customer_name']?.toLowerCase() ?? '';
        final phone = c['phone'] ?? '';
        return name.contains(query) || phone.contains(query);
      }).toList();
    });
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

  Widget _buildShopCard(Map<String, dynamic> hall) {
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

  Widget _buildCustomerCard(Map<String, dynamic> customer) {
    final bills = List<Map<String, dynamic>>.from(customer['bills']);

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),side: BorderSide(color: royal)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        backgroundColor: royal.withValues(alpha: 0.08),
        collapsedBackgroundColor: royal.withValues(alpha: 0.04),
        iconColor: royal,
        collapsedIconColor: royal,
        textColor: royal,
        collapsedTextColor: royal,
        title: Text(
          customer['customer_name'] ?? '-',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,color: royal),
        ),
        subtitle: Text(
          "${customer['phone']} • ${bills.length} bill(s)",
        ),
        children: bills.map((bill) {
          return InkWell(
            onTap: () => _showBillDetailsBottomSheet(bill),
            child: _buildBillCard(bill),
          );
        }).toList(),
      ),
    );
  }
  Widget _buildBillCard(Map<String, dynamic> bill) {
    final date = DateTime.tryParse(bill['created_at'] ?? '');
    final paymentMode = bill['payment_mode'] ?? 'CASH';

    Color paymentColor =
    paymentMode.toUpperCase() == 'ONLINE' ? Colors.green : Colors.orange;

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),side: BorderSide(color: royal)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bill #${bill['bill_id']}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: paymentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    paymentMode.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: paymentColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Date
            Text(
              date != null
                  ? DateFormat('dd MMM yyyy').format(date)
                  : '-',
              style: TextStyle(color: Colors.grey[700]),
            ),

            const SizedBox(height: 6),

            // Total
            Text(
              'Total: ₹${bill['total']?.toStringAsFixed(2) ?? '0.00'}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: royal,
              ),
            ),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text("Billing History",style: TextStyle(color: Colors.white),),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => MainNavigation(initialIndex: 0)));
            },
          )
        ],
      ),
      body: _isFetching
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if(shopDetails!=null)_buildShopCard(shopDetails!),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              cursorColor: royal,
              style: TextStyle(color: royal),
              decoration:  InputDecoration(
                labelText: "Search by customer or phone",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
                prefixIconColor: royal,
                labelStyle: TextStyle(color: royal),
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
              ),
              onChanged: (_) => _filterCustomers(),
            ),
            const SizedBox(height: 12),
            if (filteredCustomers.isEmpty)
              const Center(
                child: Text("No customer history found"),
              )
            else
              ...filteredCustomers.map(_buildCustomerCard),
          ],
        ),
      ),
    );
  }
}

//
// class BillDetailPage extends StatelessWidget {
//   final Map<String, dynamic> bill;
//   const BillDetailPage({super.key, required this.bill});
//
//   @override
//   Widget build(BuildContext context) {
//     final items = List<Map<String, dynamic>>.from(bill['items'] ?? []);
//     final date = DateTime.tryParse(bill['created_at'] ?? '');
//
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: royal,
//         title: Text('Bill ${bill['bill_id']} Details'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             Text('Customer: ${bill['customer_name']}'),
//             Text('Phone: ${bill['phone']}'),
//             Text('Total: ₹${bill['total']?.toStringAsFixed(2) ?? '0.0'}'),
//             Text('Date: ${date != null ? DateFormat('dd/MM/yyyy').format(date) : '-'}'),
//             const Divider(),
//             const Text("Items:", style: TextStyle(fontWeight: FontWeight.bold)),
//             Expanded(
//               child: ListView.builder(
//                 itemCount: items.length,
//                 itemBuilder: (_, index) {
//                   final item = items[index];
//                   return ListTile(
//                     title: Text(item['medicine_name'] ?? '-'),
//                     subtitle: Text('Batch: ${item['batch_no'] ?? '-'} | Qty: ${item['quantity'] ?? 0}'),
//                     trailing: Text('₹${item['total_price']?.toStringAsFixed(2) ?? '0.0'}'),
//                   );
//                 },
//               ),
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }
