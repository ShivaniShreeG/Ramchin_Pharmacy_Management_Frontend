import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../../public/main_navigation.dart';

const Color royal = Color(0xFF875C3F);

class ReorderPdfPage extends StatefulWidget {
  final Map<String, dynamic>? shopDetails;
  final List<Map<String, dynamic>> medicines;

  const ReorderPdfPage({
    super.key,
    required this.shopDetails,
    required this.medicines,
  });

  @override
  State<ReorderPdfPage> createState() => _ReorderPdfPageState();
}

class _ReorderPdfPageState extends State<ReorderPdfPage> {
  late Future<Uint8List> pdfFuture;
  final Map<int, TextEditingController> qtyControllers = {};
  bool isAllQtyEntered = false;
  bool showPdf = false;

  @override
  void initState() {
    super.initState();


      for (var m in widget.medicines) {
        final c = TextEditingController();
        c.addListener(_checkAllQtyEntered);
        qtyControllers[m['medicine_id']] = c;
      }

    pdfFuture = _buildReorderPdf();
  }

  void _checkAllQtyEntered() {
    final allEntered = widget.medicines.every((m) {
      final text = qtyControllers[m['medicine_id']]!.text;
      final qty = int.tryParse(text) ?? 0;
      return qty > 0;
    });

    if (allEntered != isAllQtyEntered) {
      setState(() => isAllQtyEntered = allEntered);
    }
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
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _th("Medicine"),
                      _th("Required Quantity"),
                    ],
                  ),

                  ...widget.medicines.map((m) {
                    final qty = qtyControllers[m['medicine_id']]!.text;
                    return pw.TableRow(
                      children: [
                        _td(m['medicine_name']),
                        _td(qty), // ✅ ENTERED QTY
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
      backgroundColor: Colors.white,
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

      body: showPdf
          ? FutureBuilder<Uint8List>(
        future: pdfFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          return PdfPreview(
            build: (_) => snapshot.data!,
            allowPrinting: false,
            allowSharing: false,
            canChangeOrientation: false,
            canChangePageFormat: false,
          );
        },
      )
          : Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 600, // constrain width
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListView.builder(
                  shrinkWrap: true, // important to let column expand
                  physics: const NeverScrollableScrollPhysics(), // single scroll
                  itemCount: widget.medicines.length,
                  itemBuilder: (context, index) {
                    final m = widget.medicines[index];
                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: royal),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m['medicine_name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: royal,
                              ),
                            ),
                            Text("Current Stock: ${m['current_stock']}"),
                            const SizedBox(height: 8),
                            TextField(
                              controller: qtyControllers[m['medicine_id']],
                              cursorColor: royal,
                              style: TextStyle(color: royal),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: "Required Quantity",
                                labelStyle: TextStyle(color: royal),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: royal, width: 1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: royal, width: 2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: royal.withValues(alpha:0.05),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),

      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(12),
          color: showPdf?royal:Colors.white,
          child: showPdf
              ? Row(
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

              /// SHARE
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
          )
              : SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text("Generate PDF"),
              style: ElevatedButton.styleFrom(
                backgroundColor: royal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: isAllQtyEntered
                  ? () {
                setState(() {
                  showPdf = true;
                  pdfFuture = _buildReorderPdf();
                });
              }
                  : null,
            ),
          ),
        ),
      ),
      );
  }
}
