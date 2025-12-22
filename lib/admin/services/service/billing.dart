import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../public/config.dart';
import '../../../../public/main_navigation.dart';
import 'package:flutter/services.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  int? shopId;
  bool isLoading = true;
  Map<String, dynamic>? shopDetails;
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> billItems = [];

  final TextEditingController customerCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController doctorCtrl = TextEditingController();
  final TextEditingController medicineCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController();

  String paymentMode = "CASH";

  List<Map<String, dynamic>> medicineSuggestions = [];
  Map<String, dynamic>? selectedMedicine;
  List<Map<String, dynamic>> selectedBatches = [];

  double billTotal = 0;

  String? userId;

  @override
  void initState() {
    super.initState();
    loadShopId();
  }

  Future loadShopId() async {
    final prefs = await SharedPreferences.getInstance();
    shopId = prefs.getInt('shopId');
    userId = prefs.getString('userId');

    await _fetchHallDetails();

    setState(() {
      isLoading = false; // ✅ STOP LOADING
    });
  }

  Future<void> fetchMedicines(String query) async {
    if (query.isEmpty) return;

    final res = await http.get(
      Uri.parse("$baseUrl/medicines/search?shop_id=$shopId&query=$query"),
    );

    if (res.statusCode == 200) {
      setState(() {
        medicineSuggestions = List<Map<String, dynamic>>.from(jsonDecode(res.body));
      });
    }
  }

  Future<void> fetchBatches(int medicineId) async {
    final res = await http.get(
      Uri.parse("$baseUrl/medicine-batches/available/$medicineId"),
    );

    if (res.statusCode == 200) {
      selectedBatches = List<Map<String, dynamic>>.from(jsonDecode(res.body));
    }
  }

  Widget labeledField({
    required String label,
    required Widget field,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110, // 👈 FIXED LABEL WIDTH (adjust if needed)
            child: Text(
              label,
              style: const TextStyle(
                color: royal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: field),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: royal.withValues(alpha: 0.8)),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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

  void calculateFromQuantity(int requestedQty) {
    int remainingQty = requestedQty;
    billTotal = 0;

    for (final batch in selectedBatches) {
      if (remainingQty <= 0) break;

      int batchAvailableQty =
      (batch['total_stock'] / batch['unit']).floor();

      int usedQty = remainingQty > batchAvailableQty
          ? batchAvailableQty
          : remainingQty;

      billTotal += usedQty * batch['selling_price'];

      remainingQty -= usedQty;
    }

    if (remainingQty > 0) {
      _showMessage("Insufficient stock across batches");
    }

    setState(() {});
  }

  Future<void> submitBill() async {
    if (!_formKey.currentState!.validate()) return;

    final items = <Map<String, dynamic>>[];
    int remainingQty = int.parse(qtyCtrl.text);

    for (final batch in selectedBatches) {
      if (remainingQty <= 0) break;

      int availableQty = (batch['total_stock'] / batch['unit']).floor();
      int usedQty = remainingQty > availableQty ? availableQty : remainingQty;

      items.add({
        "medicine_id": selectedMedicine!['id'],
        "batch_id": batch['id'],
        "quantity": usedQty,
        "unit_price": batch['selling_price'],
        "total_price": usedQty * batch['selling_price'],
      });

      remainingQty -= usedQty;
    }

    final body = {
      "shop_id": shopId,
      "user_id": userId,
      "customer_name": customerCtrl.text,
      "phone": phoneCtrl.text,
      "doctor_name": doctorCtrl.text.isEmpty ? null : doctorCtrl.text,
      "total": billTotal,
      "payment_mode": paymentMode,
      "items": billItems.map((e) => {
        "medicine_id": e['medicine_id'],
        "batch_id": e['batch_id'],
        "quantity": e['quantity'],
        "unit_price": e['unit_price'],
        "total_price": e['total_price'],
      }).toList(),
    };

    await http.post(
      Uri.parse("$baseUrl/billing"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    _showMessage("Bill created successfully");
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

  void addMedicineItem() {
    if (selectedMedicine == null || qtyCtrl.text.isEmpty) {
      _showMessage("Select medicine and quantity");
      return;
    }

    int remainingQty = int.parse(qtyCtrl.text);

    for (final batch in selectedBatches) {
      if (remainingQty <= 0) break;

      int availableQty = (batch['total_stock'] / batch['unit']).floor();
      int usedQty = remainingQty > availableQty ? availableQty : remainingQty;

      final itemTotal = usedQty * batch['selling_price'];

      billItems.add({
        "medicine_id": selectedMedicine!['id'],
        "medicine_name": selectedMedicine!['name'],
        "batch_id": batch['id'],
        "quantity": usedQty,
        "unit_price": batch['selling_price'],
        "total_price": itemTotal,
      });

      remainingQty -= usedQty;
    }

    if (remainingQty > 0) {
      _showMessage("Insufficient stock");
      return;
    }

    /// reset inputs
    medicineCtrl.clear();
    qtyCtrl.clear();
    selectedMedicine = null;
    selectedBatches.clear();

    calculateBillTotal();

    setState(() {});
  }

  void calculateBillTotal() {
    billTotal = 0;
    for (final item in billItems) {
      billTotal += item['total_price'];
    }
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: royal.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: royal.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: royal,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(thickness: 1,color: royal,),
          child,
        ],
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
          "Billing",
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
        Form(
          key: _formKey,
          child: Column(
            children: [

              if (shopDetails != null) _buildHallCard(shopDetails!),

              const SizedBox(height: 16),

              _sectionCard(
                title: "Billing Details",
                child: Column(
                  children: [
                    labeledField(
                      label: "Customer",
                      field: TextFormField(
                        controller: customerCtrl,
                        style: TextStyle(color: royal),
                        cursorColor: royal,
                        decoration: _inputDecoration("Customer name"),
                        validator: (v) =>
                        v == null || v.isEmpty ? "Required" : null,
                      ),
                    ),
                    labeledField(
                      label: "Phone",
                      field: TextFormField(
                        controller: phoneCtrl,
                        cursorColor: royal,
                        style: TextStyle(color: royal),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly, // Only digits allowed
                          LengthLimitingTextInputFormatter(10),   // Max 10 digits
                        ],
                        decoration: _inputDecoration("Phone number"),
                      ),
                    ),
                    labeledField(
                      label: "Doctor",
                      field: TextFormField(
                        controller: doctorCtrl,
                        cursorColor: royal,
                        style: TextStyle(color: royal),
                        decoration: _inputDecoration("Doctor name"),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              /// 💊 BILL ITEMS STACK
              _sectionCard(
                title: "Bill Items",
                child: Column(
                  children: [
                    labeledField(
                      label: "Medicine",
                      field: TextFormField(
                        controller: medicineCtrl,
                        decoration: _inputDecoration("Search medicine"),
                        onChanged: fetchMedicines,
                      ),
                    ),

                    /// Suggestions
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: medicineSuggestions.length,
                      itemBuilder: (_, i) {
                        final med = medicineSuggestions[i];
                        return ListTile(
                          dense: true,
                          title: Text(med['name']),
                          onTap: () async {
                            selectedMedicine = med;
                            medicineCtrl.text = med['name'];
                            medicineSuggestions.clear();
                            await fetchBatches(med['id']);
                            setState(() {});
                          },
                        );
                      },
                    ),

                    labeledField(
                      label: "Quantity",
                      field: TextFormField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration("Qty"),
                        onChanged: (val) {
                          final q = int.tryParse(val) ?? 0;
                          calculateFromQuantity(q);
                        },
                      ),
                    ),
                    if (billItems.isNotEmpty)
                      Column(
                        children: billItems.map((item) {
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              title: Text(
                                item['medicine_name'],
                                style: const TextStyle(
                                  color: royal,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                "Qty: ${item['quantity']}  ×  ₹${item['unit_price']}",
                              ),
                              trailing: Text(
                                "₹ ${item['total_price']}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add, color: royal),
                        label: const Text(
                          "Add Item",
                          style: TextStyle(color: royal),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: royal),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: addMedicineItem,
                      ),
                    ),

                    const SizedBox(height: 10),

                    /// TOTAL
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Total",
                          style: TextStyle(
                            color: royal,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "₹ ${billTotal.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    /// PAYMENT MODE
                    labeledField(
                      label: "Payment",
                      field: DropdownButtonFormField<String>(
                        initialValue: paymentMode,
                        decoration: _inputDecoration("Payment mode"),
                        dropdownColor: Colors.white,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: royal,
                        ),
                        style: const TextStyle(
                          color: royal,
                          fontWeight: FontWeight.w600,
                        ),
                        items: ["CASH", "ONLINE"].map(
                              (e) => DropdownMenuItem<String>(
                            value: e,
                            child: Text(
                              e,
                              style: const TextStyle(
                                color: royal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ).toList(),
                        onChanged: (v) => setState(() => paymentMode = v!),
                      ),
                    ),

                  ],
                ),
              ),

              const SizedBox(height: 30),

              /// ✅ SUBMIT BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: royal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: submitBill,
                  child: const Text(
                    "Create Bill",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),

      ),
    );
  }
}
