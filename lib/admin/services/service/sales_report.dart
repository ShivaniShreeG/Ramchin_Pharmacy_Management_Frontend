import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../../../public/main_navigation.dart';
import 'package:intl/intl.dart';

const Color royal = Color(0xFF875C3F);

class SalesReportPdfPage extends StatefulWidget {
  final Map<String, dynamic> reportData;
  final Map<String, dynamic> shopDetails;
  final DateTime selectedDate;

  const SalesReportPdfPage({
    super.key,
    required this.reportData,
    required this.shopDetails,
    required this.selectedDate,
  });

  @override
  State<SalesReportPdfPage> createState() => _SalesReportPdfPageState();
}

class _SalesReportPdfPageState extends State<SalesReportPdfPage> {
  late Future<Uint8List> pdfFuture;

  late pw.Font tamilFont;
  late pw.Font tamilFontBold;

  @override
  void initState() {
    super.initState();
    pdfFuture = _buildBillPdf(); // ✅ build ONCE
  }

  /// 🔹 BUILD PDF
  Future<Uint8List> _buildBillPdf() async {
    final pdf = pw.Document();
    tamilFont = pw.Font.ttf(
      await rootBundle.load("assets/fonts/NotoSansTamil-Regular.ttf"),
    );

    tamilFontBold = pw.Font.ttf(
      await rootBundle.load("assets/fonts/NotoSansTamil-Bold.ttf"),
    );
    final hall = widget.shopDetails;
    final summary = widget.reportData['summary'];
    final medicineWise = widget.reportData['medicineWise'] as List;

    final royal = PdfColor.fromInt(0xFF875C3F);
    Uint8List? hallLogo;

      hallLogo = base64Decode(hall['logo']);


    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (hallLogo != null)
                    pw.Image(
                      pw.MemoryImage(hallLogo),
                      width: 70,
                      height: 70,
                    ),

                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          hall['name'].toString().toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            font: tamilFontBold,
                            color: royal,
                          ),
                        ),

                        if ((hall['address'] ?? '').toString().isNotEmpty)
                          pw.Text(
                            hall['address'],
                            style: pw.TextStyle(font: tamilFont),
                          ),

                        if ((hall['phone'] ?? '').toString().isNotEmpty)
                          pw.Text(
                            'Phone: ${hall['phone']}',
                            style: pw.TextStyle(font: tamilFont),
                          ),

                        if ((hall['email'] ?? '').toString().isNotEmpty)
                          pw.Text(
                            'Email: ${hall['email']}',
                            style: pw.TextStyle(font: tamilFont),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Sales Summary-${DateFormat('dd MMM yyyy').format(widget.selectedDate)}",
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: royal,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: royal),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    _summaryRow("Total Sales", "₹${summary['totalSales'].toStringAsFixed(2)}"),
                    _summaryRow("Total Bills", summary['totalBills'].toString()),
                    _summaryRow("Total Profit", "₹${summary['totalProfit'].toStringAsFixed(2)}"),
                    _summaryRow("Units Sold", summary['totalUnitsSold'].toString()),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                "Medicine-wise Sales",
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: royal,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: royal),
                headerStyle: pw.TextStyle(
                  font: tamilFontBold,
                  fontSize: 10,
                  color: PdfColors.white,
                ),
                cellStyle: pw.TextStyle(
                  font: tamilFont,
                  fontSize: 10,
                ),
                headerDecoration: pw.BoxDecoration(color: royal),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(6),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,   // Medicine
                  1: pw.Alignment.center,       // Units
                  2: pw.Alignment.center,       // Strips
                  3: pw.Alignment.centerRight,  // Sales
                  4: pw.Alignment.centerRight,  // Profit
                },
                headers: ['Medicine', 'Units', 'Strips', 'Sales', 'Profit'],
                data: medicineWise.map((m) {
                  return [
                    m['medicine'],
                    m['quantity_units'].toString(),
                    m['quantity_strips'].toStringAsFixed(2),
                    '₹${m['sales'].toStringAsFixed(2)}',
                    '₹${m['profit'].toStringAsFixed(2)}',
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _summaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: tamilFont),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: tamilFontBold,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: royal,
          title: Text(
            "Sales Report - ${DateFormat('dd MMM yyyy').format(widget.selectedDate)}",
            style: const TextStyle(color: Colors.white),
          ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => MainNavigation(initialIndex: 0),
                ),
              );
            },
          ),
        ],
      ),

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
                ),
                icon: const Icon(Icons.share),
                label: const Text("Share"),
                onPressed: () {
                  pdfFuture.then((pdfData) {
                    Printing.sharePdf(
                      bytes: pdfData,
                      filename: "sales.pdf",
                    );
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
