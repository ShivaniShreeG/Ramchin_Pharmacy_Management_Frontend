import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../public/main_navigation.dart';
import '../../../services/config.dart';

const royal = Color(0xFF875C3F);

class OrderedMedicinesPage extends StatefulWidget {
  const OrderedMedicinesPage({super.key});

  @override
  State<OrderedMedicinesPage> createState() => _OrderedMedicinesPageState();
}

class _OrderedMedicinesPageState extends State<OrderedMedicinesPage> {
  bool isLoading = true;
  int? shopId;
  Map<String, dynamic>? shopDetails;
  List<Map<String, dynamic>> allOrders = [];

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final Map<int, bool> allOrderSelection = {};

  @override
  void initState() {
    super.initState();
    _loadShopId();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadShopId() async {
    final prefs = await SharedPreferences.getInstance();
    shopId = prefs.getInt('shopId');

    if (shopId != null) {
      await _fetchHallDetails();
      await _fetchAllOrders();
    }

    setState(() => isLoading = false);
  }

  Future<void> _fetchHallDetails() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/shops/$shopId'));
      if (res.statusCode == 200) shopDetails = jsonDecode(res.body);
    } catch (e) {
      debugPrint("Error fetching shop details: $e");
    }
  }

  Future<void> _fetchAllOrders() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/order/ordered/$shopId'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        allOrders = data.map((e) => Map<String, dynamic>.from(e)).toList();

        // ✅ ensure selection keys exist (optional)
        for (final o in allOrders) {
          final int id = (o['order_id'] ?? o['id']) as int;
          allOrderSelection.putIfAbsent(id, () => false);
        }
      }
    } catch (e) {
      debugPrint("Error fetching all orders: $e");
    }
  }

  Widget _buildHallCard(Map<String, dynamic> hall) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 95,
      decoration: BoxDecoration(
        color: royal,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white,
            child: hall['logo'] != null
                ? ClipOval(
              child: Image.memory(
                base64Decode(hall['logo']),
                fit: BoxFit.cover,
                width: 64,
                height: 64,
              ),
            )
                : const Icon(Icons.home_work, color: royal, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hall['name']?.toString().toUpperCase() ?? "SHOP",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        backgroundColor: royal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
        margin: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _submitReceivedOrders(List<Map<String, dynamic>> orders) async {
    try {
      final payloadOrders = orders.map((o) {
        final id = o['order_id'] ?? o['id'];
        return {'order_id': id};
      }).toList();

      final res = await http.post(
        Uri.parse('$baseUrl/order/receive/$shopId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'orders': payloadOrders}),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        showMessage("Orders received successfully");

        allOrderSelection.clear();

        await _fetchAllOrders();
        setState(() {});
      } else {
        showMessage("Failed to submit orders");
      }
    } catch (e) {
      showMessage("Something went wrong");
    }
  }

  List<Map<String, dynamic>> _getSelectedOrders() {
    final selected = <Map<String, dynamic>>[];

    for (final o in allOrders) {
      final int id = (o['order_id'] ?? o['id']) as int;
      if (allOrderSelection[id] == true) selected.add(o);
    }

    return selected;
  }

  List<Map<String, dynamic>> _getSelectedOrderDetails() {
    final selected = <Map<String, dynamic>>[];

    for (final o in allOrders) {
      final int id = (o['order_id'] ?? o['id']) as int;
      if (allOrderSelection[id] == true) {
        selected.add({
          'name': o['medicine']?['name'] ?? '',
          'quantity': o['quantity'] ?? '',
        });
      }
    }

    return selected;
  }

  String _buildConfirmMessage(List<Map<String, dynamic>> items) {
    final buffer = StringBuffer();
    buffer.writeln("Do you receive the following items?\n");

    for (final item in items) {
      buffer.writeln("• ${item['name']}  ×  ${item['quantity']}");
    }
    return buffer.toString();
  }

  void _showConfirmDialog() {
    final selectedOrders = _getSelectedOrders();
    final selectedDetails = _getSelectedOrderDetails();

    if (selectedOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one order")),
      );
      return;
    }

    final message = _buildConfirmMessage(selectedDetails);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          "Confirm Received Orders",
          style: TextStyle(color: royal),
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, height: 1.5, color: royal),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: royal)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: royal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _submitReceivedOrders(selectedOrders);
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      cursorColor: royal,
      style: const TextStyle(color: royal),
      decoration: InputDecoration(
        hintText: "Search by medicine name...",
        hintStyle: TextStyle(color: royal.withAlpha(150)),
        prefixIcon: const Icon(Icons.search, color: royal),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: royal.withAlpha(80)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: royal.withAlpha(100)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: royal.withAlpha(150)),
        ),
      ),
      onChanged: (val) {
        setState(() => _searchQuery = val.toLowerCase());
      },
    );
  }

  Widget _buildOrderCard(
      Map<String, dynamic> order, {
        required bool selected,
        required ValueChanged<bool?> onChanged,
      }) {
    final medicine = order['medicine'] ?? {};
    final supplier = order['supplier'] ?? {};
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: royal.withAlpha(120)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((medicine['name'] ?? '').toString().isNotEmpty)
                    Text(
                      medicine['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: royal,
                      ),
                    ),
                  const SizedBox(height: 6),
                  if ((medicine['category'] ?? '').toString().isNotEmpty)
                    Text("Category: ${medicine['category']}"),
                  if (medicine['current_stock'] != null)
                    Text("Current Stock: ${medicine['current_stock']}"),
                  if (medicine['reorder_level'] != null)
                    Text("Reorder Level: ${medicine['reorder_level']}"),
                  const Divider(height: 20, color: royal, thickness: 0.5),
                  if (order['quantity'] != null)
                    Text(
                      "Ordered Quantity: ${order['quantity']}",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  if (order['order_date'] != null)
                    Text(
                      "Ordered Date: ${DateTime.parse(order['order_date']).toLocal().toString().split(' ')[0]}",
                    ),
                  const Divider(height: 20, color: royal, thickness: 0.5),
                  if ((supplier['name'] ?? '').toString().isNotEmpty)
                    const Text("Supplier",
                        style: TextStyle(fontWeight: FontWeight.bold, color: royal)),
                  if ((supplier['name'] ?? '').toString().isNotEmpty)
                    Text("Name: ${supplier['name']}"),
                  if ((supplier['phone'] ?? '').toString().isNotEmpty)
                    Text("Phone: ${supplier['phone']}"),
                  if ((supplier['email'] ?? '').toString().isNotEmpty)
                    Text("Email: ${supplier['email']}"),
                ],
              ),
            ),
            Checkbox(
              value: selected,
              onChanged: onChanged,
              activeColor: royal,
              checkColor: Colors.white,
              side: const BorderSide(color: royal, width: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showOrders = allOrders.where((o) {
      final name = (o['medicine']?['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text("Ordered Medicines", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MainNavigation(initialIndex: 2)),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (shopDetails != null) _buildHallCard(shopDetails!),
            const SizedBox(height: 16),
            _buildSearchBar(),
            const SizedBox(height: 24),
            if (showOrders.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Text("No ordered medicines", style: TextStyle(color: royal)),
                ),
              ),
            if (showOrders.isNotEmpty)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: showOrders.length,
                    itemBuilder: (context, index) {
                      final item = showOrders[index];
                      final int id = (item['order_id'] ?? item['id']) as int;

                      allOrderSelection.putIfAbsent(id, () => false);

                      return _buildOrderCard(
                        item,
                        selected: allOrderSelection[id]!,
                        onChanged: (val) {
                          setState(() => allOrderSelection[id] = val ?? false);
                        },
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (showOrders.isNotEmpty)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SizedBox(
                    width: 150,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: royal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _showConfirmDialog,
                      child: const Text(
                        "Submit",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
