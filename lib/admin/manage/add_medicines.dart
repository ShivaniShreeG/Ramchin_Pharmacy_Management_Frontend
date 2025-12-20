import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../public/config.dart';

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

  bool showAddMedicine = false;
  bool showAddBatch = false;

  Map<String, dynamic>? selectedMedicine;

  @override
  void initState() {
    super.initState();
    loadShopId();
  }

  Future loadShopId() async {
    final prefs = await SharedPreferences.getInstance();
    shopId = prefs.getInt('shopId');
    if (shopId != null) fetchMedicines();
    setState(() {});
  }

  Future fetchMedicines() async {
    final res = await http.get(
      Uri.parse("$baseUrl/inventory/medicine/shop/$shopId"),
    );

    final List data = jsonDecode(res.body);

    medicines = data.map<Map<String, dynamic>>(
          (e) => Map<String, dynamic>.from(e),
    ).toList();

    setState(() {});
  }

  Widget actionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                showAddMedicine = !showAddMedicine;
                showAddBatch = false;
              });
            },
            child: Text(showAddMedicine ? "Close Medicine Form" : "Add Medicine"),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                showAddBatch = !showAddBatch;
                showAddMedicine = false;
              });
            },
            child: Text(showAddBatch ? "Close Batch Form" : "Add Batch"),
          ),
        ),
      ],
    );
  }

  Widget medicineCard(Map<String, dynamic> m)
  {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Text(m['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Stock: ${m['stock']}"),
      ),
    );
  }
  final medicineCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final unitCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final profitCtrl = TextEditingController();
  final expiryCtrl = TextEditingController();
  final mfgCtrl = TextEditingController();

  double stock = 0, purchase = 0, sell = 0;
  Widget addMedicineForm() {
    final nameCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();

    return Card(
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Add Medicine",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Medicine Name"),
            ),

            TextField(
              controller: categoryCtrl,
              decoration: const InputDecoration(labelText: "Category"),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: () async {
                await http.post(
                  Uri.parse("$baseUrl/inventory/medicine"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "shop_id": shopId,
                    "name": nameCtrl.text,
                    "category": categoryCtrl.text,
                  }),
                );

                fetchMedicines();
                setState(() => showAddMedicine = false);
              },
              child: const Text("Save Medicine"),
            ),
          ],
        ),
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
    final suggestions = medicines.where((m) =>
        m['name'].toLowerCase().contains(medicineCtrl.text.toLowerCase())).toList();

    return Card(
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Add Batch", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            TextField(
              controller: medicineCtrl,
              decoration: InputDecoration(
                labelText: "Medicine Name",
                errorText: selectedMedicine == null && medicineCtrl.text.isNotEmpty
                    ? "Medicine not found"
                    : null,
              ),
              onChanged: (v) {
                try {
                  selectedMedicine = medicines.firstWhere(
                        (m) => m['name'].toLowerCase() == v.toLowerCase(),
                  );
                } catch (e) {
                  selectedMedicine = null;
                }
                setState(() {});
              },
            ),

            if (selectedMedicine != null)
              Card(
                color: Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    "Category: ${selectedMedicine!['category']}\n"
                        "Current Stock: ${selectedMedicine!['stock']}",
                  ),
                ),
              ),

            TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: "Quantity"), onChanged: (_) => calculate()),
            TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: "Unit"), onChanged: (_) => calculate()),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "Unit Price"), onChanged: (_) => calculate()),
            TextField(controller: profitCtrl, decoration: const InputDecoration(labelText: "Profit %"), onChanged: (_) => calculate()),

            const SizedBox(height: 8),
            Text("Stock: $stock"),
            Text("Purchase: ₹$purchase"),
            Text("Selling: ₹$sell"),

            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: selectedMedicine == null ? null : confirmBatch,
              child: const Text("Review & Confirm"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> confirmBatch() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Batch"),
        content: Text(
          "Medicine: ${selectedMedicine!['name']}\n"
              "Stock: $stock\n"
              "Purchase: ₹$purchase\n"
              "Selling: ₹$sell",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirm")),
        ],
      ),
    );

    if (ok == true) submitBatch();
  }

  Future submitBatch() async {
    await http.post(
      Uri.parse("$baseUrl/inventory/medicine/${selectedMedicine!['id']}/batch"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "shop_id": shopId,
        "batch_no": "AUTO",
        "quantity": qtyCtrl.text,
        "unit": unitCtrl.text,
        "unit_price": priceCtrl.text,
        "purchase_price": purchase,
        "selling_price": sell,
        "stock_quantity": stock.toInt(),
        "seller_name": "Supplier",
        "seller_phone": "9999999999",
        "reason": "Add Batch"
      }),
    );

    fetchMedicines();
    setState(() {
      showAddBatch = false;
      selectedMedicine = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (shopId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Inventory"), backgroundColor: royal),
      body: SingleChildScrollView(
        child:
        Column(
          children: [
            Padding(padding: const EdgeInsets.all(8), child: actionButtons()),

            if (showAddMedicine) addMedicineForm(),
            if (showAddBatch) addBatchForm(),

            const Divider(),

            if (medicines.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text("No medicines found"),
              ),

            ...medicines.map(medicineCard).toList(),
          ],
        ),

      ),
    );
  }
}
