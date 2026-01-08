import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import '../../public/config.dart';
import '../../public/main_navigation.dart';

const Color royal = Color(0xFF875C3F);

class BulkUploadPage extends StatefulWidget {
  const BulkUploadPage({super.key});

  @override
  State<BulkUploadPage> createState() => _BulkUploadPageState();
}

class _BulkUploadPageState extends State<BulkUploadPage> {
  bool isLoadingShop = true;
  Map<String, dynamic>? shopDetails;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    if (shopId != null) {
      final res = await http.get(Uri.parse('$baseUrl/shops/$shopId'));
      if (res.statusCode == 200) {
        shopDetails = jsonDecode(res.body);
      }
    }
    setState(() => isLoadingShop = false);
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

  Future<void> _downloadTemplate() async {
    if (Platform.isAndroid) {
      if (!await Permission.storage.request().isGranted) {
        _showMessage("Storage permission denied");
        return;
      }
    }

    final data = await rootBundle.load('assets/medicine.xlsx');
    final dir = Platform.isAndroid
        ? Directory('/storage/emulated/0/Download')
        : await getApplicationDocumentsDirectory();

    final file = File('${dir.path}/medicine.xlsx');
    await file.writeAsBytes(data.buffer.asUint8List());

    _showMessage("Template downloaded in $file");
  }

  Future<List<Map<String, dynamic>>> parseExcel(File file) async {
    final bytes = await file.readAsBytes();
    final ex = excel.Excel.decodeBytes(bytes);

    List<Map<String, dynamic>> rows = [];

    double toTwoDecimals(dynamic value) {
      if (value == null) return 0.0;
      double v = 0.0;
      if (value is double) {
        v = value;
      } else if (value is int) {
        v = value.toDouble();
      } else {
        v = double.tryParse(value.toString()) ?? 0.0;
      }
      return double.parse(v.toStringAsFixed(2)); // round to 2 decimals
    }

    String formatDate(dynamic value) {
      if (value == null) return "";
      try {
        DateTime date;
        if (value is DateTime) {
          date = value;
        } else if (value is double) {
          // Excel serial number
          date = DateTime(1899, 12, 30).add(Duration(days: value.toInt()));
        } else {
          date = DateTime.parse(value.toString());
        }
        return date.toIso8601String().split("T")[0];
      } catch (_) {
        return "";
      }
    }

    bool isMfgValid(String date) {
      if (date.isEmpty) return true;
      try {
        return DateTime.parse(date).isBefore(DateTime.now());
      } catch (_) {
        return false;
      }
    }

    bool isExpValid(String date) {
      if (date.isEmpty) return true;
      try {
        return DateTime.parse(date).isAfter(DateTime.now());
      } catch (_) {
        return false;
      }
    }

    for (var sheet in ex.tables.values) {
      for (var row in sheet.rows.skip(1)) {
        dynamic cell(int index) => index < row.length ? row[index]?.value : null;

        String mfg = formatDate(cell(5));
        String exp = formatDate(cell(4));
        String purchase = formatDate(cell(14));

        // Apply validation rules
        if (!isMfgValid(mfg)) mfg = "";
        if (!isExpValid(exp)) exp = "";
        if (purchase.isEmpty) purchase = ""; // UI can show "Choose"

        rows.add({
          "MEDICINE_ID": cell(0),
          "Batch_no": cell(1),
          "Rack_no": cell(2),
          "HSN_code": cell(3),
          "EXP_Date": exp,
          "MFG_Date": mfg,
          "Quantity": cell(6),
          "Free_quantity": cell(7),
          "Unit": cell(8),
          "Rate_per_quantity": toTwoDecimals(cell(9)),
          "GST": toTwoDecimals(cell(10)),
          "MRP": toTwoDecimals(cell(11)),
          "Profit": toTwoDecimals(cell(12)),
          "Supplier_id": cell(13),
          "Purchase_Date": purchase,
        });
      }
    }

    return rows;
  }

