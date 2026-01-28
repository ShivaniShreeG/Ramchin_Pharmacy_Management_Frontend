import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../services/config.dart' show baseUrl;
import '../../../widget/color_theme.dart';

class AddMedicineForm extends StatefulWidget {
  final String shopId;
  final Function() fetchMedicines;
  final Function(bool) onClose;
  final List<String> categories; // ✅ NEW

  const AddMedicineForm({
    super.key,
    required this.shopId,
    required this.fetchMedicines,
    required this.onClose,
    required this.categories,
  });

  @override
  State<AddMedicineForm> createState() => _AddMedicineFormState();
}
class _AddMedicineFormState extends State<AddMedicineForm> {

  final reorderCtrl = TextEditingController(text: '10');
  final nameCtrl = TextEditingController();
  bool isNameTaken = false;

  final ndcCtrl = TextEditingController();
  late List<String> medicineCategories;

  String selectedCategory = "Tablets";
  bool isOtherCategory = false;
  final otherCategoryCtrl = TextEditingController();

  DateTime? mfgDate;
  DateTime? expDate;
  DateTime purchaseDate = DateTime.now();

  int? selectedSupplierId;
  bool supplierFound = false;

  final batchCtrl = TextEditingController(text: "01");
  final rackCtrl = TextEditingController();
  final quantityCtrl = TextEditingController();
  final unitCtrl = TextEditingController();
  final profitCtrl = TextEditingController();
  final sellerCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final hsnCtrl = TextEditingController();
  final mrpCtrl = TextEditingController();
  final freeQtyCtrl = TextEditingController();
  double totalQuantity = 0;
  double totalStock = 0; // ✅ FIX
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
  final nameFocus = FocusNode();
  final ndcFocus = FocusNode();
  final reorderFocus = FocusNode();
  final batchFocus = FocusNode();
  final rackFocus = FocusNode();
  final hsnFocus = FocusNode();
  final quantityFocus = FocusNode();
  final freeQtyFocus = FocusNode();
  final unitFocus = FocusNode();
  final rateFocus = FocusNode();
  final gstFocus = FocusNode();
  final mrpFocus = FocusNode();
  final profitFocus = FocusNode();
  final phoneFocus = FocusNode();

