import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../public/config.dart';
import '../../../../public/main_navigation.dart';
import 'package:flutter/services.dart';
import 'bill_pdf_page.dart';
import 'package:intl/intl.dart';

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
  List<Map<String, dynamic>> customerSuggestions = [];
  List<Map<String, dynamic>> customerBills = [];
  bool showCustomerDropdown = false;
  bool isFetchingCustomers = false;

  final TextEditingController customerCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController doctorCtrl = TextEditingController();
  final TextEditingController medicineCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController();

  String paymentMode = "CASH";

  List<Map<String, dynamic>> medicineSuggestions = [];
  Map<String, dynamic>? selectedMedicine;
  List<Map<String, dynamic>> selectedBatches = [];

  double previewItemTotal = 0; // qty × price (live preview)
  double billTotal = 0;        // sum of added items ONLY

  String? userId;

  @override
  void initState() {
    super.initState();
    loadShopId();
  }

  void clearBillingForm() {
    _formKey.currentState?.reset();

    customerCtrl.clear();
    phoneCtrl.clear();
    doctorCtrl.clear();
    medicineCtrl.clear();
    qtyCtrl.clear();

    billItems.clear();
    medicineSuggestions.clear();
    selectedBatches.clear();

    selectedMedicine = null;
    previewItemTotal = 0;
    billTotal = 0;
    paymentMode = "CASH";

    setState(() {});
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
      Uri.parse("$baseUrl/medicine/search?shop_id=$shopId&query=$query"),
    );

    if (res.statusCode == 200) {
      setState(() {
        medicineSuggestions =
        List<Map<String, dynamic>>.from(jsonDecode(res.body));
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

  static const TextStyle _headerStyle = TextStyle(
    color: royal,
    fontWeight: FontWeight.bold,
  );

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

  Future<void> fetchCustomersByPhone(String phone) async {
    if (phone.length != 10) return;

    setState(() {
      isFetchingCustomers = true;
    });

    final res = await http.get(
      Uri.parse(
        "$baseUrl/billing/customers/by-phone/$shopId?phone=$phone",
      ),
    );

    if (res.statusCode == 200) {
      customerSuggestions =
      List<Map<String, dynamic>>.from(jsonDecode(res.body));

      showCustomerDropdown = customerSuggestions.isNotEmpty;
    }

    setState(() {
      isFetchingCustomers = false;
    });
  }

  Future<void> fetchBillsByCustomer(String customerName) async {
    final res = await http.get(
      Uri.parse(
        "$baseUrl/billing/bills/by-customer/$shopId"
            "?phone=${phoneCtrl.text}&customerName=$customerName",
      ),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      customerBills = List<Map<String, dynamic>>.from(data['bills']);
    }
  }

  void _showBillsBottomSheet()
  {
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
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  /// 🔹 APP BAR
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    height: 56,
                    decoration: const BoxDecoration(
                      color: royal,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
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
                            "Previous Bills - ${customerCtrl.text}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// 🔹 BILL LIST
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: customerBills.length,
                      itemBuilder: (_, i) {
                        final bill = customerBills[i];
                        final DateTime billDate = DateTime.parse(bill['bill_date']);
                        final String formattedDate = DateFormat('dd MMM yyyy').format(billDate);

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: royal, width: 1), // ✅ ROYAL BORDER
                          ),
                          color: Colors.white, // ✅ WHITE BACKGROUND
                          child: ExpansionTile(
                            collapsedIconColor: royal,
                            iconColor: royal,
                            textColor: royal,
                            collapsedTextColor: royal,
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            title: Text(
                              "Bill #${bill['bill_id']}   ₹${bill['total']}",
                              style: const TextStyle(
                                color: royal,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bill['doctor_name'] == null || bill['doctor_name'].toString().trim().isEmpty
                                      ? "Self"
                                      : "Doctor: ${bill['doctor_name']}",
                                  style: const TextStyle(color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Date: $formattedDate",
                                  style:  TextStyle(
                                    color: royal.withValues(alpha: 0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),

                            children: bill['items'].map<Widget>((item)
                            {
                              final int qty = item['quantity'];
                              final double price = (item['unit_price'] as num).toDouble();
                              final double total = qty * price;
                              return ListTile(
                                dense: true,
                                title: Text(item['medicine_name']),
                                trailing: Text(
                                  "${item['quantity']} × ₹${item['unit_price']}=  ₹$total",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
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

  void calculateFromQuantity(int qty) {
    if (selectedBatches.isEmpty || qty <= 0) {
      previewItemTotal = 0;
      setState(() {});
      return;
    }

    final double sellingPrice =
    (selectedBatches.first['selling_price'] as num).toDouble();

    previewItemTotal = qty * sellingPrice;

    setState(() {});
  }

  Future<void> submitBill() async {
    if (!_formKey.currentState!.validate()) return;

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
        "medicine_name":e['medicine_name'],
        "batch_id": e['batch_id'],
        "quantity": e['quantity'],
        "unit_price": e['unit_price'],
        "total_price": e['total_price'],
      }).toList(),
    };

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/billing"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final response = jsonDecode(res.body);

        _showMessage("Bill created successfully");
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BillDetailsPage(
              item: body, // ✅ contains medicine_name
              billData: response,
              shopDetails: shopDetails,
              userId: userId,
            ),
          ),
        );
        clearBillingForm();

      } else {
        _showMessage("Failed to create bill: ${res.statusCode}");
      }
    } catch (e) {
      _showMessage("Error: $e");
    }
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

    final qty = int.parse(qtyCtrl.text);
    final batch = selectedBatches.first;
    final int availableQty = batch['available_qty'];

    if (qty > availableQty) {
      _showMessage("Quantity exceeds available stock");
      return;
    }

    final double unitPrice =
    (batch['selling_price'] as num).toDouble();

    final double total = qty * unitPrice;


    billItems.add({
      "medicine_id": selectedMedicine!['id'],
      "medicine_name": selectedMedicine!['name'],
      "batch_id": batch['id'],
      "quantity": qty,
      "unit_price": unitPrice,
      "total_price": total,
    });

    medicineCtrl.clear();
    qtyCtrl.clear();
    selectedMedicine = null;
    selectedBatches.clear();
    previewItemTotal = 0;

    calculateBillTotal();
    setState(() {});
  }

  void calculateBillTotal() {
    billTotal = 0;
    for (final item in billItems) {
      billTotal += (item['total_price'] as num).toDouble();
    }
  }

  void editBillItem(int index) {
    final TextEditingController editQtyCtrl =
    TextEditingController(text: billItems[index]['quantity'].toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Quantity",style: TextStyle(color: royal),),
        content: TextField(
          controller: editQtyCtrl,
          cursorColor: royal,
          style: TextStyle(color: royal),
          keyboardType: TextInputType.number,
          decoration: _inputDecoration("Quantity"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel",style: TextStyle(color: royal),),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: royal,foregroundColor: Colors.white),
            onPressed: () {
              final newQty = int.tryParse(editQtyCtrl.text) ?? 0;
              if (newQty <= 0) return;

              final double unitPrice =
              (billItems[index]['unit_price'] as num).toDouble();

              billItems[index]['quantity'] = newQty;
              billItems[index]['total_price'] = newQty * unitPrice;

              calculateBillTotal();
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
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
                      label: "Phone",
                      field: TextFormField(
                        controller: phoneCtrl,
                        cursorColor: royal,
                        style: TextStyle(color: royal),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: _inputDecoration("Phone number"),
                        onChanged: (val) {
                          fetchCustomersByPhone(val);
                        },
                      ),
                    ),
                    if (showCustomerDropdown)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: royal.withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: customerSuggestions.length,
                          itemBuilder: (_, i) {
                            final c = customerSuggestions[i];
                            return ListTile(
                              title: Text(
                                c['customer_name'],
                                style: const TextStyle(color: royal),
                              ),
                              subtitle: Text(
                                "Last visit: ${c['last_bill_date'].toString().substring(0, 10)}",
                                style: const TextStyle(fontSize: 12),
                              ),
                              onTap: () {
                                customerCtrl.text = c['customer_name'];
                                showCustomerDropdown = false;

                                setState(() {});
                              },
                            );
                          },
                        ),
                      ),

                    labeledField(
                      label: "Customer Name",
                      field: TextFormField(
                        controller: customerCtrl,
                        style: TextStyle(color: royal),
                        cursorColor: royal,
                        decoration: _inputDecoration("Customer name"),
                        validator: (v) =>
                        v == null || v.isEmpty ? "Required" : null,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.history, color: royal),
                        label: const Text(
                          "View Previous Bills",
                          style: TextStyle(
                            color: royal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () async {
                          if (phoneCtrl.text.length != 10 || customerCtrl.text.isEmpty) {
                            _showMessage("Enter phone number and customer name");
                            return;
                          }

                          await fetchBillsByCustomer(customerCtrl.text);

                          if (customerBills.isEmpty) {
                            _showMessage("No previous bills found");
                            return;
                          }

                          _showBillsBottomSheet();
                        },
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

              _sectionCard(
                title: "Bill Items",
                child: Column(
                  children: [
                    labeledField(
                      label: "Medicine",
                      field: TextFormField(
                        controller: medicineCtrl,
                        cursorColor: royal,
                        style: TextStyle(color: royal),
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
                        final batches = med['batches'] as List<dynamic>;

                        return InkWell(
                          onTap: () async {
                            selectedMedicine = med;
                            medicineCtrl.text = med['name'];
                            medicineSuggestions.clear();

                            /// batches already available — no need refetch
                            selectedBatches = List<Map<String, dynamic>>.from(batches);


                            setState(() {});
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: royal.withValues(alpha: 0.4)),
                              boxShadow: [
                                BoxShadow(
                                  color: royal.withValues(alpha: 0.12),
                                  blurRadius: 4,
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                /// Medicine Name
                                Text(
                                  med['name'],
                                  style: const TextStyle(
                                    color: royal,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                /// Batch Info
                                Column(
                                  children: batches.map((b) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Batch: ${b['batch_no']}",
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                          Text(
                                            "Stock: ${b['available_qty']}",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: b['available_qty'] > 0
                                                  ? Colors.green
                                                  : Colors.red,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),

                                const SizedBox(height: 4),

                                const Text(
                                  "FIFO applied automatically",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    labeledField(
                      label: "Quantity",
                      field: TextFormField(
                        controller: qtyCtrl,
                        cursorColor: royal,
                        style: TextStyle(color: royal),
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration("Qty"),
                        onChanged: (val) {
                          final enteredQty = int.tryParse(val) ?? 0;

                          if (selectedBatches.isEmpty) return;

                          final int availableQty = selectedBatches.first['available_qty'];

                          if (enteredQty > availableQty) {
                            qtyCtrl.text = availableQty.toString();
                            qtyCtrl.selection = TextSelection.fromPosition(
                              TextPosition(offset: qtyCtrl.text.length),
                            );

                            _showMessage("Only $availableQty units available in this batch");
                            calculateFromQuantity(availableQty);
                            return;
                          }

                          calculateFromQuantity(enteredQty);
                        },
                      ),
                    ),
                    if (previewItemTotal > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            "Item Total: ₹ ${previewItemTotal.toStringAsFixed(2)}",
                            style: const TextStyle(
                              color: royal,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                    if (billItems.isNotEmpty) ...[
                      const SizedBox(height: 10),

                      /// 🔹 TABLE HEADER
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: royal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Expanded(flex: 3, child: Text("Medicine", style: _headerStyle)),
                            Expanded(flex: 1, child: Text("Qty", textAlign: TextAlign.center, style: _headerStyle)),
                            Expanded(flex: 2, child: Text("Price", textAlign: TextAlign.right, style: _headerStyle)),
                            Expanded(flex: 2, child: Text("Total", textAlign: TextAlign.right, style: _headerStyle)),
                            Expanded(flex: 1, child: Text("")),
                          ],
                        ),
                      ),

                      /// 🔹 TABLE ROWS (FIXED)
                      ...billItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;

                        return InkWell(
                          onTap: () => editBillItem(index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.black12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    item['medicine_name'],
                                    style: const TextStyle(color: royal),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    item['quantity'].toString(),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    "₹${item['unit_price']}",
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    "₹${item['total_price']}",
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red,),
                                    onPressed: () {
                                      billItems.removeAt(index);
                                      calculateBillTotal();
                                      setState(() {});
                                    },
                                  ),
                                ),

                              ],
                            ),
                          ),
                        );
                      }),
                    ],

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
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: royal.withValues(alpha: 0.4), width: 1.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Grand Total",
                            style: TextStyle(
                              color: royal,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "₹ ${billTotal.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 16,
                              color: royal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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
                    "Submit",
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