  Future<void> _pickExcelAndOpenUpload() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null) {
        _showMessage("No file selected");
        return;
      }

      final path = result.files.single.path;
      if (path == null) {
        _showMessage("Invalid file path");
        return;
      }

      final file = File(path);

      final rows = await parseExcel(file);

      if (rows.isEmpty) {
        _showMessage("Excel file is empty");
        return;
      }
      if (!mounted) return; // stop if widget is disposed
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BulkBatchUpload(batches: rows,shopDetails: shopDetails),
        ),
      );
    } catch (e) {
      _showMessage("Failed to read Excel: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text(
          "Bulk Upload",
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
      body: isLoadingShop
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child:
        Column(
          children: [
            const SizedBox(height: 16),
            if (shopDetails != null) _buildHallCard(shopDetails!),
            const SizedBox(height: 16),
            SizedBox(
              width: 220,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _downloadTemplate,
                icon: const Icon(Icons.download),
                label: const Text(
                  "Download Template",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: royal,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: 180,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _pickExcelAndOpenUpload,
                icon: const Icon(Icons.upload_file),
                label: const Text(
                  "Upload Excel",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: royal,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

          ],),),
    );
  }
}

class BulkBatchUpload extends StatefulWidget {
  final List<Map<String, dynamic>> batches;
  final Map<String, dynamic>? shopDetails;

  const BulkBatchUpload({
    super.key,
    required this.batches,
    required this.shopDetails,
  });

  @override
  State<BulkBatchUpload> createState() => _BulkBatchUploadState();
}

class _BulkBatchUploadState extends State<BulkBatchUpload> {
  late List<Map<String, TextEditingController>> controllers;
  late List<Map<String, dynamic>> calculatedRows;
  Map<String, String> medicineNameCache = {};
  Map<String, String> supplierNameCache = {};
  Map<int, bool?> batchAvailability = {};

  int? shopId;

  @override
  void initState() {
    super.initState();
    shopId = widget.shopDetails?['id'];

    calculatedRows = List.generate(widget.batches.length, (_) => {});

    controllers = widget.batches.map((row) {
      return {
        "MEDICINE_ID": TextEditingController(text: row["MEDICINE_ID"]?.toString() ?? ""),
        "Batch_no": TextEditingController(text: row["Batch_no"]?.toString() ?? ""),
        "Rack_no": TextEditingController(text: row["Rack_no"]?.toString() ?? ""),
        "HSN_code": TextEditingController(text: row["HSN_code"]?.toString() ?? ""),
        "EXP_Date": TextEditingController(text: row["EXP_Date"]?.toString() ?? ""),
        "MFG_Date": TextEditingController(text: row["MFG_Date"]?.toString() ?? ""),
        "Quantity": TextEditingController(text: row["Quantity"]?.toString() ?? ""),
        "Free_quantity": TextEditingController(text: row["Free_quantity"]?.toString() ?? "0"),
        "Unit": TextEditingController(text: row["Unit"]?.toString() ?? ""),
        "Rate_per_quantity": TextEditingController(text: row["Rate_per_quantity"]?.toString() ?? ""),
        "GST": TextEditingController(text: row["GST"]?.toString() ?? "0"),
        "MRP": TextEditingController(text: row["MRP"]?.toString() ?? ""),
        "Profit": TextEditingController(text: row["Profit"]?.toString() ?? ""),
        "Supplier_id": TextEditingController(text: row["Supplier_id"]?.toString() ?? ""),
        "Purchase_Date": TextEditingController(text: row["Purchase_Date"]?.toString() ?? ""),
      };
    }).toList();

    _postInitTasks();

  }

  Future<void> _postInitTasks() async {
    if (shopId == null) return;

    // ✅ Validate existing batch numbers (Excel loaded)
    for (int i = 0; i < controllers.length; i++) {
      final batch = controllers[i]["Batch_no"]!.text.trim();
      final medId = int.tryParse(controllers[i]["MEDICINE_ID"]!.text);

      if (batch.isNotEmpty && medId != null) {
        batchAvailability[i] = null;
        final result = await validateBatchBackend(medId, batch);
        batchAvailability[i] = result;
      }
    }

    // ✅ Fetch names
    for (final r in controllers) {
      final medId = int.tryParse(r["MEDICINE_ID"]!.text);
      final supId = int.tryParse(r["Supplier_id"]!.text);
      if (medId != null) await fetchMedicineName(medId);
      if (supId != null) await fetchSupplierName(supId);
    }

    setState(() {});
  }

  Future<bool> validateBatchBackend(int medicineId, String batchNo) async {
    if (shopId == null || batchNo.isEmpty) {
      throw Exception("ShopId not ready");
    }
    final res = await http.get(
      Uri.parse(
        "$baseUrl/inventory/medicine/$shopId/$medicineId/validate-batch?batch_no=$batchNo",
      ),
    );

    if (res.statusCode != 200 && res.statusCode != 201) return false;

    final data = jsonDecode(res.body);
    return data["is_valid"] == true;
  }

  Future<String?> fetchMedicineName(int id) async {
    if (shopId == null) return null;

    final cacheKey = "$shopId-$id";
    if (medicineNameCache.containsKey(cacheKey)) {
      return medicineNameCache[cacheKey];
    }

    final res = await http.get(
      Uri.parse("$baseUrl/medicine/by-id/$shopId/$id"),
    );

    if (res.statusCode == 200) {
      final name = jsonDecode(res.body)["name"];
      medicineNameCache[cacheKey] = name;
      return name;
    }
    return null;
  }

  Future<String?> fetchSupplierName(int id) async {
    if (shopId == null) return null;

    final cacheKey = "$shopId-$id";
    if (supplierNameCache.containsKey(cacheKey)) {
      return supplierNameCache[cacheKey];
    }

    final res = await http.get(
      Uri.parse("$baseUrl/suppliers/$shopId/$id"),
    );

    if (res.statusCode == 200) {
      final name = jsonDecode(res.body)["name"];
      supplierNameCache[cacheKey] = name;
      return name;
    }
    return null;
  }

  Map<String, double> calculateValues(Map<String, TextEditingController> r) {

    final qty = double.tryParse(r["Quantity"]?.text ?? "") ?? 0.0;
    final free = double.tryParse(r["Free_quantity"]?.text ?? "") ?? 0.0;
    final unit = double.tryParse(r["Unit"]?.text ?? "") ?? 1.0;
    final rate = double.tryParse(r["Rate_per_quantity"]?.text ?? "") ?? 0.0;
    final gst = double.tryParse(r["GST"]?.text ?? "") ?? 0.0;
    final profit = double.tryParse(r["Profit"]?.text ?? "") ?? 0.0;
    final mrp = double.tryParse(r["MRP"]?.text ?? "") ?? 0.0;


    final totalQty = qty + free;
    final totalStock = totalQty * unit;

    final baseAmount = qty * rate;
    final gstPerQty = rate * gst / 100;
    final totalGst = gstPerQty * qty;
    final purchasePrice = baseAmount + totalGst;

    final purchasePerQty = qty == 0.0 ? 0.0 : purchasePrice / qty;
    final purchasePerUnit = unit == 0.0 ? 0.0 : purchasePerQty / unit;

    var sellingPerQty =
        purchasePerQty + (purchasePerQty * profit / 100);

    if (mrp > 0 && sellingPerQty > mrp) {
      sellingPerQty = mrp;
    }

    final sellingPerUnit = unit == 0.0 ? 0.0 : sellingPerQty / unit;

    return {
      "totalQty": totalQty,
      "totalStock": totalStock,
      "gstPerQty": gstPerQty,
      "baseAmount": baseAmount,
      "totalGst": totalGst,
      "purchasePrice": purchasePrice,
      "purchasePerQty": purchasePerQty,
      "purchasePerUnit": purchasePerUnit,
      "sellingPrice": sellingPerQty,
      "sellingPerUnit": sellingPerUnit,
    };
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

  void recalcRow(int i) {
    final r = controllers[i];

    final qty = double.tryParse(r["Quantity"]!.text) ?? 0;
    final free = double.tryParse(r["Free_quantity"]!.text) ?? 0;
    final unit = double.tryParse(r["Unit"]!.text) ?? 1;
    final rate = double.tryParse(r["Rate_per_quantity"]!.text) ?? 0;
    final gst = double.tryParse(r["GST"]!.text) ?? 0;
    final profit = double.tryParse(r["Profit"]!.text) ?? 0;

    final totalQty = qty + free;
    final stock = totalQty * unit;
    final base = qty * rate;
    final gstAmt = base * gst / 100;
    final purchase = base + gstAmt;
    final sellQty = (purchase / qty) * (1 + profit / 100);

    setState(() {
      calculatedRows[i] = {
        "total_stock": stock,
        "purchase_price": purchase,
        "selling_price": sellQty,
      };
    });
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

  Future<void> submitAll() async {
    if (shopId == null) return;

    List<Map<String, dynamic>> batchPayload = [];

    for (int i = 0; i < controllers.length; i++) {
      final r = controllers[i];
      final calc = calculateValues(r);

      batchPayload.add({
        "medicine_id": int.parse(r["MEDICINE_ID"]!.text),
        "batch_no": r["Batch_no"]!.text,
        "rack_no": r["Rack_no"]?.text ?? "",
        "hsncode": r["HSN_code"]?.text ?? "",
        "mfg_date": r["MFG_Date"]?.text,
        "exp_date": r["EXP_Date"]?.text,
        "quantity": int.parse(r["Quantity"]!.text),
        "free_quantity": int.parse(r["Free_quantity"]!.text),
        "total_quantity": calc["totalQty"],
        "unit": int.parse(r["Unit"]!.text),
        "total_stock": calc["totalStock"],
        "mrp": double.parse(r["MRP"]!.text),
        "supplier_id": int.parse(r["Supplier_id"]!.text),
        "purchase_details": {
          "purchase_date": r["Purchase_Date"]!.text,
          "rate_per_quantity": double.parse(r["Rate_per_quantity"]!.text),
          "gst_percent": double.parse(r["GST"]!.text),
          "gst_per_quantity": calc["gstPerQty"],
          "base_amount": calc["baseAmount"],
          "total_gst_amount": calc["totalGst"],
          "purchase_price": calc["purchasePrice"],
        },
        "purchase_price_per_unit": calc["purchasePerUnit"],
        "purchase_price_per_quantity": calc["purchasePerQty"],
        "selling_price_per_unit": calc["sellingPerUnit"],
        "selling_price_per_quantity": calc["sellingPrice"],
        "profit_percent": double.parse(r["Profit"]!.text),
        "reason": "New Stock",
      });
    }

    final url = Uri.parse("$baseUrl/inventory/medicine/batch-upload"); // single bulk endpoint

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "shop_id": shopId,
        "batches": batchPayload, // all medicine batches inside JSON
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      _showMessage("Bulk upload completed");
    } else {
      _showMessage("Error during bulk upload: ${response.statusCode}");
    }
  }

  DataCell editableIdWithName({
    required TextEditingController controller,
    required Future<String?> Function(int) fetchName,
  }) {
    return DataCell(
      SizedBox(
        width: 130,
        child: Column(
          children: [
            TextField(
              cursorColor: royal,
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            ),
            FutureBuilder<String?>(
              future: int.tryParse(controller.text) != null
                  ? fetchName(int.parse(controller.text))
                  : null,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                return Text(
                  snapshot.data!,
                  style:  TextStyle(
                    fontSize: 11,
                    color: royal,
                  ),
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  DataCell editNumber(TextEditingController c) =>
      DataCell(
        SizedBox(
          width: 90,
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
            ),
            onChanged: (_) => setState(() {}),
          )

        ),
      );

  DataCell datePickerCell({
    required TextEditingController controller,
    required String label,
  }) {
    return DataCell(
      GestureDetector(
        onTap: () async {
          DateTime? initialDate;
          try {
            initialDate = DateTime.parse(controller.text);
          } catch (_) {
            initialDate = DateTime.now();
          }

          final pickedDate = await showDatePicker(
            context: context,
            initialDate: initialDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: royal, // header background
                    onPrimary: Colors.white, // header text color
                    onSurface: Colors.black, // body text color
                  ),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: royal, // button text color
                    ),
                  ),
                ),
                child: child!,
              );
            },
          );

          if (pickedDate != null) {
            controller.text = pickedDate.toIso8601String().split("T")[0]; // yyyy-MM-dd
            setState(() {});
          }
        },
        child: SizedBox(
          width: 100,
          child: Text(
            controller.text.isEmpty ? label : controller.text,
            style: TextStyle(
              color: controller.text.isEmpty ? Colors.grey : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  DataCell editInt(TextEditingController c) =>
      DataCell(
        SizedBox(
          width: 90,
          child: TextField(
            controller: c,
            cursorColor: royal,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      );

  DataCell editCurrency(TextEditingController c) => DataCell(
    SizedBox(
      width: 90,
      child: TextField(
        controller: c,
        cursorColor: royal,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')), // 2 decimals
        ],
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          prefixText: '₹', // Adds ₹ in front
        ),
        onChanged: (_) => setState(() {}),
      ),
    ),
  );

  DataCell editPercent(TextEditingController controller) => DataCell(
    SizedBox(
      width: 90,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              TextField(
                controller: controller,
                cursorColor: royal,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                ),
                style: const TextStyle(fontSize: 14),
                onChanged: (_) => setState(() {}),
              ),
              // Positioned % right after the typed text
              Positioned(
                left: _calculateTextWidth(controller.text, 14) + 2, // 2px padding
                top: 4,
                child: Text(
                  '%',
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  double _calculateTextWidth(String text, double fontSize) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize)),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.width;
  }

  DataCell view(double v) => DataCell(Text(v.toStringAsFixed(2)));

  DataCell viewInt(double v) => DataCell(Text(v.toInt().toString()));

  DataCell viewCurrency(double v) => DataCell(Text("₹${v.toStringAsFixed(2)}"));

  DataCell viewCurrencyInt(double v) => DataCell(Text("₹${v.toInt()}"));

  DataCell viewPercent(double v) => DataCell(Text("${v.toStringAsFixed(2)}%"));


  DataCell batchCell(
      TextEditingController controller,
      int medicineId,
      int rowIndex,
      ) {
    return DataCell(
      SizedBox(
        width: 120,
        child: TextField(
          controller: controller,
          cursorColor: royal,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            suffixIcon: batchAvailability[rowIndex] == null
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Icon(
              batchAvailability[rowIndex]! ? Icons.check_circle : Icons.error,
              color: batchAvailability[rowIndex]! ? Colors.green : Colors.red,
              size: 18,
            ),
          ),
          onChanged: (value) async {
            if (value.isEmpty || medicineId == 0) {
              batchAvailability[rowIndex] = null;
              setState(() {});
              return;
            }

            batchAvailability[rowIndex] = null; // ⏳ checking
            setState(() {});

            final isAvailable =
            await validateBatchBackend(medicineId, value.trim());

            // ✅ override old result safely
            if (controller.text.trim() == value.trim()) {
              batchAvailability[rowIndex] = isAvailable;
              setState(() {});
            }
          },
        ),
      ),
    );
  }

  bool get isSubmitEnabled {
    for (int i = 0; i < controllers.length; i++) {
      final r = controllers[i];

      // Medicine & Supplier validation
      final medicineValid =
      medicineNameCache.containsKey("$shopId-${r["MEDICINE_ID"]!.text}");
      final supplierValid =
      supplierNameCache.containsKey("$shopId-${r["Supplier_id"]!.text}");

      if (!medicineValid || !supplierValid) return false;

      // 🚨 Batch validation (THIS WAS MISSING)
      if (!batchAvailability.containsKey(i)) return false; // not checked yet
      if (batchAvailability[i] == null) return false; // still loading
      if (batchAvailability[i] == false) return false; // batch exists
    }

    return true;
  }

  Widget submitButton() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: royal,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
        onPressed: isSubmitEnabled
            ? () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Confirm Submission"),
              content: const Text("Have you checked all the values of the data?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: royal),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Confirm"),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            await submitAll();
          }
        }
            : null, // disabled if conditions not met
        child: const Text(
          "Submit Bulk Upload",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,color: Colors.white),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalController = ScrollController();
    final verticalController = ScrollController();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        foregroundColor: Colors.white,
        elevation: 2,
        title: const Text(
          "Bulk Batch Upload",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildHallCard(widget.shopDetails!)
          ),

          const Divider(height: 1),

          Expanded(
            child: Scrollbar(
              controller: verticalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: verticalController,
                child: Scrollbar(
                  controller: horizontalController,
                  thumbVisibility: true,
                  notificationPredicate: (n) =>
                  n.metrics.axis == Axis.horizontal,
                  child: SingleChildScrollView(
                    controller: horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: screenWidth + 800,
                      ),
                      child: DataTableTheme(
                        data: DataTableThemeData(
                          headingRowColor:
                          WidgetStateProperty.all(Colors.white),
                          headingTextStyle: const TextStyle(
                            color: royal,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          dataTextStyle: const TextStyle(
                            color: Colors.black,
                            fontSize: 13,
                          ),
                          dividerThickness: 1,
                        ),
                        child: DataTable(
                          columnSpacing: 16,
                          headingRowHeight: 48,
                          dataRowMinHeight: 46,
                          columns: const [
                            DataColumn(label: Text("Medicine")),
                            DataColumn(label: Text("Batch")),
                            DataColumn(label: Text("Rack")),
                            DataColumn(label: Text("HSN")),
                            DataColumn(label: Text("MFG")),
                            DataColumn(label: Text("EXP")),
                            DataColumn(label: Text("Qty")),
                            DataColumn(label: Text("Free")),
                            DataColumn(label: Text("Unit")),
                            DataColumn(label: Text("Rate")),
                            DataColumn(label: Text("GST%")),
                            DataColumn(label: Text("MRP")),
                            DataColumn(label: Text("Profit%")),
                            DataColumn(label: Text("Supplier")),
                            DataColumn(label: Text("Purchase Date")),
                            DataColumn(label: Text("Total Qty")),
                            DataColumn(label: Text("Total Stock")),
                            DataColumn(label: Text("GST Amount/Qty")),
                            DataColumn(label: Text("Base Amount")),
                            DataColumn(label: Text("Total GST")),
                            DataColumn(label: Text("Purchase Price")),
                            DataColumn(label: Text("Purchase Price/Unit")),
                            DataColumn(label: Text("Purchase Price/Qty")),
                            DataColumn(label: Text("Selling Price/Unit")),
                            DataColumn(label: Text("Selling Price/Qty")),
                          ],
                          rows: List.generate(controllers.length, (i) {
                            final r = controllers[i];
                            final calc = calculateValues(r);

                            DataCell edit(TextEditingController c) =>
                                DataCell(
                                  SizedBox(
                                    width: 90,
                                    child: TextField(
                                      controller: c,
                                      cursorColor: royal,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: InputBorder.none,
                                      ),
                                      onChanged: (_) =>
                                          setState(() {}),
                                    ),
                                  ),
                                );

                            return DataRow(cells: [
                              editableIdWithName(
                                controller: r["MEDICINE_ID"]!, // ✅ use the existing controller
                                fetchName: fetchMedicineName,
                              ),

                              batchCell(
                                r["Batch_no"]!,
                                int.tryParse(r["MEDICINE_ID"]!.text) ?? 0,
                                i,
                              ),
                              edit(r["Rack_no"]!),
                              edit(r["HSN_code"]!),
                              datePickerCell(controller: r["MFG_Date"]!, label: "MFG"),
                              datePickerCell(controller: r["EXP_Date"]!, label: "EXP"),
                              editInt(r["Quantity"]!),
                              editInt(r["Free_quantity"]!),
                              editInt(r["Unit"]!),
                              editCurrency(r["Rate_per_quantity"]!), // Rate
                              editPercent(r["GST"]!),               // GST %
                              editCurrency(r["MRP"]!),              // MRP
                              editPercent(r["Profit"]!),            // Profit %
                              editableIdWithName(
                                controller: r["Supplier_id"]!,
                                fetchName: fetchSupplierName,
                              ),
                              datePickerCell(controller: r["Purchase_Date"]!, label: "Purchase"),
                              viewInt(calc["totalQty"]!),
                              viewInt(calc["totalStock"]!),
                              viewCurrency(calc["gstPerQty"]!),           // GST Amount/Qty
                              viewCurrency(calc["baseAmount"]!),          // Base Amount
                              viewCurrency(calc["totalGst"]!),            // Total GST
                              viewCurrency(calc["purchasePrice"]!),       // Purchase Price
                              viewCurrency(calc["purchasePerQty"]!),      // Purchase Price/Qty
                              viewCurrency(calc["purchasePerUnit"]!),     // Purchase Price/Unit
                              viewCurrency(calc["sellingPerUnit"]!),      // Selling Price/Unit
                              viewCurrency(calc["sellingPrice"]!),    // Selling Price per Quantity
                            ]);
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          submitButton(), // Add this below DataTable

        ],
      ),
    );
  }
}