  @override
  void initState() {
    super.initState();

    final defaultCategories = [
      "Tablets",
      "Syrups",
      "Drops",
      "Ointments",
      "Creams",
      "Soap",
    ];

    medicineCategories = {
      ...defaultCategories,
      ...widget.categories, // 👈 FROM BACKEND
      "Other",
    }.toList();

    // safety: selected value must exist
    if (!medicineCategories.contains(selectedCategory)) {
      selectedCategory = medicineCategories.first;
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

    calculatePurchaseValues();

    setState(() {});
  }

  Future<void> submitMedicine() async {
    if (!isFormValid()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => confirmMedicineDialog(),
    );

    if (confirmed != true) return;

    final finalCategory =
    isOtherCategory ? otherCategoryCtrl.text.trim() : selectedCategory;

    final response = await http.post(
      Uri.parse("$baseUrl/inventory/medicine"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "shop_id": widget.shopId,
        "name": nameCtrl.text,
        "category": finalCategory,
        "ndc_code": ndcCtrl.text,
        "batch_no": batchCtrl.text,
        "mfg_date": mfgDate?.toIso8601String(),
        "exp_date": expDate?.toIso8601String(),
        "rack_no": rackCtrl.text,
        "quantity": quantityCtrl.text,
        "free_quantity": freeQtyCtrl.text,
        "total_quantity": totalQuantity,
        "unit": unitCtrl.text,
        "total_stock": totalStock,
        "mrp": mrpCtrl.text,
        "supplier_id": selectedSupplierId,
        "reorder": int.tryParse(reorderCtrl.text),
        "hsncode": hsnCtrl.text,
        "purchase_details": {
          "purchase_date": purchaseDate.toIso8601String(),
          "rate_per_quantity": double.tryParse(ratePerQtyCtrl.text) ?? 0,
          "gst_percent": double.tryParse(gstCtrl.text) ?? 0,
          "gst_per_quantity": double.parse(gstPerQuantity.toStringAsFixed(2)),
          "base_amount": double.parse(baseAmount.toStringAsFixed(2)),
          "total_gst_amount": double.parse(totalGstAmount.toStringAsFixed(2)),
          "purchase_price": double.parse(purchasePrice.toStringAsFixed(2)),
        },
        "purchase_price_per_unit":
        double.parse(purchasePerUnit.toStringAsFixed(2)),
        "purchase_price_per_quantity":
        double.parse(purchasePerQuantity.toStringAsFixed(2)),
        "selling_price_per_unit":
        double.parse(sellingPerUnit.toStringAsFixed(2)),
        "selling_price_per_quantity":
        double.parse(sellingPerQuantity.toStringAsFixed(2)),
        "profit_percent": double.tryParse(profitCtrl.text) ?? 0,
      }),
    );

    // ✅ SUCCESS ONLY
    if (response.statusCode == 200 || response.statusCode == 201) {
      resetForm();
      widget.onClose(false);   // 👈 close only on success
      widget.fetchMedicines();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to add medicine. Please try again."),
        ),
      );
    }
  }

  void resetForm() {
    nameCtrl.clear();
    ndcCtrl.clear();
    batchCtrl.text = "01";
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
    reorderCtrl.clear();
    otherCategoryCtrl.clear();

    selectedCategory = medicineCategories.first;
    isOtherCategory = false;

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
    isNameTaken = false;
    phoneDebounce?.cancel();
    setState(() {});
  }

  Widget confirmMedicineDialog() {
    final finalCategory =
    isOtherCategory ? otherCategoryCtrl.text.trim() : selectedCategory;
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
        side: BorderSide(color: royal, width: 1.2),
      ),
      title: const Center(
        child: Text(
          "Confirm Medicine Details",
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

                /// 🔹 BASIC INFO
                infoTile("Name", nameCtrl.text),
                infoTile("Category", finalCategory),
                if (ndcCtrl.text.trim().isNotEmpty)
                  infoTile("NDC", ndcCtrl.text),
                infoTile("Batch No", batchCtrl.text),
                if (rackCtrl.text.trim().isNotEmpty)
                  infoTile("Rack No", rackCtrl.text),
                if (hsnCtrl.text.trim().isNotEmpty)
                  infoTile("HSN Code", hsnCtrl.text),

                Divider(color: royal),

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

    return
      nameCtrl.text.trim().isNotEmpty &&
          !isNameTaken &&

          selectedCategory.isNotEmpty &&
          (!isOtherCategory || otherCategoryCtrl.text.trim().isNotEmpty) &&

          batchCtrl.text.trim().isNotEmpty &&

          quantityCtrl.text.trim().isNotEmpty &&
          (double.tryParse(quantityCtrl.text) ?? 0) > 0 &&

          unitCtrl.text.trim().isNotEmpty &&
          (double.tryParse(unitCtrl.text) ?? 0) > 0 &&

          ratePerQtyCtrl.text.trim().isNotEmpty &&
          (double.tryParse(ratePerQtyCtrl.text) ?? 0) > 0 &&

          profitCtrl.text.trim().isNotEmpty &&
          (double.tryParse(profitCtrl.text) ?? 0) >= 0 &&

          mrp > 0 &&
          mrp > 0 && mrp >= purchasePricePerQuantity() &&

          supplierFound &&
          selectedSupplierId != null &&

          phoneCtrl.text.length == 10 &&

          mfgDate != null &&
          expDate != null &&
          expDate!.isAfter(mfgDate!);
  }
  @override
  Widget build(BuildContext context) {

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.all(10),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: royal, // 👈 border color
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Center(
              child: Text("Add Medicine & Batch",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: royal)),
            ),

            const SizedBox(height: 14),
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
                      child: labeledField(
                        label: "Name",
                        field: StatefulBuilder(
                          builder: (context, setLocalState) {
                            Timer? debounce;
                            return TextFormField(
                              controller: nameCtrl,
                              style: TextStyle(color: royal),
                              cursorColor: royal,
                              focusNode: nameFocus,
                              textInputAction: TextInputAction.next, // 👈 shows NEXT / Enter
                              onFieldSubmitted: (_) {
                                FocusScope.of(context).requestFocus(ndcFocus); // 👈 NEXT FOCUS
                              }, //                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: "Enter Medicine name",
                                hintStyle: TextStyle(color: royal),
                                filled: true,
                                fillColor: royal.withValues(alpha: 0.1),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: royal, width: 0.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: royal, width: 1.5),
                                ),
                                suffixIcon: isNameTaken
                                    ? const Icon(
                                    Icons.error, color: Colors.red)
                                    : const Icon(
                                    Icons.check, color: Colors.green),
                              ),
                              onChanged: (value) {
                                if (debounce?.isActive ?? false) debounce!.cancel();
                                debounce = Timer(const Duration(
                                    milliseconds: 500), () async {
                                  if (value
                                      .trim()
                                      .isEmpty) {
                                    setLocalState(() =>
                                    isNameTaken = false);
                                    return;
                                  }
                                  try {
                                    final url = Uri.parse(
                                        "$baseUrl/inventory/medicine/check-name/${widget.shopId}?name=$value");
                                    final response = await http.get(url);
                                    if (response.statusCode == 200) {
                                      final data = jsonDecode(
                                          response.body);
                                      setLocalState(() =>
                                      isNameTaken =
                                          data['exists'] ?? false);
                                    } else {
                                      setLocalState(() =>
                                      isNameTaken = false);
                                    }
                                  } catch (_) {
                                    setLocalState(() =>
                                    isNameTaken = false);
                                  }
                                });
                                setLocalState(() {});
                              },
                            );
                          },
                        ),
                      ),
                    ),

                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Category",
                        field: DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          iconEnabledColor: royal,
                          style: const TextStyle(color: royal),
                          decoration: _inputDecoration("Select category"),
                          items: medicineCategories
                              .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              selectedCategory = v!;
                              isOtherCategory = v == "Other";
                              if (!isOtherCategory) otherCategoryCtrl.clear();
                            });
                          },
                        ),
                      ),
                    ),

                    if (isOtherCategory)
                      SizedBox(
                        width: fieldWidth(constraints),
                        child: labeledField(
                          label: "Custom Category",
                          field: TextFormField(
                            controller: otherCategoryCtrl,
                            textCapitalization: TextCapitalization.words,
                            cursorColor: royal,
                            style: const TextStyle(color: royal),
                            onChanged: (_) => setState(() {}),
                            decoration: _inputDecoration(
                                "Enter custom category"),
                          ),
                        ),
                      ),

                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "NDC",
                        field: TextFormField(
                          controller: ndcCtrl,
                          cursorColor: royal,
                          keyboardType: TextInputType.visiblePassword,
                          style: const TextStyle(color: royal),
                          focusNode: ndcFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(reorderFocus);
                          },
                          decoration: _inputDecoration(
                              "Enter NDC code (optional)"),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Reorder-Level",
                        field: TextFormField(
                          cursorColor: royal,
                          style: TextStyle(color: royal),
                          keyboardType: TextInputType.number,
                          controller: reorderCtrl,
                          focusNode: reorderFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(batchFocus);
                          },
                          onChanged: (_) => setState(() {}),
                          // ✅ update button state
                          decoration: _inputDecoration("Enter Re-order value"),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Batch No",
                        field: TextFormField(
                          controller: batchCtrl,
                          cursorColor: royal,
                          focusNode: batchFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(rackFocus);
                          },
                          onChanged: (_) => setState(() {}),
                          keyboardType: TextInputType.visiblePassword,
                          style: const TextStyle(color: royal),
                          decoration: _inputDecoration("Enter Batch no"),
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
                            FocusScope.of(context).requestFocus(hsnFocus);
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
                          style: TextStyle(color: royal),
                          controller: hsnCtrl,
                          focusNode: hsnFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(quantityFocus);
                          },
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
                          focusNode: quantityFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(freeQtyFocus);
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly, // ✅ allows only digits
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
                          keyboardType: TextInputType.number,
                          focusNode: freeQtyFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(unitFocus);
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly, // ✅ allows only digits
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
                          focusNode: unitFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(rateFocus);
                          },
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly, // ✅ allows only digits
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
                          focusNode: rateFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(gstFocus);
                          },
                          cursorColor: royal,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')), // allows 2 decimals
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
                          focusNode: gstFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(mrpFocus);
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')), // allows 2 decimals
                          ],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          cursorColor: royal,
                          style: const TextStyle(color: royal),
                          decoration: _inputDecoration("GST percentage (0–100)"),
                          onChanged: (value) {
                            final gst = double.tryParse(value);

                            if (gst != null && gst > 100) {
                              gstCtrl.text = '100';                 // ⛔ STOP at 100
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
                          focusNode: mrpFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(profitFocus);
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')), // allows 2 decimals
                          ],
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
                          focusNode: profitFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(phoneFocus);
                          },
                          style: const TextStyle(color: royal),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')), // allows 2 decimals
                          ],
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
                              focusNode: phoneFocus,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) {
                                FocusScope.of(context).unfocus(); // close keyboard
                              },
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              decoration: _inputDecoration("Enter Supplier Phone number").copyWith(
                                suffixIcon: phoneCtrl.text.length == 10
                                    ? supplierFound
                                    ? const Icon(Icons.check_circle, color: Colors.green, size: 24)  // ✅ RIGHT
                                    : const Icon(Icons.error, color: Colors.red, size: 24)          // ❌ WRONG
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
                                phoneDebounce = Timer(const Duration(milliseconds: 500), () async {
                                  try {
                                    final url = Uri.parse("$baseUrl/suppliers/search/by-phone/${widget.shopId}?phone=$value");
                                    final response = await http.get(url);

                                    setPhoneState(() {
                                      if (response.statusCode == 200) {
                                        final data = jsonDecode(response.body) as List;
                                        if (data.isNotEmpty) {
                                          supplierFound = true;
                                          selectedSupplierId = data[0]['id'];
                                          sellerCtrl.text = data[0]['name'] ?? '';
                                        } else {
                                          supplierFound = false;  // ❌ Shows RED icon
                                        }
                                      } else {
                                        supplierFound = false;  // ❌ Shows RED icon
                                      }
                                    });
                                    setState(() {});
                                  } catch (e) {
                                    setPhoneState(() => supplierFound = false);  // ❌ Shows RED icon
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

                        summaryBox(
                          width: columnWidth,
                          isDesktop: isDesktop,
                          text: supplierFound
                              ? "Supplier name: ${sellerCtrl.text}"
                              : "No supplier found",
                          color: supplierFound ? royal : Colors.grey,
                        ),

                        summaryBox(
                          width: columnWidth,
                          isDesktop: isDesktop,
                          text: selectedSupplierId != null
                              ? "Supplier ID: $selectedSupplierId"
                              : "Supplier ID: Not Found",
                          color: supplierFound ? royal : Colors.grey,
                        ),

                        summaryBox(
                          width: columnWidth,
                          isDesktop: isDesktop,
                          text: "Total Quantity: ${totalQuantity.toInt()}",
                        ),

                        summaryBox(
                          width: columnWidth,
                          isDesktop: isDesktop,
                          text: "Total Stock: ${totalStock.toInt()}",

                        ),

                        summaryBox(
                          width: columnWidth,
                          isDesktop: isDesktop,
                          text:
                          "GST Amount / Qty: ₹${gstPerQuantity.toStringAsFixed(2)}",
                        ),

                        summaryBox(
                          width: columnWidth,
                          isDesktop: isDesktop,
                          text:
                          "Purchase / Quantity: ₹${purchasePerQuantity.toStringAsFixed(2)}",
                        ),

                        summaryBox(
                          width: columnWidth,
                          isDesktop: isDesktop,
                          text:
                          "Purchase / Unit: ₹${purchasePerUnit.toStringAsFixed(2)}",
                        ),
                        summaryBox(
                          width: columnWidth,
                          isDesktop: isDesktop,
                          text:
                          "Selling / Quantity: ₹${sellingPerQuantity.toStringAsFixed(2)}",
                        ),
                        summaryBox(
                          width: columnWidth,
                          isDesktop: isDesktop,
                          text:
                          "Selling / Unit: ₹${sellingPerUnit.toStringAsFixed(2)}",
                        ),
                        summaryBox(
                          width: columnWidth,
                          isDesktop: isDesktop,
                          text:
                          "Base Amount: ₹${baseAmount.toStringAsFixed(2)}",
                        ),
                        summaryBox(
                          width: columnWidth,
                          isDesktop: isDesktop,
                          text:
                          "Total GST: ₹${totalGstAmount.toStringAsFixed(2)}",
                        ),
                        summaryBox(
                          width: columnWidth,
                          isDesktop: isDesktop,
                          text:
                          "Purchase Price: ₹${purchasePrice.toStringAsFixed(2)}",
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
                          onPressed: isFormValid() ? submitMedicine : null,
                          child: const Text(
                            "Submit Medicine",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
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

Widget summaryBox({
  required double width,
  required bool isDesktop,
  required String text,
  Color color = royal,
}) {
  return SizedBox(
    width: width,
    child: Align(
      alignment:
      isDesktop ? Alignment.centerLeft : Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: 14,
        ),
      ),
    ),
  );
}
