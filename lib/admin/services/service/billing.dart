import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/config.dart';
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
  final FocusNode medicineFocus = FocusNode();
  final FocusNode qtyFocus = FocusNode();
  int highlightedIndex = -1;
  final FocusNode suggestionFocus = FocusNode();
  final FocusNode phoneFocus = FocusNode();
  final FocusNode customerFocus = FocusNode();
  final FocusNode doctorFocus = FocusNode();
  final FocusNode paymentFocus = FocusNode();
  final FocusNode submitFocus = FocusNode();
  bool isSubmitFocused = false;
  int customerHighlightIndex = -1;
  final FocusNode customerSuggestionFocus = FocusNode();

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
  bool isResettingForm = false;

  String? userId;
  int getUsedQty(int medicineId, int batchId) {
    return billItems
        .where((i) =>
    i['medicine_id'] == medicineId &&
        i['batch_id'] == batchId)
        .fold<int>(0, (sum, i) => sum + (i['quantity'] as int));
  }

  @override
  void initState() {
    super.initState();
    loadShopId();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      phoneFocus.requestFocus(); // 🔥 start here
    });
  }

  @override
  void dispose() {
    medicineFocus.dispose();
    qtyFocus.dispose();
    phoneFocus.dispose();
    customerFocus.dispose();
    doctorFocus.dispose();
    submitFocus.dispose();
    super.dispose();
  }

  void clearBillingForm() {
    isResettingForm = true; // 🔒 BLOCK AUTO-FILL

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
    paymentMode = 'CASH';

    customerSuggestions.clear();
    customerBills.clear();
    showCustomerDropdown = false;
    isFetchingCustomers = false;

    setState(() {});

    // 🔓 RELEASE AFTER FRAME
    WidgetsBinding.instance.addPostFrameCallback((_) {
      isResettingForm = false;
    });
  }

  bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 700;
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
      final List data = jsonDecode(res.body);

      setState(() {
        medicineSuggestions = data.map<Map<String, dynamic>>((med) {
          final List batches = med['batches'];

          final adjustedBatches = batches.map<Map<String, dynamic>>((b) {
            final int usedQty =
            getUsedQty(med['id'], b['id']); // 🔥 KEY LINE

            final int available =
                (b['available_qty'] as int) - usedQty;

            return {
              ...b,
              'available_qty': available < 0 ? 0 : available,
            };
          }).where((b) => b['available_qty'] > 0).toList();

          return {
            'id': med['id'],
            'name': med['name'],
            'batches': adjustedBatches,
          };
        }).where((m) => (m['batches'] as List).isNotEmpty).toList();
      });
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
    double toTwoDecimals(num value) {
      return double.parse(value.toStringAsFixed(2));
    }

    final body = {
      "shop_id": shopId,
      "user_id": userId,
      "customer_name": customerCtrl.text,
      "phone": phoneCtrl.text,
      "doctor_name": doctorCtrl.text.isEmpty ? null : doctorCtrl.text,
      "total": toTwoDecimals(billTotal),
      "payment_mode": paymentMode,
      "items": billItems.map((e) => {
        "medicine_id": e['medicine_id'],
        "medicine_name":e['medicine_name'],
        "batch_id": e['batch_id'],
        "quantity": e['quantity'],
        "unit_price": toTwoDecimals(e['unit_price']),
        "total_price":toTwoDecimals( e['total_price']),
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
        FocusScope.of(context).requestFocus(phoneFocus);

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
      _showMessage("Select medicine and enter quantity");
      return;
    }


    int remainingQty = int.parse(qtyCtrl.text);

    for (final batch in selectedBatches) {
      if (remainingQty <= 0) break;

      int availableQty = batch['available_qty'];
      if (availableQty <= 0) continue;

      final int usedQty =
      remainingQty > availableQty ? availableQty : remainingQty;

      final double unitPrice =
      (batch['selling_price'] as num).toDouble();

      final existingIndex = billItems.indexWhere((item) =>
      item['medicine_id'] == selectedMedicine!['id'] &&
          item['batch_id'] == batch['id']);

      if (existingIndex != -1) {
        billItems[existingIndex]['quantity'] += usedQty;
        billItems[existingIndex]['total_price'] =
            billItems[existingIndex]['quantity'] * unitPrice;
      } else {
        billItems.add({
          "medicine_id": selectedMedicine!['id'],
          "medicine_name": selectedMedicine!['name'],
          "batch_id": batch['id'],
          "batch_no": batch['batch_no'],
          "rack_no": batch['rack_no'],
          "quantity": usedQty,
          "unit_price": unitPrice,
          "total_price": usedQty * unitPrice,
        });
      }

      // 🔥 CRITICAL FIX
      batch['available_qty'] -= usedQty;
      remainingQty -= usedQty;
    }

    if (remainingQty > 0) {
      _showMessage("Insufficient stock across all batches");
    }

    // ❌ REMOVE EMPTY BATCHES FROM UI
    selectedBatches.removeWhere((b) => b['available_qty'] <= 0);

    medicineCtrl.clear();
    selectedMedicine=null;
    qtyCtrl.clear();
    previewItemTotal = 0;
    FocusScope.of(context).requestFocus(medicineFocus);

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

  void _selectMedicine(Map<String, dynamic> med) {
    selectedMedicine = med;
    medicineCtrl.text = med['name'];
    medicineSuggestions.clear();
    highlightedIndex = -1;

    selectedBatches = (med['batches'] as List<dynamic>)
        .where((b) =>
    (b as Map<String, dynamic>)['available_qty'] != null &&
        ((b as Map<String, dynamic>)['available_qty'] as int) > 0)
        .map((b) => b as Map<String, dynamic>)
        .toList();

    if (selectedBatches.isEmpty) {
      _showMessage("No stock available");
      return;
    }

    setState(() {});
    FocusScope.of(context).unfocus(); // release RawKeyboardListener
    Future.microtask(() {
      FocusScope.of(context).requestFocus(qtyFocus);
    });
  }

  void _selectCustomer(Map<String, dynamic> customer) {
    customerCtrl.text = customer['customer_name'];

    showCustomerDropdown = false;
    customerSuggestions.clear();
    customerHighlightIndex = -1;

    setState(() {});

    /// 🔁 Move focus next
    FocusScope.of(context).requestFocus(doctorFocus);
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

              if (isDesktop(context))
                Column(
                  children: [
                       Column(
                        children: [
                          _sectionCard(
                            title: "Billing Details",
                            child: Column(
                              children: [

                                Row(
                                  children: [
                                    Expanded(
                                      child: labeledField(
                                        label: "Phone",
                                        field: TextFormField(
                                          controller: phoneCtrl,
                                          cursorColor: royal,
                                          focusNode: phoneFocus,
                                          textInputAction: TextInputAction.next,
                                          onFieldSubmitted: (_) {
                                            FocusScope.of(context).requestFocus(customerFocus);
                                          },
                                          style: TextStyle(color: royal),
                                          keyboardType: TextInputType.phone,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                            LengthLimitingTextInputFormatter(10),
                                          ],
                                          decoration: _inputDecoration("Phone number"),
                                          onChanged: (val) {
                                            if (isResettingForm) return;

                                            if (val.length != 10) {
                                              customerSuggestions.clear();
                                              customerBills.clear();
                                              showCustomerDropdown = false;
                                              customerCtrl.clear();
                                              setState(() {});
                                              return;
                                            }

                                            fetchCustomersByPhone(val);
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: labeledField(
                                        label: "Customer Name",
                                        field: RawKeyboardListener(
                                          focusNode: customerSuggestionFocus,
                                          onKey: (event) {
                                            if (!showCustomerDropdown || customerSuggestions.isEmpty) return;

                                            if (event is RawKeyDownEvent) {
                                              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                                setState(() {
                                                  customerHighlightIndex =
                                                      (customerHighlightIndex + 1) % customerSuggestions.length;
                                                });
                                              }

                                              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                                setState(() {
                                                  customerHighlightIndex =
                                                      (customerHighlightIndex - 1 + customerSuggestions.length) %
                                                          customerSuggestions.length;
                                                });
                                              }

                                              if (event.logicalKey == LogicalKeyboardKey.enter &&
                                                  customerHighlightIndex >= 0) {
                                                _selectCustomer(customerSuggestions[customerHighlightIndex]);
                                              }
                                            }
                                          },
                                          child: TextFormField(
                                            controller: customerCtrl,
                                            focusNode: customerFocus,
                                            textInputAction: TextInputAction.next,
                                            cursorColor: royal,
                                            style: const TextStyle(color: royal),
                                            decoration: _inputDecoration("Customer name"),
                                            onChanged: (val) {
                                              customerHighlightIndex = -1;
                                            },
                                            onFieldSubmitted: (_) {
                                              FocusScope.of(context).requestFocus(doctorFocus);
                                            },
                                          ),
                                        ),
                                      ),

                                    ),
                                  ],
                                ),

                                if (showCustomerDropdown)
                                  ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: customerSuggestions.length,
                                    itemBuilder: (_, i) {
                                      final c = customerSuggestions[i];
                                      final bool isHighlighted = i == customerHighlightIndex;

                                      return InkWell(
                                        onTap: () => _selectCustomer(c),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isHighlighted
                                                ? royal.withValues(alpha: 0.15)
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                c['customer_name'],
                                                style: const TextStyle(
                                                  color: royal,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                "Last visit: ${c['last_bill_date'].toString().substring(0, 10)}",
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                const SizedBox(height: 16),

                                Row(
                                  children: [
                                    Expanded(
                                      child: labeledField(
                                        label: "Doctor",
                                        field: TextFormField(
                                          controller: doctorCtrl,
                                          cursorColor: royal,
                                          focusNode: doctorFocus,
                                          textInputAction: TextInputAction.next,
                                          onFieldSubmitted: (_) {
                                            FocusScope.of(context).requestFocus(medicineFocus);
                                          },
                                          style: TextStyle(color: royal),
                                          decoration: _inputDecoration("Doctor name"),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Align(
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
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          _sectionCard(
                            title: "Bill Items",
                            child: Column(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    /// 🔹 Medicine + Quantity in same row
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: labeledField(
                                            label: "Medicine",
                                            field: RawKeyboardListener(
                                              focusNode: suggestionFocus,
                                              onKey: (event) {
                                                if (medicineSuggestions.isEmpty) return;

                                                if (event is RawKeyDownEvent) {
                                                  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                                    setState(() {
                                                      highlightedIndex =
                                                          (highlightedIndex + 1) % medicineSuggestions.length;
                                                    });
                                                  }

                                                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                                    setState(() {
                                                      highlightedIndex =
                                                          (highlightedIndex - 1 + medicineSuggestions.length) %
                                                              medicineSuggestions.length;
                                                    });
                                                  }

                                                  if (event.logicalKey == LogicalKeyboardKey.enter &&
                                                      highlightedIndex >= 0) {
                                                    _selectMedicine(medicineSuggestions[highlightedIndex]);
                                                  }
                                                }
                                              },
                                              child: TextFormField(
                                                controller: medicineCtrl,
                                                focusNode: medicineFocus,
                                                cursorColor: royal,
                                                style: TextStyle(color: royal),
                                                onChanged: (val) {
                                                  highlightedIndex = -1;
                                                  fetchMedicines(val);
                                                },
                                                decoration: _inputDecoration("Search medicine"),
                                              ),
                                            ),

                                          ),
                                        ),

                                        const SizedBox(width: 16),
                                        Expanded(
                                          flex: 2,
                                          child: labeledField(
                                            label: "Quantity",
                                            field:TextFormField(
                                              controller: qtyCtrl,
                                              focusNode: qtyFocus,
                                              cursorColor: royal,
                                              style: const TextStyle(color: royal),
                                              keyboardType: TextInputType.number,
                                              textInputAction: TextInputAction.done,
                                              decoration: _inputDecoration("Qty"),

                                              onChanged: (val) {
                                                if (selectedMedicine == null) {
                                                  previewItemTotal = 0;
                                                  setState(() {});
                                                  return;
                                                }

                                                final enteredQty = int.tryParse(val) ?? 0;
                                                if (selectedBatches.isEmpty) return;

                                                final totalAvailable = selectedBatches.fold<int>(
                                                  0,
                                                      (sum, b) => sum + (b['available_qty'] as int),
                                                );

                                                if (enteredQty > totalAvailable) {
                                                  qtyCtrl.text = totalAvailable.toString();
                                                  qtyCtrl.selection = TextSelection.fromPosition(
                                                    TextPosition(offset: qtyCtrl.text.length),
                                                  );

                                                  _showMessage("Only $totalAvailable units available");
                                                  calculateFromQuantity(totalAvailable);
                                                  return;
                                                }

                                                calculateFromQuantity(enteredQty);
                                              },

                                              /// 🔥 ENTER KEY HANDLER
                                              onFieldSubmitted: (_) {
                                                if (selectedMedicine == null || qtyCtrl.text.isEmpty) return;

                                                addMedicineItem();

                                                /// Clear quantity + medicine if needed
                                                qtyCtrl.clear();
                                                medicineCtrl.clear();
                                                selectedMedicine = null;
                                                selectedBatches.clear();
                                                previewItemTotal = 0;

                                                setState(() {});

                                                /// 🔁 MOVE FOCUS BACK TO MEDICINE
                                                FocusScope.of(context).requestFocus(medicineFocus);
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    /// 🔹 Suggestions (BELOW medicine field)

                                  ],
                                ),
                                if (medicineSuggestions.isNotEmpty)
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: medicineSuggestions.length,
                                      itemBuilder: (_, i) {
                                        final med = medicineSuggestions[i];
                                        final batches = med['batches'] as List<dynamic>;
                                        final bool isHighlighted = i == highlightedIndex;

                                        return InkWell(
                                          onTap: () {
                                            selectedMedicine = med;
                                            medicineCtrl.text = med['name'];
                                            medicineSuggestions.clear();

                                            // ✅ Set available batches
                                            selectedBatches = List<Map<String, dynamic>>.from(
                                              batches.where((b) => b['available_qty'] > 0),
                                            );

                                            if (selectedBatches.isEmpty) {
                                              _showMessage("No stock available for this medicine");
                                              return;
                                            }

                                            setState(() {});

                                            // 🔹 Move focus to Quantity field
                                            FocusScope.of(context).requestFocus(qtyFocus);
                                          },

                                              child: Container(
                                            margin: const EdgeInsets.symmetric(vertical: 6),
                                            padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                              color: isHighlighted
                                              ? royal.withValues(alpha: 0.15)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: royal),
                                        ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  med['name'],
                                                  style: const TextStyle(
                                                    color: royal,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                ...batches.map(
                                                      (b) => Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text("Batch: ${b['batch_no']}", style: const TextStyle(fontSize: 13)),
                                                      Text(
                                                        "Stock: ${b['available_qty']}",
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w600,
                                                          color: b['available_qty'] > 0 ? Colors.green : Colors.red,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
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
                                const SizedBox(height: 10),

                                SizedBox(
                                  width: 200,
                                  height: 40,
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
                                        Expanded(flex: 2, child: Text("Batch", style: _headerStyle)),
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
                                        child:Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                item['medicine_name'],
                                                style: const TextStyle(color: royal),
                                              ),
                                            ),

                                            /// 👇 Batch & Rack (REFERENCE ONLY)
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text("Batch: ${item['batch_no']}", style: const TextStyle(fontSize: 12)),
                                                  Text("Rack: ${item['rack_no']}", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                                ],
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
                                                "₹${item['unit_price'].toStringAsFixed(2)}",
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                "₹${item['total_price'].toStringAsFixed(2)}",
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red),
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


                                const SizedBox(height: 10),
                                const Divider(thickness:0.5,color: royal),

                                /// TOTAL
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    /// 🔹 LEFT: Payment Mode
                                    Expanded(
                                      flex: 1,
                                      child: labeledField(
                                        label: "Payment",
                                        field: DropdownButtonFormField<String>(
                                          initialValue: paymentMode,
                                          focusNode: paymentFocus, // 🔥 REQUIRED
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
                                          items: ["CASH", "ONLINE"]
                                              .map(
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
                                          )
                                              .toList(),
                                          onChanged: (v) => setState(() => paymentMode = v!),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 3,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              "Grand Total : ₹${billTotal.toStringAsFixed(2)}",
                                              style: TextStyle(
                                                color: royal,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),


                              ],
                            ),
                          ),

                          const SizedBox(height: 30),
                          Focus(
                            focusNode: submitFocus,
                            onFocusChange: (hasFocus) {
                              setState(() {
                                isSubmitFocused = hasFocus;
                              });
                            },
                            child: SizedBox(
                              width: 200,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSubmitFocused
                                      ? Colors.green   // 🔥 Focus color
                                      : royal,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: isSubmitFocused
                                        ? const BorderSide(color: Colors.green, width: 2)
                                        : BorderSide.none,
                                  ),
                                ),
                                onPressed: submitBill,
                                child: const Text(
                                  "Submit",
                                  style: TextStyle(fontSize: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                    ),
                  ],
                ),

              if (!isDesktop(context))
                Column(
                  children: [
                    Center(
            child: Column(
              children: [

                _sectionCard(
                  title: "Bill Items",
                  child: Column(
                    children: [
                      labeledField(
                        label: "Medicine",
                        field: TextFormField(
                          controller: medicineCtrl,
                          cursorColor: royal,
                          focusNode: medicineFocus,
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
                              selectedBatches = List<Map<String, dynamic>>.from(
                                batches.where((b) => b['available_qty'] > 0),
                              );

                              if (selectedBatches.isEmpty) {
                                _showMessage("No stock available for this medicine");
                                return;
                              }


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
                            if (selectedMedicine == null) {
                              previewItemTotal = 0;
                              setState(() {});
                              return;
                            }

                            final enteredQty = int.tryParse(val) ?? 0;

                            if (selectedBatches.isEmpty) return;

                            final int totalAvailable = selectedBatches.fold<int>(
                              0,
                                  (sum, b) => sum + (b['available_qty'] as int),
                            );

                            if (enteredQty > totalAvailable) {
                              qtyCtrl.text = totalAvailable.toString();
                              qtyCtrl.selection = TextSelection.fromPosition(
                                TextPosition(offset: qtyCtrl.text.length),
                              );

                              _showMessage("Only $totalAvailable units available");
                              calculateFromQuantity(totalAvailable);
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
                              Expanded(flex: 2, child: Text("Batch", style: _headerStyle)),
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
                              child:Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      item['medicine_name'],
                                      style: const TextStyle(color: royal),
                                    ),
                                  ),

                                  /// 👇 Batch & Rack (REFERENCE ONLY)
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Batch: ${item['batch_no']}", style: const TextStyle(fontSize: 12)),
                                        Text("Rack: ${item['rack_no']}", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                      ],
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
                                      "₹${item['unit_price'].toStringAsFixed(2)}",
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "₹${item['total_price'].toStringAsFixed(2)}",
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
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
                            if (isResettingForm) return; // ✅ KEY LINE

                            if (val.length != 10) {
                              customerSuggestions.clear();
                              customerBills.clear();
                              showCustomerDropdown = false;
                              customerCtrl.clear(); // ✅ ALSO CLEAR NAME

                              setState(() {});
                              return;
                            }

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
                                  customerSuggestions.clear(); // ✅ clear list

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
],
        ),

      ],
          ),
        ),
      ),
    );
  }
}
