import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import '../../services/config.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart'; // ✅ For kIsWeb

const Color royal = Color(0xFF875C3F);

class BulkUploadExistBatchPage extends StatefulWidget {
  const BulkUploadExistBatchPage({super.key});

  @override
  State<BulkUploadExistBatchPage> createState() => _BulkUploadExistBatchPageState();
}

class _BulkUploadExistBatchPageState extends State<BulkUploadExistBatchPage> {
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
    try {
      final data = await rootBundle.load('assets/medicine_exist_batch.xlsx');
      final bytes = data.buffer.asUint8List();

      final savedPath = await FileSaver.instance.saveFile(
        name: 'medicine_exist_batch.xlsx', // 👈 include extension in name
        bytes: bytes,
        mimeType: MimeType.microsoftExcel,
      );

      _showMessage("Template downloaded successfully\n$savedPath");
    } catch (e) {
      _showMessage("Download failed: $e");
    }
  }


  Future<List<Map<String, dynamic>>> parseExcelBytes(Uint8List bytes) async {
    final ex = excel.Excel.decodeBytes(bytes);

    List<Map<String, dynamic>> rows = [];

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
        return date.toIso8601String().split("T")[0]; // yyyy-MM-dd
      } catch (_) {
        return "";
      }
    }

    for (var sheet in ex.tables.values) {
      for (var row in sheet.rows.skip(1)) {
        dynamic cell(int index) => index < row.length ? row[index]?.value : null;

        String mfg = formatDate(cell(4));
        String exp = formatDate(cell(3));
        int toInt(dynamic v) => int.tryParse(v?.toString() ?? "") ?? 0;
        double toDouble(dynamic v) => double.tryParse(v?.toString() ?? "") ?? 0.0;

        rows.add({
          "MEDICINE_ID": cell(0),
          "Batch_no": cell(1),
          "Rack_no": cell(2),
          "EXP_Date": exp,
          "MFG_Date": mfg,
          "Total_Stock": toInt(cell(5)),
          "Unit": toInt(cell(6)),
          "Selling_Price_Quantity": toDouble(cell(7)),
          "Selling_Price_Unit": toDouble(cell(8)),
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
        withData: true, // needed for web
      );

      if (result == null) {
        _showMessage("No file selected");
        return;
      }

      Uint8List bytes; // ✅ must be Uint8List

      if (kIsWeb) {
        // On web, bytes are already Uint8List
        bytes = result.files.single.bytes!;
      } else {
        // On mobile/desktop, convert List<int> to Uint8List
        final path = result.files.single.path;
        if (path == null) {
          _showMessage("Invalid file path");
          return;
        }
        final file = File(path);
        final fileBytes = await file.readAsBytes(); // List<int>
        bytes = Uint8List.fromList(fileBytes);      // ✅ convert to Uint8List
      }

      final rows = await parseExcelBytes(bytes); // works perfectly now

      if (rows.isEmpty) {
        _showMessage("Excel file is empty");
        return;
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BulkBatchExistUpload(
            batches: rows,
            shopDetails: shopDetails,
          ),
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

class BulkBatchExistUpload extends StatefulWidget {
  final List<Map<String, dynamic>> batches;
  final Map<String, dynamic>? shopDetails;

  const BulkBatchExistUpload({
    super.key,
    required this.batches,
    required this.shopDetails,
  });

  @override
  State<BulkBatchExistUpload> createState() => _BulkBatchExistUploadState();
}

class _BulkBatchExistUploadState extends State<BulkBatchExistUpload> {
  late List<Map<String, TextEditingController>> controllers;
  late List<Map<String, dynamic>> calculatedRows;
  Map<String, String> medicineNameCache = {};
  Map<int, bool?> batchAvailability = {};
  Map<int, String?> lastEditedField = {};

  int? shopId;

  @override
  void initState() {
    super.initState();
    shopId = int.tryParse(widget.shopDetails?['shop_id']?.toString() ?? '');

    calculatedRows = List.generate(widget.batches.length, (_) => {});

    // ✅ INITIALIZE batchAvailability FOR ALL ROWS
    for (int i = 0; i < widget.batches.length; i++) {
      batchAvailability[i] = false;
    }

    controllers = widget.batches.map((row) {
      return {
        "MEDICINE_ID": TextEditingController(text: row["MEDICINE_ID"]?.toString() ?? ""),
        "Batch_no": TextEditingController(text: row["Batch_no"]?.toString() ?? ""),
        "Rack_no": TextEditingController(text: row["Rack_no"]?.toString() ?? ""),
        "EXP_Date": TextEditingController(text: row["EXP_Date"]?.toString() ?? ""),
        "MFG_Date": TextEditingController(text: row["MFG_Date"]?.toString() ?? ""),
        "Total_Stock": TextEditingController(text: row["Total_Stock"]?.toString() ?? ""),
        "Unit": TextEditingController(text: row["Unit"]?.toString() ?? ""),
        "sellingPrice": TextEditingController(text: row["Selling_Price_Quantity"]?.toString() ?? ""),
        "sellingPerUnit": TextEditingController(text: row["Selling_Price_Unit"]?.toString() ?? ""),
      };
    }).toList();
    calculatedRows = List.generate(
      controllers.length,
          (_) => <String, dynamic>{},
    );
    for (int i = 0; i < controllers.length; i++) {
      if (controllers[i]["sellingPrice"]!.text.isNotEmpty &&
          (double.tryParse(controllers[i]["sellingPrice"]!.text) ?? 0) > 0) {
        lastEditedField[i] = "qty";
        calculateRow(i);
      }
    }

    _postInitTasks(); // ✅ only once

  }
  void calculateRow(int i) {
    final r = controllers[i];
    final result = calculateValues(r, i);

    setState(() {
      calculatedRows[i] = result;
    });
  }

  Future<void> _postInitTasks() async {
    if (shopId == null) return;

    for (int i = 0; i < controllers.length; i++) {
      final batch = controllers[i]["Batch_no"]!.text.trim();
      final medId = int.tryParse(controllers[i]["MEDICINE_ID"]!.text);

      if (batch.isNotEmpty && medId != null) {
        setState(() => batchAvailability[i] = null); // loading

        final result = await validateBatchBackend(medId, batch);

        if (!mounted) return;
        setState(() => batchAvailability[i] = result);
      }
    }

    for (final r in controllers) {
      final medId = int.tryParse(r["MEDICINE_ID"]!.text);

      if (medId != null) await fetchMedicineName(medId);
    }

    if (mounted) setState(() {});
  }

  Future<bool> validateBatchBackend(int medicineId, String batchNo) async {
    if (shopId == null || batchNo.isEmpty) {
      return false; // ❌ no exception
    }

    try {
      final res = await http.get(
        Uri.parse(
          "$baseUrl/inventory/medicine/$shopId/$medicineId/validate-batch?batch_no=$batchNo",
        ),
      );

      if (res.statusCode != 200 && res.statusCode != 201) {
        return false;
      }

      final data = jsonDecode(res.body);
      return data["is_valid"] == true;
    } catch (e) {
      return false; // network / parse error
    }
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


  Map<String, dynamic> calculateValues(
      Map<String, TextEditingController> r,
      int rowIndex,
      ) {
    final totalStock = int.tryParse(r["Total_Stock"]?.text ?? "0") ?? 0;
    final unit = int.tryParse(r["Unit"]?.text ?? "1") ?? 1;

    final sellingPrice =
        double.tryParse(r["sellingPrice"]?.text ?? "0") ?? 0.0;
    final sellingPerUnit =
        double.tryParse(r["sellingPerUnit"]?.text ?? "0") ?? 0.0;

    // ✅ quantity = ceil logic
    final totalQty =
    unit > 0 ? (totalStock / unit).ceil() : totalStock;

    double updatedSellingPrice = sellingPrice;
    double updatedSellingPerUnit = sellingPerUnit;

    final edited = lastEditedField[rowIndex];

    if (edited == "unit" && sellingPerUnit > 0) {
      updatedSellingPrice =
          truncateTo2Decimals(sellingPerUnit * unit);
      r["sellingPrice"]!.text = updatedSellingPrice.toString();
    }

    if (edited == "qty" && sellingPrice > 0 && unit > 0) {
      updatedSellingPerUnit =
          truncateTo2Decimals(sellingPrice / unit);
      r["sellingPerUnit"]!.text = updatedSellingPerUnit.toString();
    }

    return {
      "totalStock": totalStock,
      "totalQty": totalQty,
      "sellingPrice": updatedSellingPrice,
      "sellingPerUnit": updatedSellingPerUnit,
    };
  }
  double truncateTo2Decimals(double value) {
    return (value * 100).truncate() / 100;
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

  Future<void> submitAll() async {
    if (shopId == null) return;

    List<Map<String, dynamic>> batchPayload = [];

    for (int i = 0; i < controllers.length; i++) {
      final r = controllers[i];
      final calc = calculateValues(r, i);

      batchPayload.add({
        "medicine_id": int.parse(r["MEDICINE_ID"]!.text),
        "batch_no": r["Batch_no"]!.text,
        "rack_no": r["Rack_no"]?.text ?? "",
        "mfg_date": r["MFG_Date"]?.text,
        "exp_date": r["EXP_Date"]?.text,
        "total_stock": int.tryParse(r["Total_Stock"]!.text) ?? 0,
        "total_quantity": calc["totalQty"],
        "unit": int.parse(r["Unit"]!.text),
        "selling_price_per_unit": calc["sellingPerUnit"],
        "selling_price_per_quantity": calc["sellingPrice"],
      });
    }

    final url = Uri.parse("$baseUrl/inventory/medicine/batch-upload-exist"); // single bulk endpoint

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

      if (!mounted) return;
      Navigator.pop(context);
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

  DataCell editInt(
      TextEditingController c,
      int rowIndex,
      ) =>
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
            onChanged: (_) {
              calculateRow(rowIndex); // 🔥 force recalculation
            },
          ),
        ),
      );

  DataCell viewInt(int v) => DataCell(Text(v.toString()));

  DataCell editCurrency(
      TextEditingController c,
      int rowIndex,
      String field, // "qty" or "unit"
      ) =>
      DataCell(
        SizedBox(
          width: 90,
          child: TextField(
            controller: c,
            cursorColor: royal,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d+\.?\d{0,2}'),
              ),
            ],
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              prefixText: '₹',
            ),
            onChanged: (_) {
              lastEditedField[rowIndex] = field;
              calculateRow(rowIndex);
            },
          ),
        ),
      );



  DataCell view(double v) => DataCell(Text(v.toStringAsFixed(2)));


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
              batchAvailability[rowIndex]!
                  ? Icons.check_circle
                  : Icons.error,
              color: batchAvailability[rowIndex]!
                  ? Colors.green
                  : Colors.red,
              size: 18,
            ),
          ),
          onChanged: (value) async {
            if (value.isEmpty || medicineId == 0) {
              setState(() {
                batchAvailability[rowIndex] = false;
              });
              return;
            }

            setState(() {
              batchAvailability[rowIndex] = null; // ⏳ checking
            });

            final isAvailable =
            await validateBatchBackend(medicineId, value.trim());

            if (!mounted) return;

            if (controller.text.trim() == value.trim()) {
              setState(() {
                batchAvailability[rowIndex] = isAvailable;
              });
            }
          },
        ),
      ),
    );
  }
  bool isRowValid(int i) {
    final r = controllers[i];
    final calc = calculateValues(r, i);

    bool notEmpty(String key) =>
        r[key] != null && r[key]!.text.trim().isNotEmpty;

    int toInt(String key) =>
        int.tryParse(r[key]?.text ?? "") ?? 0;

    double toDouble(String key) =>
        double.tryParse(r[key]?.text ?? "") ?? 0;
    final medicineValid =
    medicineNameCache.containsKey("$shopId-${r["MEDICINE_ID"]!.text}");

    if (!medicineValid ) return false;

    // 🚨 Batch validation (THIS WAS MISSING)
    if (!batchAvailability.containsKey(i)) return false; // not checked yet
    if (batchAvailability[i] == null) return false; // still loading
    if (batchAvailability[i] == false) return false; // batch exists

    return
      // ✅ medicine name must be valid
          // ❗ REQUIRED fields (except NDC)
          notEmpty("Rack_no") &&

          notEmpty("MFG_Date") &&
          notEmpty("EXP_Date") &&

          toInt("Total_Stock") > 0 &&
          toInt("Unit") > 0 &&

          toDouble("sellingPrice") > 0 &&
          toDouble("sellingPerUnit") > 0 &&

          // ✅ calculated value
          (calc["totalQty"] ?? 0) > 0;
  }

  bool get isSubmitEnabled {
    for (int i = 0; i < controllers.length; i++) {
      if (!isRowValid(i)) return false;
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
                  child: const Text("Cancel",style: TextStyle(color: royal),),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: royal),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Confirm",style: TextStyle(color: Colors.white),),
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
                            DataColumn(label: Text("Medicine ID")),
                            DataColumn(label: Text("Batch")),
                            DataColumn(label: Text("Rack")),
                            DataColumn(label: Text("MFG")),
                            DataColumn(label: Text("EXP")),
                            DataColumn(label: Text("Total Stock")),
                            DataColumn(label: Text("Unit")),
                            DataColumn(label: Text("Total Qty")),
                            DataColumn(label: Text("Selling Price/Qty")),
                            DataColumn(label: Text("Selling Price/Unit")),
                          ],
                          rows: List.generate(controllers.length, (i) {
                            final r = controllers[i];
                            final calc = calculatedRows[i].isNotEmpty
                                ? calculatedRows[i]
                                : (calculatedRows[i] = calculateValues(r, i));

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
                              datePickerCell(controller: r["MFG_Date"]!, label: "MFG"),
                              datePickerCell(controller: r["EXP_Date"]!, label: "EXP"),
                              editInt(r["Total_Stock"]!,i),
                              editInt(r["Unit"]!,i),
                              viewInt(calc["totalQty"]!),
                              editCurrency(r["sellingPrice"]!, i, "qty"),
                              editCurrency(r["sellingPerUnit"]!, i, "unit"), ]);
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
