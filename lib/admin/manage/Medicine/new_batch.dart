import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../services/config.dart';
import '../../../widget/color_theme.dart';
class AddBatchForm extends StatefulWidget {
  final String shopId;
  final Function() fetchMedicines;
  final Function(bool) onClose;
  final List<Map<String, dynamic>> medicines; // ✅ Add this

  const AddBatchForm({
    super.key,
    required this.shopId,
    required this.fetchMedicines,
    required this.onClose,
    required this.medicines, // ✅ Pass it in constructor
  });

  @override
  State<AddBatchForm> createState() => _AddBatchFormState();
}

class _AddBatchFormState extends State<AddBatchForm> {

  Timer? debounce;
  bool isBatchTaken = false;
  final rackCtrl = TextEditingController();
  final quantityCtrl = TextEditingController();
  final unitCtrl = TextEditingController();
  final profitCtrl = TextEditingController();
  final sellerCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final hsnCtrl = TextEditingController();
  final mrpCtrl = TextEditingController();
  DateTime? mfgDate;
  DateTime? expDate;
  int? selectedSupplierId;     // ✅ real supplier id
  bool supplierFound = false; // ✅ for UI icon
  final freeQtyCtrl = TextEditingController();
  double totalQuantity = 0;
  double totalStock = 0; // ✅ FIX
  DateTime purchaseDate = DateTime.now(); // ✅ default today
  final ratePerQtyCtrl = TextEditingController();
  final gstCtrl = TextEditingController();
  double sellingPerUnit = 0;
  double sellingPerQuantity = 0;
  double purchasePerUnit = 0;
  double purchasePerQuantity = 0;
  double gstPerQuantity = 0;
  double baseAmount = 0;
  double totalGstAmount = 0;
  double purchasePrice = 0;
  Timer? phoneDebounce;
  int? selectedMedicineId;
  Map<String, dynamic>? selectedMedicine;
  final batchCtrl = TextEditingController();
  final medicineCtrl = TextEditingController();
  final hsnFocus = FocusNode();
  final medicineFocus = FocusNode();
  final batchFocus = FocusNode();
  final rackFocus = FocusNode();
  final qtyFocus = FocusNode();
  final freeQtyFocus = FocusNode();
  final unitFocus = FocusNode();
  final rateFocus = FocusNode();
  final gstFocus = FocusNode();
  final mrpFocus = FocusNode();
  final profitFocus = FocusNode();
  final phoneFocus = FocusNode();

  void resetForm() {
    medicineCtrl.clear();   // ✅ Clears autocomplete text
    selectedMedicine = null;
    selectedMedicineId = null;
    batchCtrl.clear();
    rackCtrl.clear();
    quantityCtrl.clear();
    freeQtyCtrl.clear();
    unitCtrl.clear();
    ratePerQtyCtrl.clear();
    gstCtrl.clear();
    mrpCtrl.clear();
    profitCtrl.clear();
    sellerCtrl.clear();
    phoneCtrl.clear();
    hsnCtrl.clear();

    mfgDate = null;
    expDate = null;
    purchaseDate = DateTime.now();

    selectedSupplierId = null;
    supplierFound = false;

    totalQuantity = 0;
    totalStock = 0;
    gstPerQuantity = 0;
    baseAmount = 0;
    totalGstAmount = 0;
    purchasePrice = 0;
    purchasePerUnit = 0;
    purchasePerQuantity = 0;
    sellingPerUnit = 0;
    sellingPerQuantity = 0;
    phoneDebounce?.cancel();
    setState(() {});
  }

