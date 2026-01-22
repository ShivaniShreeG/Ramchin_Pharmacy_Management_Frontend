import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'supplier_reorder_pdf_page.dart';
import '../../../public/main_navigation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/config.dart';

const Color royal = Color(0xFF875C3F);

class SupplierReorderDetailPage extends StatefulWidget {
  final Map<String, dynamic>? shopDetails; // ✅ ADD
  final Map<String, dynamic> supplier;
  final List medicines;

  const SupplierReorderDetailPage({
    super.key,
    required this.shopDetails, // ✅ ADD
    required this.supplier,
    required this.medicines,
  });


  @override
  State<SupplierReorderDetailPage> createState() =>
      _SupplierReorderDetailPageState();
}

class _SupplierReorderDetailPageState extends State<SupplierReorderDetailPage> {
  final Map<int, TextEditingController> qtyControllers = {};
  bool isAllQtyEntered = false; // ✅ Track if all quantities are entered
  final Set<int> selectedMedicines = {}; // medicine_id set

  @override
  void initState() {
    super.initState();

    for (var m in widget.medicines) {
      final controller = TextEditingController();
      controller.addListener(_checkAllQtyEntered); // ✅ Listen for changes
      qtyControllers[m['medicine_id']] = controller;
    }
  }

  void _submitReorder() async {
    final List<Map<String, dynamic>> items = [];

    for (var m in widget.medicines) {
      final id = m['medicine_id'];

      if (!selectedMedicines.contains(id)) continue;

      final qty = int.tryParse(qtyControllers[id]!.text) ?? 0;
      if (qty > 0) {
        items.add({
          "medicine_id": id,
          "quantity": qty,
        });
      }
    }

    if (items.isEmpty) return;

    // 🔔 CONFIRMATION DIALOG
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: Border.all(color: royal),
          title: const Text('Confirm Reorder'),
          content: SingleChildScrollView(
            child: Text(_buildConfirmMessage(items)),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel',style: TextStyle(color: royal),),
              onPressed: () => Navigator.pop(ctx, false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: royal),
              child: const Text('Confirm',style: TextStyle(color: Colors.white),),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // 🔥 API CALL
    final payload = {
      "supplier_id": widget.supplier['id'],
      "items": items,
    };

    final shopId = widget.shopDetails!['shop_id'];

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reorder/order/$shopId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reorder submitted successfully")),
        );

        // ✅ MOVE TO GENERATE REORDER LIST PAGE
        _goToGeneratePage(items);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  void dispose() {
    for (var c in qtyControllers.values) {
      c.removeListener(_checkAllQtyEntered);
      c.dispose();
    }
    super.dispose();
  }

  void _checkAllQtyEntered() {
    if (selectedMedicines.isEmpty) {
      setState(() => isAllQtyEntered = false);
      return;
    }

    final allEntered = selectedMedicines.every((id) {
      final text = qtyControllers[id]?.text ?? '';
      final qty = int.tryParse(text) ?? 0;
      return qty > 0;
    });

    if (allEntered != isAllQtyEntered) {
      setState(() => isAllQtyEntered = allEntered);
    }
  }

  String _buildConfirmMessage(List<Map<String, dynamic>> items) {
    final buffer = StringBuffer();

    buffer.writeln(
      'Do you want to order the following medicines from ${widget.supplier['name']}?\n',
    );

    for (final item in items) {
      final medicine = widget.medicines.firstWhere(
            (m) => m['medicine_id'] == item['medicine_id'],
      );

      buffer.writeln(
        '• ${medicine['medicine_name']}  ×  ${item['quantity']}',
      );
    }

    return buffer.toString();
  }

  Future<void> _goToGeneratePage(List<Map<String, dynamic>> items) async {
    final List<Map<String, dynamic>> finalList = [];

    for (final item in items) {
      final medicine = widget.medicines.firstWhere(
            (m) => m['medicine_id'] == item['medicine_id'],
      );

      finalList.add({
        ...medicine,
        'required_qty': item['quantity'],
      });
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupplierReorderPdfPage(
          shopDetails: widget.shopDetails,
          supplier: widget.supplier,
          medicines: finalList,
        ),
      ),
    );

    Navigator.pop(context, result); // 🔥 passes true back

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title:  Text(widget.supplier['name'], style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MainNavigation(initialIndex: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 600, // constrain the width
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...widget.medicines.map((m) {
                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: royal),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: selectedMedicines.contains(m['medicine_id']),
                                activeColor: royal,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      selectedMedicines.add(m['medicine_id']);
                                    } else {
                                      selectedMedicines.remove(m['medicine_id']);
                                    }
                                    _checkAllQtyEntered();
                                  });
                                },
                              ),
                              Expanded(
                                child: Text(
                                  m['medicine_name'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: royal,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text("Current Stock: ${m['current_stock']}"),
                          Text("Reorder Level: ${m['reorder_level']}"),
                          const SizedBox(height: 10),
                          if (selectedMedicines.contains(m['medicine_id']))
                            TextField(
                              controller: qtyControllers[m['medicine_id']],
                              cursorColor: royal,
                              style: TextStyle(color: royal),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly, // ✅ ONLY DIGITS
                              ],
                              decoration: InputDecoration(
                                labelText: "Required Quantity",
                                labelStyle: TextStyle(color: royal),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: royal, width: 1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: royal, width: 2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: royal.withValues(alpha: 0.05),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                ElevatedButton(
                  child:  Text("Submit Reorder"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: royal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: isAllQtyEntered ? _submitReorder : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

