import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../public/config.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../../../public/main_navigation.dart';

const Color royal = Color(0xFF875C3F);

class DailyReportPage extends StatefulWidget {
  final DateTime date;
  final Map<String, dynamic> shopDetails;

  const DailyReportPage({
    super.key,
    required this.date,
    required this.shopDetails,
  });

  @override
  State<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _filteredData = [];
  List<Map<String, dynamic>> _incomes = [];
  List<Map<String, dynamic>> _drawing = [];


  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");

    if (shopId != null) {
      await Future.wait([
        _fetchExpenses(shopId),
        _fetchIncomes(shopId),
        _fetchDrawing(shopId),
      ]);
      _combineData();
    }
    setState(() => isLoading = false);
  }

  Future<void> _fetchIncomes(int shopId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/finance/income/$shopId"));
      if (response.statusCode == 200) {
        _incomes = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("❌ Error fetching incomes: $e");
    }
  }

  Future<void> _fetchDrawing(int shopId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/finance/drawing/$shopId"));
      if (response.statusCode == 200) {
        _drawing = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("❌ Error fetching drawing: $e");
    }
  }

  Future<void> _fetchExpenses(int shopId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/finance/expenses/$shopId"));
      if (response.statusCode == 200) {
        _expenses = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error fetching expenses: $e");
    }
  }

  void _combineData() {
    List<Map<String, dynamic>> combined = [];

    final selectedDate = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
    );

    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    // INCOME
    combined.addAll(_incomes.where((inc) {
      final d = DateTime.tryParse(inc["created_at"] ?? "");
      return d != null && isSameDay(d, selectedDate);
    }).map((inc) => {
      "type": "Income",
      "title": inc["reason"] ?? "Income",
      "amount": inc["amount"] ?? 0,
      "date": inc["created_at"],
    }));

    // EXPENSE
    combined.addAll(_expenses.where((e) {
      final d = DateTime.tryParse(e["created_at"] ?? "");
      return d != null && isSameDay(d, selectedDate);
    }).map((e) => {
      "type": "Expense",
      "title": e["reason"] ?? "-",
      "amount": e["amount"] ?? 0,
      "date": e["created_at"],
    }));

    combined.sort((a, b) {
      final da = DateTime.tryParse(a["date"] ?? "") ?? DateTime.now();
      final db = DateTime.tryParse(b["date"] ?? "") ?? DateTime.now();
      return da.compareTo(db);
    });

    _filteredData = combined;
  }

  Map<String, double> _calculateTotals() {
    double totalIncome = 0;
    double totalExpense = 0;

    for (var item in _filteredData) {
      final amount = double.tryParse(item["amount"].toString()) ?? 0;
      if (item["type"] == "Income") {
        totalIncome += amount;
      } else if (item["type"] == "Expense") {
        totalExpense += amount;
      }
    }

    return {"income": totalIncome, "expense": totalExpense};
  }

  @override
  Widget build(BuildContext context) {
    final pdfFuture = _buildDailyPdf();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Daily Report",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: royal,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: 0)),
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: FutureBuilder<Uint8List>(
        future: pdfFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error generating PDF: ${snapshot.error}"));
          } else {
            final pdfData = snapshot.data!;
            return PdfPreview(
              build: (format) => pdfData,
              allowPrinting: false,
              allowSharing: false,
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
            );
          }
        },
      ),

    bottomNavigationBar: SafeArea(
        child: Container(
          color: royal,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: royal,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.print),
                label: const Text("Print"),
                onPressed: () {
                  pdfFuture.then((pdfData) {
                    Printing.layoutPdf(onLayout: (format) async => pdfData);
                  });
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: royal,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.share),
                label: const Text("Share"),
                onPressed: () {
                  pdfFuture.then((pdfData) {
                    Printing.sharePdf(bytes: pdfData, filename: "dailyreport.pdf");
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _buildDailyPdf() async {
    final pdf = pw.Document();
    final tamilFont = pw.Font.ttf(await rootBundle.load("assets/fonts/NotoSansTamil-Regular.ttf"));
    final tamilFontBold = pw.Font.ttf(await rootBundle.load("assets/fonts/NotoSansTamil-Bold.ttf"));

    final royal = PdfColor.fromInt(0xFF19527A);
    final beige = PdfColor.fromInt(0xFFAAD8EA);

    final totals = _calculateTotals();
    final selectedDate = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
    );
    // ✅ Use the passed-in date for label
    final dateLabel = DateFormat('dd-MM-yyyy').format(selectedDate);

    final shop = widget.shopDetails;

    Uint8List? shopLogo;
    if (shop['logo'] != null) {
      shopLogo = base64Decode(shop['logo']);
    }
// --- Summary Section ---
    final totalIncome = totals["income"] ?? 0;
    final totalExpense = totals["expense"] ?? 0;

// Calculate total drawing for selected month
    // Calculate total Drawing In and Out for selected month


    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    final drawingFiltered = _drawing.where((d) {
      final date = DateTime.tryParse(d["created_at"] ?? "");
      return date != null && isSameDay(date, selectedDate);
    });


    final totalDrawingIn = drawingFiltered
        .where((d) => d["type"].toString().toLowerCase() == "drawin")
        .fold<double>(0, (sum, d) => sum + (double.tryParse(d["amount"].toString()) ?? 0));

    final totalDrawingOut = drawingFiltered
        .where((d) => d["type"].toString().toLowerCase() == "drawout")
        .fold<double>(0, (sum, d) => sum + (double.tryParse(d["amount"].toString()) ?? 0));

// ✅ New balance formula

    final combinedData = [
      ..._filteredData.map((tx) => {
        "date": tx["date"],
        "particular": tx["title"],
        "income": tx["type"] == "Income" ? tx["amount"] : 0.0,
        "expense": tx["type"] == "Expense" ? tx["amount"] : 0.0,
        "drawingIn": 0.0,
        "drawingOut": 0.0,
      }),
    ...drawingFiltered.map((d) => {
        "date": d["created_at"],
        "particular":
        "${d["reason"] ?? "-"}",
        "income": 0.0,
        "expense": 0.0,
        "drawingIn": d["type"].toString().toLowerCase() == "drawin" ? d["amount"] : 0.0,
        "drawingOut": d["type"].toString().toLowerCase() == "drawout" ? d["amount"] : 0.0,
      }),
    ];

// Sort all by date ascending
    combinedData.sort((a, b) {
      final da = DateTime.tryParse(a["date"] ?? "") ?? DateTime(2000);
      final db = DateTime.tryParse(b["date"] ?? "") ?? DateTime(2000);
      return da.compareTo(db);
    });

    // === Calculate Opening (Previous) Balance ===
    final selectedDateStart = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
    );

    double previousIncome = 0;
    double previousExpense = 0;
    double previousDrawingIn = 0;
    double previousDrawingOut = 0;

// ---- Incomes ----
    for (var inc in _incomes) {
      final date = DateTime.tryParse(inc["created_at"] ?? "");
      if (date != null && date.isBefore(selectedDateStart)) {
        previousIncome += double.tryParse(inc["amount"].toString()) ?? 0;
      }
    }


    for (var e in _expenses) {
      final date = DateTime.tryParse(e["created_at"] ?? "");
      if (date != null && date.isBefore(selectedDateStart)) {
        previousExpense += double.tryParse(e["amount"].toString()) ?? 0;
      }
    }

// ---- Drawings ----
    for (var d in _drawing) {
      final date = DateTime.tryParse(d["created_at"] ?? "");
      if (date != null && date.isBefore(selectedDateStart)) {
        final amount = double.tryParse(d["amount"].toString()) ?? 0;
        if (d["type"].toString().toLowerCase() == "drawin") {
          previousDrawingIn += amount;
        } else if (d["type"].toString().toLowerCase() == "drawout") {
          previousDrawingOut += amount;
        }
      }
    }

// ✅ Opening balance till previous month
    final openingBalance = previousIncome + previousDrawingIn - previousExpense - previousDrawingOut;
    final balance = openingBalance + totalIncome + totalDrawingIn - totalExpense - totalDrawingOut;

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: tamilFont, bold: tamilFontBold),
        build: (context) => [

          // Header
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (shopLogo != null)
                pw.Image(pw.MemoryImage(shopLogo), width: 70, height: 70),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      shop['name']?.toString().toUpperCase() ?? 'SHOP NAME',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        font: tamilFontBold,
                        color: royal,
                      ),
                    ),
                    if ((shop['address'] ?? '').toString().isNotEmpty)
                      pw.Text(shop['address'], style: pw.TextStyle(font: tamilFont)),
                    if ((shop['phone'] ?? '').toString().isNotEmpty)
                      pw.Text('Phone: ${shop['phone']}', style: pw.TextStyle(font: tamilFont)),
                    if ((shop['email'] ?? '').toString().isNotEmpty)
                      pw.Text('Email: ${shop['email']}', style: pw.TextStyle(font: tamilFont)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Center(
            child: pw.Text(
              "DAILY REPORT - $dateLabel",
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: royal,
              ),
            ),
          ),

          pw.SizedBox(height: 20),


          if (_filteredData.isEmpty)
            pw.Center(child: pw.Text("No transactions for this day.", style: pw.TextStyle(font: tamilFont,fontSize: 9)))
          else
            pw.TableHelper.fromTextArray(
              headers: ["S.No", "Particular", "Income", "Expense", "Drawing In", "Drawing Out"],
              headerStyle: pw.TextStyle(
                font: tamilFontBold,
                fontSize: 9,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: pw.BoxDecoration(color: royal),
              cellStyle: pw.TextStyle(
                font: tamilFont,
                fontSize: 9,
                color: PdfColors.black,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignment: pw.Alignment.centerLeft,
              rowDecoration: pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: pw.BoxDecoration(color: beige),

              data: List.generate(combinedData.length, (index) {
                final item = combinedData[index];
                String formatAmount(dynamic v) {
                  if (v == null) return "-";
                  final val = double.tryParse(v.toString()) ?? 0.0;
                  return val != 0.0 ? "₹${val.toStringAsFixed(2)}" : "-";
                }

                return [
                  (index + 1).toString(),
                  // pw.Align(
                  //   alignment: pw.Alignment.center,
                  //   child: pw.Text(
                  //     date != null ? DateFormat('dd-MM-yyyy').format(date) : "-",
                  //     style: pw.TextStyle(fontSize: 8), // smaller date font
                  //   ),
                  // ),
                  // Particular: normal readable size
                  pw.Text(
                    item["particular"] ?? "-",
                    style: pw.TextStyle(fontSize: 9),
                  ),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      formatAmount(item["income"]),
                      style: pw.TextStyle(fontSize: 8), // smaller amount font
                    ),
                  ),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      formatAmount(item["expense"]),
                      style: pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      formatAmount(item["drawingIn"]),
                      style: pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      formatAmount(item["drawingOut"]),
                      style: pw.TextStyle(fontSize: 8),
                    ),
                  ),
                ];
              }),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(4.3), // more space for Particular
                2: const pw.FlexColumnWidth(1.6),
                3: const pw.FlexColumnWidth(1.6),
                4: const pw.FlexColumnWidth(1.6),
                5: const pw.FlexColumnWidth(1.7),
              },
            ),
          if (_filteredData.isNotEmpty)
            pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: pw.Row(
              children: [
                // TOTAL label
                pw.Expanded(
                  flex: 8,
                  child: pw.Align(
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      "TOTAL",
                      style: pw.TextStyle(
                        font: tamilFontBold,
                        fontSize: 9,
                        color: royal,
                      ),
                    ),
                  ),
                ),

                // Income total
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    "₹${totals["income"]?.toStringAsFixed(2) ?? '0.00'}",
                    style: pw.TextStyle(
                      font: tamilFontBold,
                      color: royal,
                      fontSize: 8,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),

                // Expense total
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    "₹${totals["expense"]?.toStringAsFixed(2) ?? '0.00'}",
                    style: pw.TextStyle(
                      font: tamilFontBold,
                      color: royal,
                      fontSize: 8,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),

                // Drawing In total
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    "₹${totalDrawingIn.toStringAsFixed(2) }",
                    style: pw.TextStyle(
                      font: tamilFontBold,
                      color: royal,
                      fontSize: 8,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),

                // Drawing Out total
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    "₹${totalDrawingOut.toStringAsFixed(2) }",
                    style: pw.TextStyle(
                      font: tamilFontBold,
                      color: royal,
                      fontSize: 8,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          ),



          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: royal, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "Daily Summary",
                  style: pw.TextStyle(
                    font: tamilFontBold,
                    fontSize: 10,
                    color: royal,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Previous Balance:", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                    pw.Text("₹${openingBalance.toStringAsFixed(2)}", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Total Income:", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                    pw.Text("₹${totalIncome.toStringAsFixed(2)}", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Total Expense:", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                    pw.Text("₹${totalExpense.toStringAsFixed(2)}", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Total Drawing In:", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                    pw.Text("₹${totalDrawingIn.toStringAsFixed(2)}", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Total Drawing Out:", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                    pw.Text("₹${totalDrawingOut.toStringAsFixed(2)}", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                  ],
                ),

                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Balance :",
                        style: pw.TextStyle(font: tamilFontBold, fontSize: 9, color: royal)),
                    pw.Text("₹${balance.toStringAsFixed(2)}",
                        style: pw.TextStyle(font: tamilFontBold, fontSize: 9, color: royal)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 35),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end, // align children to the right
            children: [
              pw.Column(
                children: [
                  pw.Container(width: 120, height: 1, color: PdfColors.grey),
                  pw.Text(
                    'Signature',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        font: tamilFontBold,
                        fontSize: 9
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }
}
