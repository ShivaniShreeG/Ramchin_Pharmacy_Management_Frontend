import 'package:flutter/material.dart';
import 'supplier_reorder_pdf_page.dart';
import '../../../public/main_navigation.dart';

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

  void _generatePdf() {
    final List<Map<String, dynamic>> finalList = [];

    for (var m in widget.medicines) {
      final id = m['medicine_id'];
      if (!selectedMedicines.contains(id)) continue;

      final qty = int.tryParse(qtyControllers[id]!.text) ?? 0;
      if (qty > 0) {
        finalList.add({...m, 'required_qty': qty});
      }
    }

    if (finalList.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupplierReorderPdfPage(
          shopDetails: widget.shopDetails,
          supplier: widget.supplier,
          medicines: finalList,
        ),
      ),
    );
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

                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text("Generate List"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: royal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: isAllQtyEntered ? _generatePdf : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