  Widget medicineAutocomplete(void Function(VoidCallback fn) setState) {
    return RawAutocomplete<Map<String, dynamic>>(
      textEditingController: medicineCtrl,
      focusNode: medicineFocus,
      optionsBuilder: (TextEditingValue value) {
        if (value.text.isEmpty) return const Iterable.empty();
        return widget.medicines.where(
              (m) => m['name'].toLowerCase().contains(value.text.toLowerCase()),
        );
      },
      displayStringForOption: (m) => m['name'],
      onSelected: (m) {
        setState(() {
          selectedMedicine = m;
          selectedMedicineId = m['id'];
          medicineCtrl.text = m['name'];
          batchCtrl.clear();
          isBatchTaken = false;
          debounce?.cancel();
        });

        FocusScope.of(context).requestFocus(batchFocus);
      },
      fieldViewBuilder: (context, controller, focusNode, _) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          cursorColor: royal,
          style: const TextStyle(color: royal),
          decoration: _inputDecoration("Medicine Name"),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Material(
          elevation: 4,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, i) {
              final m = options.elementAt(i);
              return ListTile(
                title: Text(m['name']),
                subtitle: Text("Stock: ${m['stock']}"),
                onTap: () => onSelected(m),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> submitBatch() async {
    if (!isFormValid()) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => confirmBatchDialog(),
    );

    if (ok != true) return;

    double d2(double value) => double.parse(value.toStringAsFixed(2));

    final response = await http.post(
      Uri.parse("$baseUrl/inventory/medicine/$selectedMedicineId/batch"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "shop_id": widget.shopId,
        "batch_no": batchCtrl.text,
        "mfg_date": mfgDate?.toIso8601String(),
        "exp_date": expDate?.toIso8601String(),
        "rack_no": rackCtrl.text,
        "quantity": int.parse(quantityCtrl.text),
        "free_quantity": int.tryParse(freeQtyCtrl.text) ?? 0,
        "total_quantity": d2(totalQuantity),
        "unit": int.parse(unitCtrl.text),
        "total_stock": d2(totalStock),
        "mrp": d2(double.parse(mrpCtrl.text)),
        "supplier_id": selectedSupplierId,
        "hsncode": hsnCtrl.text,
        "purchase_details": {
          "purchase_date": purchaseDate.toIso8601String(),
          "rate_per_quantity": d2(double.parse(ratePerQtyCtrl.text)),
          "gst_percent": d2(double.tryParse(gstCtrl.text) ?? 0),
          "gst_per_quantity": d2(gstPerQuantity),
          "base_amount": d2(baseAmount),
          "total_gst_amount": d2(totalGstAmount),
          "purchase_price": d2(purchasePrice),
        },
        "purchase_price_per_unit": d2(purchasePerUnit),
        "purchase_price_per_quantity": d2(purchasePerQuantity),
        "selling_price_per_unit": d2(sellingPerUnit),
        "selling_price_per_quantity": d2(sellingPerQuantity),
        "profit_percent": d2(double.tryParse(profitCtrl.text) ?? 0),
        "reason": "New Batch",
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {

      resetForm();
      widget.onClose(false);
      widget.fetchMedicines();
    } else {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to submit batch. Please try again.")),
      );
    }
  }

  double truncateTo2Decimals(double value) {
    return (value * 100).truncate() / 100;
  }

  void calculatePurchaseValues() {
    final qty = double.tryParse(quantityCtrl.text) ?? 0;
    final rate = double.tryParse(ratePerQtyCtrl.text) ?? 0;
    final gstPercent = double.tryParse(gstCtrl.text) ?? 0;
    final unit = double.tryParse(unitCtrl.text) ?? 0;
    final mrp = double.tryParse(mrpCtrl.text) ?? 0;
    final profitPercent = double.tryParse(profitCtrl.text) ?? 0;

    if (qty <= 0 || unit <= 0) {
      purchasePerUnit = 0;
      purchasePerQuantity = 0;
      sellingPerUnit = 0;
      sellingPerQuantity = 0;
      setState(() {});
      return;
    }

    baseAmount = truncateTo2Decimals(qty * rate);

    // GST
    gstPerQuantity = truncateTo2Decimals(rate * gstPercent / 100);
    totalGstAmount = truncateTo2Decimals(gstPerQuantity * qty);

    // PURCHASE PRICE
    purchasePrice = truncateTo2Decimals(baseAmount + totalGstAmount);
    purchasePerQuantity = truncateTo2Decimals(purchasePrice / qty);
    purchasePerUnit = truncateTo2Decimals(purchasePerQuantity / unit);

    // Profit-based selling
    final calculatedSelling =
        purchasePerQuantity + (purchasePerQuantity * profitPercent / 100);

    // MRP CAP
    sellingPerQuantity = truncateTo2Decimals(
        calculatedSelling > mrp ? mrp : calculatedSelling);

    // Selling per unit
    sellingPerUnit = truncateTo2Decimals(sellingPerQuantity / unit);

    setState(() {});
  }

  void calculateStock() {
    final qty = double.tryParse(quantityCtrl.text) ?? 0;
    final freeQty = double.tryParse(freeQtyCtrl.text) ?? 0;
    final unit = double.tryParse(unitCtrl.text) ?? 0;

    totalQuantity = qty + freeQty;     // ✅ TOTAL QTY
    totalStock = totalQuantity * unit;      // ✅ TOTAL STOCK

    setState(() {});
  }

  Future<bool> validateBatchBackend(String batchNo) async {
    if (selectedMedicineId == null || batchNo.isEmpty) {
      return true; // allow typing
    }

    try {
      final url = Uri.parse(
        "$baseUrl/inventory/medicine/${widget.shopId}/$selectedMedicineId/validate-batch?batch_no=$batchNo",
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['is_valid'] == true;
      }
    } catch (_) {}

    return true; // fallback allow
  }

  double purchasePricePerQuantity() {
    final qty = double.tryParse(quantityCtrl.text) ?? 0;
    final rate = double.tryParse(ratePerQtyCtrl.text) ?? 0;
    final gstPercent = double.tryParse(gstCtrl.text) ?? 0;
    final unit = double.tryParse(unitCtrl.text) ?? 0;

    if (qty <= 0 || unit <= 0) return 0;

    final baseAmount = qty * rate;
    final gstPerQty = rate * gstPercent / 100;
    final totalGst = gstPerQty * qty;
    final purchasePrice = baseAmount + totalGst;
    final purchasePerQty = purchasePrice / qty;

    return purchasePerQty;
  }

  bool isFormValid() {
    final mrp = double.tryParse(mrpCtrl.text) ?? 0;

    return selectedMedicineId != null &&
        batchCtrl.text.isNotEmpty &&
        !isBatchTaken &&   // ✅ disable if batch exists
        quantityCtrl.text.trim().isNotEmpty &&
        (double.tryParse(quantityCtrl.text) ?? 0) > 0 &&

        unitCtrl.text.trim().isNotEmpty &&
        (double.tryParse(unitCtrl.text) ?? 0) > 0 &&

        ratePerQtyCtrl.text.trim().isNotEmpty &&
        (double.tryParse(ratePerQtyCtrl.text) ?? 0) > 0 &&

        profitCtrl.text.trim().isNotEmpty &&
        (double.tryParse(profitCtrl.text) ?? 0) >= 0 &&

        mrp > 0 &&
        mrp >= purchasePricePerQuantity() &&   // ✅ call function

        supplierFound &&
        selectedSupplierId != null &&

        phoneCtrl.text.length == 10 &&

        mfgDate != null &&
        expDate != null &&
        expDate!.isAfter(mfgDate!) ;

  }

  Widget confirmBatchDialog() {
    Widget infoTile(String label, String value,
        {Color valueColor = royal}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(
                "$label:",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: royal,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? "-" : value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      contentPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: royal, width: 1.2),
      ),
      title: const Center(
        child: Text(
          "Confirm Batch Details",
          style: TextStyle(fontWeight: FontWeight.bold, color: royal),
        ),
      ),
      content: SingleChildScrollView(
        child: Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: royal, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                infoTile("Medicine", selectedMedicine!['name']),
                infoTile("Batch No", batchCtrl.text),
                if (rackCtrl.text.trim().isNotEmpty)
                  infoTile("Rack No", rackCtrl.text),
                if (hsnCtrl.text.trim().isNotEmpty)
                  infoTile("HSN Code", hsnCtrl.text),

                const Divider(color: royal),

                /// 🔹 DATES
                infoTile("MFG Date",
                    mfgDate?.toLocal().toString().split(' ')[0] ?? "-"),
                infoTile("EXP Date",
                    expDate?.toLocal().toString().split(' ')[0] ?? "-"),
                infoTile("Purchase Date",
                    purchaseDate.toLocal().toString().split(' ')[0]),

                const Divider(color: royal),

                /// 🔹 STOCK
                infoTile("Quantity", quantityCtrl.text),
                if (freeQtyCtrl.text.trim().isNotEmpty &&
                    freeQtyCtrl.text.trim() != "0")
                  infoTile("Free Qty", freeQtyCtrl.text),
                infoTile("Total Quantity", totalQuantity.toString()),
                infoTile("Unit Per Pack", unitCtrl.text),
                infoTile("Total Stock", totalStock.toString()),

                const Divider(color: royal),

                /// 🔹 SUPPLIER
                infoTile("Supplier Phone", phoneCtrl.text),
                infoTile("Supplier Name", sellerCtrl.text),
                infoTile("Supplier ID",
                    selectedSupplierId?.toString() ?? "-"),

                const Divider(color: royal),

                /// 🔹 PRICING
                infoTile("Rate / Qty", "₹${ratePerQtyCtrl.text}"),
                if (gstCtrl.text.trim().isNotEmpty)
                  infoTile("GST % / Qty", gstCtrl.text),
                if (gstPerQuantity > 0)
                  infoTile(
                    "GST Amount / Qty",
                    "₹${gstPerQuantity.toStringAsFixed(2)}",
                  ),

                infoTile("Base Amount",
                    "₹${baseAmount.toStringAsFixed(2)}"),
                if (totalGstAmount > 0)
                  infoTile(
                    "Total GST",
                    "₹${totalGstAmount.toStringAsFixed(2)}",
                    valueColor: Colors.orange,
                  ),

                const Divider(color: royal),

                /// 🔹 PURCHASE & SELLING
                infoTile("Purchase / Qty",
                    "₹${purchasePerQuantity.toStringAsFixed(2)}",
                    valueColor: Colors.red),
                infoTile("Purchase / Unit",
                    "₹${purchasePerUnit.toStringAsFixed(2)}",
                    valueColor: Colors.red),
                infoTile("Selling / Qty",
                    "₹${sellingPerQuantity.toStringAsFixed(2)}"),
                infoTile("Selling / Unit",
                    "₹${sellingPerUnit.toStringAsFixed(2)}"),
                infoTile("MRP / Quantity", mrpCtrl.text),
                infoTile("Profit %",
                    profitCtrl.text),

                const Divider(color:royal,thickness: 1.2),

                /// 🔥 FINAL TOTAL
                infoTile(
                  "Total Purchase Price",
                  "₹${purchasePrice.toStringAsFixed(2)}",
                  valueColor: Colors.green,

                ),
              ],
            ),
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: royal), // ✅ outline color
            foregroundColor: royal,               // ✅ text & icon color
          ),
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel",style: TextStyle(color: royal),),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: royal,foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Confirm"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: royal),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Center(
              child: Text("Add Batch",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: royal)),
            ),

