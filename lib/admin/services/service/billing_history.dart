import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../public/config.dart';
import '../../../public/main_navigation.dart';

const Color royal = Color(0xFF875C3F);

class BillingHistoryPage extends StatefulWidget {
  const BillingHistoryPage({super.key});

  @override
  State<BillingHistoryPage> createState() => _BillingHistoryPageState();
}

class _BillingHistoryPageState extends State<BillingHistoryPage> {
  bool _isFetching = true;
  List<Map<String, dynamic>> bills = [];
  List<Map<String, dynamic>> _filteredBills = [];
  Map<String, dynamic>? shopDetails;
  DateTime _selectedMonth = DateTime.now();
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
      _filterBills();
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
      final response = await http.get(Uri.parse("$baseUrl/billing/history/$shopId"));
      if (response.statusCode == 200) {
        bills = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      _showMessage("Error fetching billing history: $e");
    } finally {
      setState(() {
        _isFetching = false;
      });
    }
  }

  void _filterBills() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredBills = bills.where((bill) {
        final billDate = DateTime.tryParse(bill['created_at'] ?? '');
        final matchesMonth = billDate != null &&
            billDate.year == _selectedMonth.year &&
            billDate.month == _selectedMonth.month;

        final matchesSearch = (bill['customer_name']?.toLowerCase().contains(query) ?? false) ||
            (bill['phone']?.contains(query) ?? false);

        return matchesMonth && matchesSearch;
      }).toList();

      // Sort descending by date
      _filteredBills.sort((a, b) {
        final da = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
        final db = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
        return db.compareTo(da);
      });
    });
  }

  Future<void> _pickMonthYear() async {
    int selectedYear = _selectedMonth.year;
    int selectedMonth = _selectedMonth.month;

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Select Month and Year",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: royal)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _monthDropdown(selectedMonth, (val) => selectedMonth = val)),
                  ],
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(child: _yearDropdown(selectedYear, (val) => selectedYear = val)),
                  ],
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: royal))),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: royal, foregroundColor: Colors.white),
                      onPressed: () {
                        setState(() {
                          _selectedMonth = DateTime(selectedYear, selectedMonth);
                          _filterBills(); // ✅ filter bills for the new month
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _monthDropdown(int value, Function(int) onChanged) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: "Month",
        labelStyle: TextStyle(color: royal),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dropdownColor: Colors.white,
      items: List.generate(12, (index) {
        final m = index + 1;
        return DropdownMenuItem(value: m, child: Text(DateFormat.MMMM().format(DateTime(0, m))));
      }),
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
    );
  }

  Widget _yearDropdown(int value, Function(int) onChanged) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: "Year",
        labelStyle: TextStyle(color: royal),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dropdownColor: Colors.white,
      items: List.generate(30, (index) {
        final y = DateTime.now().year - 10 + index;
        return DropdownMenuItem(value: y, child: Text(y.toString()));
      }),
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
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

  Widget _buildBillCard(Map<String, dynamic> bill) {
    final date = DateTime.tryParse(bill['created_at'] ?? '');
    final items = List<Map<String, dynamic>>.from(bill['items'] ?? []);
    final paymentMode = bill['payment_mode'] ?? 'CASH';

    Color paymentColor = paymentMode.toUpperCase() == 'ONLINE' ? Colors.green : Colors.orange;

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: royal.withValues(alpha:0.6)),
      ),
      elevation: 4,
      shadowColor: royal.withValues(alpha:0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showBillDetailsBottomSheet(bill),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Name and Payment Mode
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      bill['customer_name'] ?? '-',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: royal,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: paymentColor.withValues(alpha:0.2),
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

              // Bill ID, Phone, Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bill #${bill['bill_id']} | ${bill['phone'] ?? '-'}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                  ),
                  Text(
                    date != null ? DateFormat('dd MMM yyyy').format(date) : '-',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Items count and Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${items.length} Item(s)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    '₹${bill['total']?.toStringAsFixed(2) ?? '0.0'}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: royal,
                    ),
                  ),
                ],
              ),
            ],
          ),
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

  Widget _buildMonthPickerButton() {
    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: royal,
          foregroundColor: Colors.white,
        ),
        onPressed: _pickMonthYear,
        child: Text(DateFormat('MMMM yyyy').format(_selectedMonth)),
      ),
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
            _buildShopCard(shopDetails!),
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
              onChanged: (_) => _filterBills(),
            ),
            const SizedBox(height: 12),
            _buildMonthPickerButton(),
            const SizedBox(height: 12),
            if (_filteredBills.isEmpty)
              Center(
                child: Text("No bills found for ${DateFormat('MMMM yyyy').format(_selectedMonth)}"),
              )
            else
              ..._filteredBills.map(_buildBillCard),
          ],
        ),
      ),
    );
  }
}


class BillDetailPage extends StatelessWidget {
  final Map<String, dynamic> bill;
  const BillDetailPage({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    final items = List<Map<String, dynamic>>.from(bill['items'] ?? []);
    final date = DateTime.tryParse(bill['created_at'] ?? '');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: royal,
        title: Text('Bill ${bill['bill_id']} Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Customer: ${bill['customer_name']}'),
            Text('Phone: ${bill['phone']}'),
            Text('Total: ₹${bill['total']?.toStringAsFixed(2) ?? '0.0'}'),
            Text('Date: ${date != null ? DateFormat('dd/MM/yyyy').format(date) : '-'}'),
            const Divider(),
            const Text("Items:", style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, index) {
                  final item = items[index];
                  return ListTile(
                    title: Text(item['medicine_name'] ?? '-'),
                    subtitle: Text('Batch: ${item['batch_no'] ?? '-'} | Qty: ${item['quantity'] ?? 0}'),
                    trailing: Text('₹${item['total_price']?.toStringAsFixed(2) ?? '0.0'}'),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
