import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../../../public/main_navigation.dart';
import 'package:url_launcher/url_launcher.dart';

const Color royal = Color(0xFF875C3F);

class BillDetailsPage extends StatefulWidget {
  final Map<String, dynamic> billData;
  final Map<String, dynamic> item;
  final Map<String, dynamic>? shopDetails;
  final String? userId;

  const BillDetailsPage({
    super.key,
    required this.billData,
    required this.item,
    this.shopDetails,
    this.userId,
  });

  @override
  State<BillDetailsPage> createState() => _BillDetailsPageState();
}

class _BillDetailsPageState extends State<BillDetailsPage> {
  late Future<Uint8List> pdfFuture;

  @override
  void initState() {
    super.initState();
    pdfFuture = _buildBillPdf(); // ✅ build ONCE
  }

  /// 🔹 BUILD PDF
  Future<Uint8List> _buildBillPdf() async {
    final pdf = pw.Document();
    final tamilFont = pw.Font.ttf(await rootBundle.load("assets/fonts/NotoSansTamil-Regular.ttf"));
    final tamilFontBold = pw.Font.ttf(await rootBundle.load("assets/fonts/NotoSansTamil-Bold.ttf"));
    final hall = widget.shopDetails;
    final gst = hall?['gst_number'] ?? '';
    final dl = hall?['dl_number'] ?? '';
    final tin = hall?['tin_number'] ?? '';

    final billItems = (widget.item['items'] as List<dynamic>?)
        ?.map((e) => Map<String, dynamic>.from(e))
        .toList() ?? [];
    final royal = PdfColor.fromInt(0xFF875C3F);
    Uint8List? hallLogo;

    if (hall != null && hall['logo'] != null) {
      hallLogo = base64Decode(hall['logo']);
    }

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
                          hall?['name']?.toString().toUpperCase() ?? 'HALL NAME',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            font: tamilFontBold,
                            color: royal,
                          ),
                        ),

                        if ((hall?['address'] ?? '').toString().isNotEmpty)
                          pw.Text(
                            hall!['address'],
                            style: pw.TextStyle(font: tamilFont),
                          ),

                        if ((hall?['phone'] ?? '').toString().isNotEmpty)
                          pw.Text(
                            'Phone: ${hall!['phone']}',
                            style: pw.TextStyle(font: tamilFont),
                          ),

                        if ((hall?['email'] ?? '').toString().isNotEmpty)
                          pw.Text(
                            'Email: ${hall!['email']}',
                            style: pw.TextStyle(font: tamilFont),
                          ),
                        if (gst.isNotEmpty)
                          pw.Text('GST No: $gst', style: pw.TextStyle(font: tamilFont)),
                        if (dl.isNotEmpty)
                          pw.Text('DL No: $dl', style: pw.TextStyle(font: tamilFont)),
                        if (tin.isNotEmpty)
                          pw.Text('TIN No: $tin', style: pw.TextStyle(font: tamilFont)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
// ---------- INVOICE DETAILS BOX ----------
              pw.Container(
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1,color: royal),
                ),
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Center(
                      child: pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: royal,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Bill No : ${widget.billData['bill_id']}'),
                              pw.Text('Customer : ${widget.item['customer_name'] ?? ""}'),
                              pw.Text('Phone : ${widget.item['phone'] ?? ""}'),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 70),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              if (widget.item['doctor_name'] != null &&
                                  widget.item['doctor_name'].toString().isNotEmpty)
                                pw.Text('Doctor : ${widget.item['doctor_name']}'),
                              pw.Text('Billed By : ${widget.userId ?? ""}'),
                              pw.Text("Payment Mode: ${widget.item['payment_mode']}"),
                            ],
                          ),
                        ),
                      ],
                    ),

                  ],
                ),
              ),
              pw.SizedBox(height: 25),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5,color: royal),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    // header row – white background
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.white, // <-- was grey300
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Medicine',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Qty',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Price',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Total',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),

                  ...billItems.map(
                        (e) => pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.white, // optional, default is white
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(e['medicine_name'] ?? ''),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            e['quantity'].toString(),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Rs. ${e['unit_price']}',
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Rs. ${e['total_price']}',
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 1,color: royal),
              pw.SizedBox(height: 8),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "Grand Total: Rs.${widget.item['total']}",
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: royal,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  String generateShareText() {
    final shop = widget.shopDetails;
    final item = widget.item;
    final items = (item['items'] as List<dynamic>? ?? []);

    final buffer = StringBuffer();

    buffer.writeln("```");
    buffer.writeln("        PHARMACY BILL");
    buffer.writeln("---------------------------");

    if (shop != null) {
      if (shop['name'] != null) {
        buffer.writeln("🏪 ${shop['name']}");
      }
      if ((shop['address'] ?? '').toString().isNotEmpty) {
        buffer.writeln("📍 ${shop['address']}");
      }
      if ((shop['phone'] ?? '').toString().isNotEmpty) {
        buffer.writeln("📞 ${shop['phone']}");
      }
    }

    buffer.writeln("");
    buffer.writeln("Bill No  : ${widget.billData['bill_id']}");
    buffer.writeln("Customer : ${item['customer_name'] ?? ''}");
    buffer.writeln("Phone    : ${item['phone'] ?? ''}");

    if (item['doctor_name'] != null &&
        item['doctor_name'].toString().isNotEmpty) {
      buffer.writeln("Doctor   : ${item['doctor_name']}");
    }

    buffer.writeln("Payment  : ${item['payment_mode'] ?? ''}");

    buffer.writeln("");
    buffer.writeln("     MEDICINES DETAILS");
    buffer.writeln("---------------------------");

    if (items.isEmpty) {
      buffer.writeln("No medicines added");
    } else {
      for (int i = 0; i < items.length; i++) {
        final m = items[i];
        buffer.writeln(
          "${i + 1}. ${m['medicine_name'] ?? ''}\n"
              "    Qty   : ${m['quantity']}\n"
              "    Price : Rs. ${m['unit_price']}\n"
              "    Total : Rs. ${m['total_price']}\n",
        );
      }
    }

    buffer.writeln("---------------------------");
    buffer.writeln("GRAND TOTAL : Rs. ${item['total'] ?? ''}");
    buffer.writeln("");
    buffer.writeln("Thank you for choosing us 🙏");
    buffer.writeln("```");

    return buffer.toString();
  }

  Future<void> shareViaWhatsApp() async {
    final rawPhone = widget.item['phone']?.toString();
    if (rawPhone == null || rawPhone.trim().isEmpty) return;

    const String countryCode = "91"; // 🇮🇳 Change if needed

    // Remove spaces, +, -, ()
    String phone = rawPhone.replaceAll(RegExp(r'[^\d]'), '');

    // Remove leading 0 if exists
    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }

    // Add country code if missing
    if (!phone.startsWith(countryCode)) {
      phone = countryCode + phone;
    }

    final text = Uri.encodeComponent(generateShareText());
    final url = Uri.parse('https://wa.me/$phone?text=$text');

    try {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint("Could not launch WhatsApp: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: royal,
        title: Text(
          "Bill #${widget.billData['bill_id']}",
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
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.share),
                label: const Text("Share"),
                onPressed: shareViaWhatsApp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