            const SizedBox(height: 14),

            // 🔍 MEDICINE AUTOCOMPLETE

            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = MediaQuery
                    .of(context)
                    .size
                    .width >= 1000;

                double fieldWidth(BoxConstraints c) {
                  if (!isDesktop) return c.maxWidth;
                  return (c.maxWidth - 32) / 3; // 3 columns with spacing
                }
                int columnCount;
                if (constraints.maxWidth >= 1000) {
                  columnCount = 4; // large desktop
                } else if (constraints.maxWidth >= 800) {
                  columnCount = 3; // tablet
                } else if (constraints.maxWidth >= 600) {
                  columnCount = 2; // tablet
                } else {
                  columnCount = 1; // mobile
                }

                double columnWidth =
                    (constraints.maxWidth - ((columnCount - 1) * 16)) / columnCount;

                return Wrap(
                  spacing: 16,
                  runSpacing: 14,
                  children: [
                    SizedBox(
                      width: fieldWidth(constraints),
                      child:labeledField(
                        label: "Medicine",
                        field: medicineAutocomplete(setState),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child:
                      labeledField(
                        label: "Batch No",
                        field: TextFormField(
                          controller: batchCtrl,
                          cursorColor: royal,
                          keyboardType: TextInputType.visiblePassword,
                          style: const TextStyle(color: royal),
                          focusNode: batchFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(rackFocus); // 👈 NEXT FOCUS
                          },
                          decoration: InputDecoration(
                            hintText: "Enter Batch no",
                            filled: true,
                            hintStyle: TextStyle(color: royal),
                            fillColor: royal.withAlpha(25),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: royal, width: 0.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: royal, width: 1.5),
                            ),
                            suffixIcon: batchCtrl.text.isEmpty
                                ? null
                                : isBatchTaken
                                ? const Icon(Icons.error, color: Colors.red)
                                : const Icon(Icons.check_circle, color: Colors.green),
                          ),
                          onChanged: (value) {
                            debounce?.cancel();

                            debounce =
                                Timer(const Duration(milliseconds: 500), () async {
                                  final batch = value.trim();

                                  if (batch.isEmpty) {
                                    setState(() => isBatchTaken = false);
                                    return;
                                  }

                                  final isValid = await validateBatchBackend(batch);

                                  setState(() {
                                    isBatchTaken =
                                    !isValid; // ❌ taken when backend returns false
                                  });
                                });
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Rack No",
                        field: TextFormField(
                          controller: rackCtrl,
                          cursorColor: royal,
                          focusNode: rackFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(hsnFocus); // 👈 NEXT FOCUS
                          },
                          keyboardType: TextInputType.visiblePassword,
                          style: const TextStyle(color: royal),
                          decoration: _inputDecoration("Optional"),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "MFG Date",
                        field: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: royal,
                            backgroundColor: royal.withValues(alpha: 0.1),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            side: const BorderSide(
                                color: royal, width: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: royal,
                                      onPrimary: Colors.white,
                                      onSurface: royal,
                                    ),
                                    textButtonTheme: TextButtonThemeData(
                                      style: TextButton.styleFrom(
                                          foregroundColor: royal),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) setState(() => mfgDate = picked);
                          },
                          child: Text(
                            mfgDate == null ? "Select date" : mfgDate!
                                .toLocal().toString().split(' ')[0],
                            style: TextStyle(color: royal),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "EXP Date",
                        field: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: royal,
                            backgroundColor: royal.withValues(alpha: 0.1),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            side: const BorderSide(
                                color: royal, width: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: royal,
                                      onPrimary: Colors.white,
                                      onSurface: royal,
                                    ),
                                    textButtonTheme: TextButtonThemeData(
                                      style: TextButton.styleFrom(
                                          foregroundColor: royal),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) setState(() => expDate = picked);
                          },
                          child: Text(
                            expDate == null ? "Select date" : expDate!
                                .toLocal().toString().split(' ')[0],
                            style: TextStyle(color: royal),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "HSN Code",
                        field: TextFormField(
                          cursorColor: royal,
                          focusNode: hsnFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(qtyFocus); // 👈 NEXT FOCUS
                          },
                          style: TextStyle(color: royal),
                          controller: hsnCtrl,
                          onChanged: (_) => setState(() {}),
                          // ✅ update button state
                          textCapitalization: TextCapitalization.words,
                          decoration: _inputDecoration("Enter HSN Code"),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Quantity",
                        field: TextFormField(
                          controller: quantityCtrl,
                          keyboardType: TextInputType.number,
                          cursorColor: royal,
                          focusNode: qtyFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(freeQtyFocus); // 👈 NEXT FOCUS
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            // ✅ allows only digits
                          ],
                          style: const TextStyle(color: royal),
                          decoration: _inputDecoration("Strips Count"),
                          onChanged: (_) {
                            calculateStock();
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Free Quantity",
                        field: TextFormField(
                          controller: freeQtyCtrl,
                          focusNode: freeQtyFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(unitFocus); // 👈 NEXT FOCUS
                          },
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            // ✅ allows only digits
                          ],
                          cursorColor: royal,
                          style: const TextStyle(color: royal),
                          decoration: _inputDecoration("Free Strips Count "),
                          onChanged: (_) => calculateStock(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Unit Per Pack",
                        field: TextFormField(
                          controller: unitCtrl,
                          keyboardType: TextInputType.number,
                          focusNode: unitFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(rateFocus); // 👈 NEXT FOCUS
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            // ✅ allows only digits
                          ],
                          cursorColor: royal,
                          style: const TextStyle(color: royal),
                          decoration: _inputDecoration("Unit(per quantity)"),
                          onChanged: (_) {
                            calculateStock();
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Rate / Quantity (₹)",
                        field: TextFormField(
                          controller: ratePerQtyCtrl,
                          keyboardType: TextInputType.number,
                          cursorColor: royal,
                          focusNode: rateFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(gstFocus); // 👈 NEXT FOCUS
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}')), // allows 2 decimals
                          ],
                          style: const TextStyle(color: royal),
                          decoration: _inputDecoration("Rate per quantity"),
                          onChanged: (_) => calculatePurchaseValues(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "GST % / Quantity",
                        field: TextFormField(
                          controller: gstCtrl,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}')), // allows 2 decimals
                          ],
                          focusNode: gstFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(mrpFocus); // 👈 NEXT FOCUS
                          },
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          cursorColor: royal,
                          style: const TextStyle(color: royal),
                          decoration: _inputDecoration("GST percentage (0–100)"),
                          onChanged: (value) {
                            final gst = double.tryParse(value);

                            if (gst != null && gst > 100) {
                              gstCtrl.text = '100'; // ⛔ STOP at 100
                              gstCtrl.selection = TextSelection.collapsed(offset: 3);
                            }

                            calculatePurchaseValues();
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(label: "MRP / Quantity (₹)",
                        field: TextFormField(
                          controller: mrpCtrl,
                          keyboardType: TextInputType.number,
                          cursorColor: royal,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}')), // allows 2 decimals
                          ],
                          focusNode: mrpFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(profitFocus); // 👈 NEXT FOCUS
                          },
                          style: const TextStyle(color: royal),
                          decoration: _inputDecoration(
                              "Maximum Retail Price"),
                          onChanged: (_) =>
                              calculatePurchaseValues(), // 🔥 REQUIRED
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Profit %",
                        field: TextFormField(
                          controller: profitCtrl,
                          keyboardType: TextInputType.number,
                          cursorColor: royal,
                          style: const TextStyle(color: royal),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}')), // allows 2 decimals
                          ],
                          focusNode: profitFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(phoneFocus); // 👈 NEXT FOCUS
                          },
                          decoration: _inputDecoration("Profit percentage"),
                          onChanged: (_) =>
                              calculatePurchaseValues(), // 🔥 REQUIRED
                        ),
                      ),


                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Purchase Date",
                        field: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: royal,
                            backgroundColor: royal.withValues(alpha: 0.1),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            side: const BorderSide(
                                color: royal, width: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: purchaseDate,
                              // ✅ today by default
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: royal,
                                      onPrimary: Colors.white,
                                      onSurface: royal,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );

