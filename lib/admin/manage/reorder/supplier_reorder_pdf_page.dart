import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../public/main_navigation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

const Color royal = Color(0xFF875C3F);

class SupplierReorderPdfPage extends StatefulWidget {
  final Map<String, dynamic>? shopDetails;
  final Map<String, dynamic> supplier;
  final List medicines;

  const SupplierReorderPdfPage({
    super.key,
    required this.shopDetails,
    required this.supplier,
    required this.medicines,
  });

  @override
  State<SupplierReorderPdfPage> createState() =>
      _SupplierReorderPdfPageState();
}

class _SupplierReorderPdfPageState extends State<SupplierReorderPdfPage> {
  late Future<Uint8List> pdfFuture;

  @override
  void initState() {
    super.initState();
    pdfFuture = _buildReorderPdf();
  }

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
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
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
                        hall?['name']?.toString().toUpperCase() ?? 'SHOP NAME',
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
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "TO",
                    style:  pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  pw.Text(
                    "Supplier: ${widget.supplier['name']}",
                    style:  pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),

                  pw.SizedBox(height: 4),
                  ...[
                    textIfNotNull(widget.supplier['phone']?.toString(), "Phone"),
                    textIfNotNull(widget.supplier['email']?.toString(), "Mail"),
                    textIfNotNull(widget.supplier['address']?.toString(), "Address"),
                  ].whereType<pw.Widget>(),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Table: Only Medicine and Required Quantity
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _th("Medicine"),
                    _th("Required"),
                  ],
                ),
                ...widget.medicines.map((m) {
                  return pw.TableRow(
                    children: [
                      _td(m['medicine_name']),
                      _td(m['required_qty'].toString()),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget? textIfNotNull(String? value, String label) {
    if (value == null || value.trim().isEmpty) return null;
    return pw.Text(
      "$label: $value",
      style: const pw.TextStyle(fontSize: 12),
    );
  }

  pw.Widget _th(String t) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(t, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  );

  pw.Widget _td(String t) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(t),
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
