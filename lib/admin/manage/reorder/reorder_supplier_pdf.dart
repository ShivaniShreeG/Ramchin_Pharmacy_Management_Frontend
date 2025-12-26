import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../../public/main_navigation.dart';

const Color royal = Color(0xFF875C3F);

class ReorderSupplierPdfPage extends StatefulWidget {
  final Map<String, dynamic>? shopDetails;
  final List<Map<String, dynamic>> medicines;

  const ReorderSupplierPdfPage({
    super.key,
    required this.shopDetails,
    required this.medicines,
  });

  @override
  State<ReorderSupplierPdfPage> createState() => _ReorderSupplierPdfPageState();
}

class _ReorderSupplierPdfPageState extends State<ReorderSupplierPdfPage> {
  late Future<Uint8List> pdfFuture;

  @override
  void initState() {
    super.initState();
    pdfFuture = _buildReorderPdf();
  }

  /// 🔹 BUILD PDF
  Future<Uint8List> _buildReorderPdf() async {
    final pdf = pw.Document();
    final font = pw.Font.ttf(
        await rootBundle.load("assets/fonts/NotoSansTamil-Regular.ttf"));
    final fontBold = pw.Font.ttf(
        await rootBundle.load("assets/fonts/NotoSansTamil-Bold.ttf"));
    Uint8List? logo;
    if (widget.shopDetails?['logo'] != null) {
      logo = base64Decode(widget.shopDetails!['logo']);
    }
    final hall = widget.shopDetails;


    final royal = PdfColor.fromInt(0xFF19527A);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              /// 🔹 HEADER
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (logo != null)
                    pw.Image(
                      pw.MemoryImage(logo),
                      width: 70,
                      height: 70,
                    ),

                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          hall?['name']?.toString().toUpperCase() ?? 'HALL NAME',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            font: fontBold,
                            color: royal,
                          ),
                        ),

                        if ((hall?['address'] ?? '').toString().isNotEmpty)
                          pw.Text(
                            hall!['address'],
                            style: pw.TextStyle(font: font),
                          ),

                        if ((hall?['phone'] ?? '').toString().isNotEmpty)
                          pw.Text(
                            'Phone: ${hall!['phone']}',
                            style: pw.TextStyle(font: font),
                          ),

                        if ((hall?['email'] ?? '').toString().isNotEmpty)
                          pw.Text(
                            'Email: ${hall!['email']}',
                            style: pw.TextStyle(font: font),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              pw.Divider(color: royal),
              pw.SizedBox(height: 12),

              /// 🔹 TITLE
              pw.Center(
                child: pw.Text(
                  "REORDER MEDICINE LIST",
                  style: pw.TextStyle(
                    fontSize: 16,
                    font: fontBold,
                    color: royal,
                  ),
                ),
              ),

              pw.SizedBox(height: 14),

              /// 🔹 TABLE
              pw.Table(
                border: pw.TableBorder.all(color: royal, width: 0.6),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(3),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _th("Medicine"),
                      _th("Stock"),
                      _th("Reorder"),
                      _th("Last Supplier"),
                    ],
                  ),

                  ...widget.medicines.map((m) {
                    final s = m['last_supplier'];
                    return pw.TableRow(
                      children: [
                        _td(m['medicine_name']),
                        _td(m['current_stock'].toString()),
                        _td(m['reorder_level'].toString()),
                        _td(s != null ? "${s['name']} (${s['phone']})" : "-"),
                      ],
                    );
                  }),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _th(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  );

  pw.Widget _td(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text("Reorder PDF", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => MainNavigation(initialIndex: 2)),
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
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error generating PDF:\n${snapshot.error}",
                textAlign: TextAlign.center,
              ),
            );
          }

          final pdfData = snapshot.data!;
          return PdfPreview(
            build: (_) => pdfData,
            allowPrinting: false,
            allowSharing: false,
            canChangeOrientation: false,
            canChangePageFormat: false,
          );
        },
      ),

      /// 🔹 BOTTOM ACTIONS
      bottomNavigationBar: SafeArea(
        child: Container(
          color: royal,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [

              /// PRINT
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: royal,
                ),
                icon: const Icon(Icons.print),
                label: const Text("Print"),
                onPressed: () {
                  pdfFuture.then((pdfData) {
                    Printing.layoutPdf(
                      onLayout: (_) async => pdfData,
                    );
                  });
                },
              ),

              /// SHARE (SYSTEM SHARE)
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
                      filename: "reorder_list.pdf",
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
