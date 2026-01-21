import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/config.dart'; // baseUrl must be defined here
import 'package:flutter/services.dart' show rootBundle;
import '../../../../public/main_navigation.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class YearlyReportPage extends StatefulWidget {
  final int year;
  final Map<String, dynamic> shopDetails;

  const YearlyReportPage({
    super.key,
    required this.year,
    required this.shopDetails,
  });

  @override
  State<YearlyReportPage> createState() => _YearlyReportPageState();
}

class _YearlyReportPageState extends State<YearlyReportPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _incomes = [];
  List<Map<String, dynamic>> _filteredData = [];
  List<Map<String, dynamic>> _drawing = [];

  Map<String, Map<String, double>> _calculateMonthlyTotals() {
    // Initialize month map
    final months = List.generate(12, (i) => DateFormat('MMMM').format(DateTime(0, i + 1)));
    Map<String, Map<String, double>> monthlyData = {
      for (var month in months) month: {"income": 0, "expense": 0, "profit": 0}
    };

    for (var item in _filteredData) {
      final date = DateTime.tryParse(item["date"] ?? "");
      if (date != null) {
        final monthName = DateFormat('MMMM').format(date);
        final amount = double.tryParse(item["amount"].toString()) ?? 0;

        if (item["type"] == "Income") {
          monthlyData[monthName]!["income"] = monthlyData[monthName]!["income"]! + amount;
        } else {
          monthlyData[monthName]!["expense"] = monthlyData[monthName]!["expense"]! + amount;
        }

        monthlyData[monthName]!["profit"] =
            monthlyData[monthName]!["income"]! - monthlyData[monthName]!["expense"]!;
      }
    }

    return monthlyData;
  }


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
        _fetchDrawing(shopId)
      ]);
      _combineData();
    }

    setState(() => isLoading = false);
  }

  Future<void> _fetchExpenses(int shopId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/finance/expense/$shopId"));
      if (response.statusCode == 200) {
        _expenses = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error fetching expenses: $e");
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

  void _combineData() {
    List<Map<String, dynamic>> combined = [];
    final year = widget.year;
    combined.addAll(_incomes.where((inc) {
      final date = DateTime.tryParse(inc["created_at"] ?? "");
      return date != null && date.year == year;

    }).map((inc) => {
      "type": "Income",
      "title": inc["reason"] ?? "Income",
      "amount": inc["amount"] ?? 0,
      "date": inc["created_at"],
    }));

    // Expenses
    combined.addAll(_expenses.where((e) {
      final date = DateTime.tryParse(e["created_at"] ?? "");
      return date != null && date.year == year;
    }).map((e) => {
      "type": "Expense",
      "title": e["reason"] ?? "-",
      "amount": e["amount"] ?? 0,
      "date": e["created_at"],
    }));

    // Sort descending by date
    combined.sort((a, b) {
      DateTime da = DateTime.tryParse(a["date"] ?? "") ?? DateTime.now();
      DateTime db = DateTime.tryParse(b["date"] ?? "") ?? DateTime.now();
      return db.compareTo(da);
    });

    _filteredData = combined;
  }


  @override
  Widget build(BuildContext context) {
    final pdfFuture = _buildYearlyPdf();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Yearly Report",
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
                    Printing.sharePdf(bytes: pdfData, filename: "yearly_report.pdf");
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _buildYearlyPdf() async {
    final pdf = pw.Document();
    final tamilFont = pw.Font.ttf(await rootBundle.load("assets/fonts/NotoSansTamil-Regular.ttf"));
    final tamilFontBold = pw.Font.ttf(await rootBundle.load("assets/fonts/NotoSansTamil-Bold.ttf"));

    final royal = PdfColor.fromInt(0xFF19527A);
    // final beige = PdfColor.fromInt(0xFFECE5D8);

    // final totals = _calculateTotals();
    final shop = widget.shopDetails;
    // final now = DateTime.now();
    final monthlyTotals = _calculateMonthlyTotals();

// Calculate grand totals
    double totalIncome = 0;
    double totalExpense = 0;
    double totalProfit = 0;
    monthlyTotals.forEach((key, value) {
      totalIncome += value["income"] ?? 0;
      totalExpense += value["expense"] ?? 0;
      totalProfit += value["profit"] ?? 0;
    });
    // Calculate total Drawing In and Out for selected year
    final drawingFiltered = _drawing.where((d) {
      final date = DateTime.tryParse(d["created_at"] ?? "");
      return date != null && date.year == widget.year;
    });

    final totalDrawingIn = drawingFiltered
        .where((d) => d["type"].toString().toLowerCase() == "drawin")
        .fold<double>(0, (sum, d) => sum + (double.tryParse(d["amount"].toString()) ?? 0));

    final totalDrawingOut = drawingFiltered
        .where((d) => d["type"].toString().toLowerCase() == "drawout")
        .fold<double>(0, (sum, d) => sum + (double.tryParse(d["amount"].toString()) ?? 0));

// ✅ New balance formula
    final balance = totalIncome + totalDrawingIn - totalExpense- totalDrawingOut;
// Calculate monthly drawing in/out
    Map<String, Map<String, double>> monthlyDrawings = {
      for (var m in List.generate(12, (i) => DateFormat('MMMM').format(DateTime(0, i + 1))))
        m: {"drawin": 0, "drawout": 0}
    };

    for (var d in _drawing) {
      final date = DateTime.tryParse(d["created_at"] ?? "");
      if (date != null && date.year == widget.year) {
        final monthName = DateFormat('MMMM').format(date);
        final amount = double.tryParse(d["amount"].toString()) ?? 0;
        final type = d["type"].toString().toLowerCase();

        if (type == "drawin") {
          monthlyDrawings[monthName]!["drawin"] =
              monthlyDrawings[monthName]!["drawin"]! + amount;
        } else if (type == "drawout") {
          monthlyDrawings[monthName]!["drawout"] =
              monthlyDrawings[monthName]!["drawout"]! + amount;
        }
      }
    }

// === Calculate Opening Balance until last year ===
    double previousIncome = 0;
    double previousExpense = 0;
    double previousDrawingIn = 0;
    double previousDrawingOut = 0;

// --- Incomes ---
    for (var inc in _incomes) {
      final date = DateTime.tryParse(inc["created_at"] ?? "");
      if (date != null && date.year < widget.year) {
        previousIncome += double.tryParse(inc["amount"].toString()) ?? 0;
      }
    }

// --- Expenses ---
    for (var e in _expenses) {
      final date = DateTime.tryParse(e["created_at"] ?? "");
      if (date != null && date.year < widget.year) {
        previousExpense += double.tryParse(e["amount"].toString()) ?? 0;
      }
    }

// --- Drawings ---
    for (var d in _drawing) {
      final date = DateTime.tryParse(d["created_at"] ?? "");
      if (date != null && date.year < widget.year) {
        final amount = double.tryParse(d["amount"].toString()) ?? 0;
        if (d["type"].toString().toLowerCase() == "in") {
          previousDrawingIn += amount;
        } else if (d["type"].toString().toLowerCase() == "out") {
          previousDrawingOut += amount;
        }
      }
    }

// ✅ Opening balance carried forward from previous years
    final previousBalance = previousIncome + previousDrawingIn - previousExpense - previousDrawingOut;
    final currentBalance = previousBalance + balance;

    // final formattedNow = DateFormat('yyyyMMddHHmm').format(now);
    Uint8List? shopLogo;
    if (shop['logo'] != null) {
      shopLogo = base64Decode(shop['logo']);
    }

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

          // Report title
          pw.Center(
            child: pw.Text("YEARLY REPORT - ${widget.year}",
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: royal)),
          ),
          pw.SizedBox(height: 20),

          if (_filteredData.isEmpty)
            pw.Center(child: pw.Text("No transactions for this year.", style: pw.TextStyle(font: tamilFont,fontSize: 9)))
          else
            pw.TableHelper.fromTextArray(
              headers: ["Month", "Income", "Expense", "Profit/Loss", "Drawing In", "Drawing Out"],
              headerStyle: pw.TextStyle(
                font: tamilFontBold,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(color: royal),
              cellStyle: pw.TextStyle(font: tamilFont, fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              data: [
                ...monthlyTotals.entries.map((entry) {
                  final month = entry.key;
                  final income = entry.value["income"] ?? 0;
                  final expense = entry.value["expense"] ?? 0;
                  final profit = entry.value["profit"] ?? 0;
                  final drawIn = monthlyDrawings[month]?["in"] ?? 0;
                  final drawOut = monthlyDrawings[month]?["out"] ?? 0;

                  return [
                    month,
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text("₹${income.toStringAsFixed(2)}",style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                    ),
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text("₹${expense.toStringAsFixed(2)}",style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                    ),
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text("₹${profit.toStringAsFixed(2)}",style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                    ),
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text("₹${drawIn.toStringAsFixed(2)}",style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                    ),
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text("₹${drawOut.toStringAsFixed(2)}",style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                    ),
                  ];
                }),
                // Total row
                [
                  pw.Text("TOTAL", style: pw.TextStyle(font: tamilFontBold, fontSize: 9)),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text("₹${totalIncome.toStringAsFixed(2)}",
                        style: pw.TextStyle(font: tamilFontBold, fontSize: 9)),
                  ),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text("₹${totalExpense.toStringAsFixed(2)}",
                        style: pw.TextStyle(font: tamilFontBold, fontSize: 9)),
                  ),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text("₹${totalProfit.toStringAsFixed(2)}",
                        style: pw.TextStyle(font: tamilFontBold, fontSize: 9)),
                  ),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text("₹${totalDrawingIn.toStringAsFixed(2)}",
                        style: pw.TextStyle(font: tamilFontBold, fontSize: 9)),
                  ),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text("₹${totalDrawingOut.toStringAsFixed(2)}",
                        style: pw.TextStyle(font: tamilFontBold, fontSize: 9)),
                  ),
                ]
              ],
            ),

          pw.SizedBox(height: 20),
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
                  "Yearly Summary",
                  style: pw.TextStyle(
                    font: tamilFontBold,
                    fontSize: 10,
                    color: royal,
                  ),
                ),
                pw.SizedBox(height: 6),
                // pw.Row(
                //   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                //   children: [
                //     pw.Text("Total Income:", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                //     pw.Text("₹${totalIncome.toStringAsFixed(2)}", style: pw.TextStyle(font: tamilFontBold, fontSize: 9)),
                //   ],
                // ),
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
                    pw.Text("Total Profit:", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                    pw.Text("₹${totalProfit.toStringAsFixed(2)}", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Total Drawing In:", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                    pw.Text("₹${totalDrawingIn.toStringAsFixed(2)}", style: pw.TextStyle(font: tamilFont, fontSize: 9)),
                  ],
                ),
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
                    pw.Text("Balance:",
                        style: pw.TextStyle(font: tamilFontBold, fontSize: 9, color: royal)),
                    pw.Text("₹${balance.toStringAsFixed(2)}",
                        style: pw.TextStyle(font: tamilFontBold, fontSize: 9, color: royal)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Previous Balance:",
                        style: pw.TextStyle(font: tamilFontBold, fontSize: 9, color: royal)),
                    pw.Text("₹${previousBalance.toStringAsFixed(2)}",
                        style: pw.TextStyle(font: tamilFontBold, fontSize: 9, color: royal)),
                  ],
                ),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Current Balance:",
                        style: pw.TextStyle(font: tamilFontBold, fontSize: 9, color: royal)),
                    pw.Text("₹${currentBalance.toStringAsFixed(2)}",
                        style: pw.TextStyle(font: tamilFontBold, fontSize: 9, color: royal)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 35),
          // Signature
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
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
