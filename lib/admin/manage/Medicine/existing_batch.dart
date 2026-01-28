import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../services/config.dart';
import '../../../widget/color_theme.dart';

class ExistingMedicineBatchForm extends StatefulWidget {
  final String shopId;
  final Function() fetchMedicines;
  final Function(bool) onClose;
  final List<Map<String, dynamic>> medicines; // ✅ Add this

  const ExistingMedicineBatchForm({
    super.key,
    required this.shopId,
    required this.fetchMedicines,
    required this.onClose,
    required this.medicines, // ✅ Pass it in constructor
  });

  @override
  State<ExistingMedicineBatchForm> createState() => _ExistingMedicineBatchFormState();
}

class _ExistingMedicineBatchFormState extends State<ExistingMedicineBatchForm> {

  Timer? debounce;
  bool isBatchTaken = false;
  final rackCtrl = TextEditingController();
  final unitCtrl = TextEditingController();

  DateTime? mfgDate;
  DateTime? expDate;

  int? selectedMedicineId;
  Map<String, dynamic>? selectedMedicine;
  final batchCtrl = TextEditingController();
  final medicineCtrl = TextEditingController();

  int totalQuantity = 0; // was double
  double totalStock = 0; // ✅ FIX
  double sellingPerUnit = 0;
  double sellingPerQuantity = 0;

  final medicineFocus = FocusNode();
  final batchFocus = FocusNode();
  final rackFocus = FocusNode();
  final unitFocus = FocusNode();
  final stockFocus = FocusNode();
  final sellingunitFocus = FocusNode();
  final sellingqtyFocus = FocusNode();

  final totalStockCtrl = TextEditingController();
  final sellingUnitCtrl = TextEditingController();
  final sellingQtyCtrl = TextEditingController();

  void resetForm() {
    medicineCtrl.clear();   // ✅ Clears autocomplete text
    selectedMedicine = null;
    selectedMedicineId = null;
    batchCtrl.clear();
    rackCtrl.clear();
    unitCtrl.clear();
    totalStockCtrl.clear();
    sellingUnitCtrl.clear();
    sellingQtyCtrl.clear();

    mfgDate = null;
    expDate = null;
    totalQuantity = 0;
    totalStock = 0;

    sellingPerUnit = 0;
    sellingPerQuantity = 0;

    medicineFocus.unfocus();
    batchFocus.unfocus();
    rackFocus.unfocus();
    unitFocus.unfocus();
    stockFocus.unfocus();
    sellingunitFocus.unfocus();
    sellingqtyFocus.unfocus();

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

    final response = await http.post(
      Uri.parse("$baseUrl/inventory/medicine/$selectedMedicineId/batch-exist"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "shop_id": widget.shopId,
        "batch_no": batchCtrl.text,
        "mfg_date": mfgDate?.toIso8601String(),
        "exp_date": expDate?.toIso8601String(),
        "rack_no": rackCtrl.text,
        "total_quantity": totalQuantity,
        "unit": int.tryParse(unitCtrl.text),
        "total_stock": double.tryParse(totalStockCtrl.text),
        "selling_price_per_unit": truncateTo2Decimals(sellingPerUnit),
        "selling_price_per_quantity":
        truncateTo2Decimals(sellingPerQuantity),

      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      // ✅ Only reset and close on success
      resetForm();
      widget.onClose(false);
      widget.fetchMedicines();
    } else {
      // ❌ Show error if submission fails
      _showError("Failed to submit batch. Please try again.");

    }
  }
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }

  double truncateTo2Decimals(double value) {
    return (value * 100).truncate() / 100;
  }