                            if (picked != null) {
                              setState(() => purchaseDate = picked);
                            }
                          },
                          child: Text(
                            purchaseDate.toLocal().toString().split(' ')[0],
                            style: const TextStyle(color: royal),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Supplier Phone",
                        field: StatefulBuilder(
                          builder: (context, setPhoneState) {
                            return TextFormField(
                              controller: phoneCtrl,
                              cursorColor: royal,
                              style: TextStyle(color: royal),
                              keyboardType: TextInputType.phone,
                              focusNode: phoneFocus,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) {
                                FocusScope.of(context).unfocus(); // 👈 NEXT FOCUS
                              },
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              decoration: _inputDecoration(
                                  "Enter Supplier Phone number").copyWith(
                                suffixIcon: phoneCtrl.text.length == 10
                                    ? supplierFound
                                    ? const Icon(
                                    Icons.check_circle, color: Colors.green,
                                    size: 24) // ✅ RIGHT
                                    : const Icon(Icons.error, color: Colors.red,
                                    size: 24) // ❌ WRONG
                                    : null,
                              ),
                              onChanged: (value) {
                                setPhoneState(() {
                                  supplierFound = false;
                                  selectedSupplierId = null;
                                  sellerCtrl.clear();
                                });
                                setState(() {});

                                if (value.length != 10) return;

                                phoneDebounce?.cancel();
                                phoneDebounce = Timer(
                                    const Duration(milliseconds: 500), () async {
                                  try {
                                    final url = Uri.parse(
                                        "$baseUrl/suppliers/search/by-phone/${widget.shopId}?phone=$value");
                                    final response = await http.get(url);

                                    setPhoneState(() {
                                      if (response.statusCode == 200) {
                                        final data = jsonDecode(
                                            response.body) as List;
                                        if (data.isNotEmpty) {
                                          supplierFound = true;
                                          selectedSupplierId = data[0]['id'];
                                          sellerCtrl.text = data[0]['name'] ?? '';
                                        } else {
                                          supplierFound = false; // ❌ Shows RED icon
                                        }
                                      } else {
                                        supplierFound = false; // ❌ Shows RED icon
                                      }
                                    });
                                    setState(() {});
                                  } catch (e) {
                                    setPhoneState(() =>
                                    supplierFound = false); // ❌ Shows RED icon
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [

                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment
                                .center,
                            child: Text(
                              supplierFound
                                  ? "Supplier name: ${sellerCtrl.text}"
                                  : "No supplier found",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: supplierFound ? royal : Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment
                                .center,
                            child: Text(
                              selectedSupplierId != null
                                  ? "Supplier ID: $selectedSupplierId"
                                  : "Supplier ID: Not Found",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: supplierFound ? royal : Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
                            child: Text(
                              "Total Quantity: ${totalQuantity.toInt()}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: royal),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
                            child: Text(
                              "Total Stock: ${totalStock.toInt()}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: royal),
                            ),
                          ),
                        ),

                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment
                                .center,
                            child: Text(
                              "GST Amount / Qty: ₹${gstPerQuantity.toStringAsFixed(
                                  2)}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: royal),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment
                                .center,
                            child: Text(
                              "Purchase / Quantity: ₹${purchasePerQuantity
                                  .toStringAsFixed(2)}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: royal),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment
                                .center,
                            child: Text(
                              "Purchase / Unit: ₹${purchasePerUnit.toStringAsFixed(
                                  2)}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: royal),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment
                                .center,
                            child: Text(
                              "Selling / Quantity: ₹${sellingPerQuantity
                                  .toStringAsFixed(2)}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: royal),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment
                                .center,
                            child: Text(
                              "Selling / Unit: ₹${sellingPerUnit.toStringAsFixed(2)}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: royal),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment
                                .center,
                            child: Text(
                              "Base Amount: ₹${baseAmount.toStringAsFixed(2)}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: royal),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment
                                .center,
                            child: Text(
                              "Total GST: ₹${totalGstAmount.toStringAsFixed(2)}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: royal),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: Align(
                            alignment: isDesktop ? Alignment.centerLeft : Alignment
                                .center,
                            child: Text(
                              "Purchase Price: ₹${purchasePrice.toStringAsFixed(2)}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: royal),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: SizedBox(
                        width: 150,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFormValid() ? royal : Colors.grey,
                            foregroundColor: isFormValid() ? Colors.white : royal,
                            elevation: 0,
                            side: BorderSide(
                              color: isFormValid() ? royal : Colors.grey.shade700,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: isFormValid() ? submitBatch : null,
                          child: const Text("Submit Batch"),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
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