  void calculateTotalQuantity() {
    final stock = double.tryParse(totalStockCtrl.text) ?? 0;
    final unit = double.tryParse(unitCtrl.text) ?? 1; // avoid division by 0
    setState(() {
      // round up to nearest integer
      totalQuantity = (stock / unit).ceil(); // integer now
    });

    // Also update selling price if one is entered
    if (sellingPerUnit > 0) {
      sellingPerQuantity =
          truncateTo2Decimals(sellingPerUnit * unit);
      sellingQtyCtrl.text = sellingPerQuantity.toString();
    } else if (sellingPerQuantity > 0) {
      sellingPerUnit = unit != 0
          ? truncateTo2Decimals(sellingPerQuantity / unit)
          : 0;
      sellingUnitCtrl.text = sellingPerUnit.toString();
    }
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


  bool isFormValid() {
    final unitValue = double.tryParse(unitCtrl.text) ?? 0;
    final stockValue = double.tryParse(totalStockCtrl.text) ?? 0;

    return selectedMedicineId != null &&
        batchCtrl.text.isNotEmpty &&
        !isBatchTaken &&   // ✅ disable if batch exists

        unitCtrl.text.trim().isNotEmpty &&
        (double.tryParse(unitCtrl.text) ?? 0) > 0 &&
        unitValue > 0 &&
        stockValue >= 0 &&

        sellingPerUnit > 0 &&
        sellingPerQuantity > 0 &&

        mfgDate != null &&
        expDate != null &&
        expDate!.isAfter(mfgDate!);

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

                Divider(color: royal),

                /// 🔹 DATES
                infoTile("MFG Date",
                    mfgDate?.toLocal().toString().split(' ')[0] ?? "-"),
                infoTile("EXP Date",
                    expDate?.toLocal().toString().split(' ')[0] ?? "-"),

                const Divider(color: royal),

                /// 🔹 STOCK
                infoTile("Total Quantity", totalQuantity.toString()),
                infoTile("Unit Per Pack", unitCtrl.text),
                infoTile("Total Stock", totalStockCtrl.text),


                const Divider(color: royal),


                infoTile("Selling / Qty",
                    "₹${sellingPerQuantity.toStringAsFixed(2)}"),
                infoTile("Selling / Unit",
                    "₹${sellingPerUnit.toStringAsFixed(2)}"),

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
                            FocusScope.of(context).requestFocus(stockFocus); // 👈 NEXT FOCUS
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
                        label: "Total Stock",
                        field: TextFormField(
                          controller: totalStockCtrl,
                          cursorColor: royal,
                          style: const TextStyle(color: royal),
                          focusNode: stockFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(unitFocus);
                          },
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (_) => calculateTotalQuantity(),
                          decoration: _inputDecoration("Enter total stock"),
                        ),
                      ),
                    ),

                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Unit per Pack",
                        field: TextFormField(
                          controller: unitCtrl,
                          cursorColor: royal,
                          focusNode: unitFocus,
                          style: const TextStyle(color: royal),
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(sellingunitFocus);
                          },
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (_) => calculateTotalQuantity(),
                          decoration: _inputDecoration("Unit per quantity"),
                        ),
                      ),
                    ),


                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Selling / Unit",
                        field: TextFormField(
                          controller: sellingUnitCtrl,
                          cursorColor: royal,
                          style: const TextStyle(color: royal),
                          focusNode: sellingunitFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(sellingqtyFocus);
                          },
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final val = double.tryParse(v) ?? 0;
                            setState(() {
                              sellingPerUnit = val;
                              final unit = double.tryParse(unitCtrl.text) ?? 1;
                              sellingPerQuantity = truncateTo2Decimals(val * unit);
                              sellingQtyCtrl.text = sellingPerQuantity.toString();   });
                          },
                          decoration: _inputDecoration("Enter selling price per unit"),
                        ),
                      ),
                    ),

                    SizedBox(
                      width: fieldWidth(constraints),
                      child: labeledField(
                        label: "Selling / Quantity",
                        field: TextFormField(
                          controller: sellingQtyCtrl,
                          cursorColor: royal,
                          style: const TextStyle(color: royal),
                          focusNode: sellingqtyFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).unfocus(); // ✅ dismiss keyboard
                          },
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final val = double.tryParse(v) ?? 0;
                            setState(() {
                              sellingPerQuantity = val;
                              final unit = double.tryParse(unitCtrl.text) ?? 1;
                              sellingPerUnit =
                              unit != 0 ? truncateTo2Decimals(val / unit) : 0;
                              sellingUnitCtrl.text = sellingPerUnit.toString();  });
                          },
                          decoration: _inputDecoration("Enter selling price per quantity"),
                        ),
                      ),
                    ),
                    summaryBox(
                        width: columnWidth,
                        isDesktop: isDesktop,
                        text: "Total Quantity: $totalQuantity"
                    ),
                    const SizedBox(height: 14),
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
