import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../../public/main_navigation.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../../public/config.dart';
import 'package:http/http.dart' as http;

const Color royal = Color(0xFF19527A);

class CancelBillPage extends StatefulWidget {
  final Map<String, dynamic> bookingDetails;
  final Map<String, dynamic>? serverData;
  final Map<String, dynamic>? hallDetails;

  const CancelBillPage({
    super.key,
    required this.bookingDetails,
    required this.serverData,
    required this.hallDetails,
  });

  @override
  State<CancelBillPage> createState() => _CancelBillPageState();
}
class _CancelBillPageState extends State<CancelBillPage> {
  late Future<Uint8List> pdfFuture;

  @override
  void initState() {
    super.initState();
    pdfFuture = _generatePdf(widget.bookingDetails, widget.serverData,widget.hallDetails
    );
  }

  Future<Map<String, dynamic>?> fetchAdminDetails(int hallId,String userId) async {
    try {
      final url = Uri.parse('$baseUrl/details/$hallId/admins/$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint("Admin Details: $data");
        return data;
      } else {
        debugPrint("Failed to fetch admin details. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching admin details: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text("Cancel Bill", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => MainNavigation(initialIndex: 0)),
              );
            },
          ),
        ],
      ),

      body: PdfPreview(
        build: (format) => _generatePdf(
          widget.bookingDetails,
          widget.serverData,
          widget.hallDetails,
        ),
        allowPrinting: false,
        allowSharing: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
      ),


      bottomNavigationBar: FutureBuilder<Uint8List>(
        future: _generatePdf(widget.bookingDetails, widget.serverData,widget.hallDetails),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final pdfData = snapshot.data!;
          return SafeArea(
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
                    ),
                    icon: const Icon(Icons.print),
                    label: const Text("Print"),
                    onPressed: () {
                      Printing.layoutPdf(onLayout: (_) async => pdfData);
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
                      Printing.sharePdf(bytes: pdfData, filename: "bill.pdf");
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<Uint8List> _generatePdf(
      Map<String, dynamic> bookingDetails,
      Map<String, dynamic>? serverData,
      Map<String, dynamic>? hallDetails
  ) async {

    final pdf = pw.Document();

    final font = pw.Font.ttf(await rootBundle.load("assets/fonts/NotoSansTamil-Regular.ttf"));
    final fontBold = pw.Font.ttf(await rootBundle.load("assets/fonts/NotoSansTamil-Bold.ttf"));

    final royalColor = PdfColor.fromInt(0xFF19527A);
    final royalLight = PdfColor.fromInt(0xFFC9E8FF);

    String formatDate(String dateStr) {
      try {
        final date = DateTime.parse(dateStr);
        return DateFormat('dd-MM-yyyy hh:mm a').format(date);
      } catch (e) {
        return dateStr;
      }
    }
    List<List<String?>> bookedRooms = [];

    if (bookingDetails['booked_room'] != null &&
        bookingDetails['booked_room'] is List) {
      bool isFirst = true;

      for (var room in bookingDetails['booked_room']) {
        String roomName = room[0].toString();
        String roomType = room[1].toString();
        String roomNumbers =
        (room[2] as List).map((e) => e.toString()).join(", ");

        bookedRooms.add([
          isFirst ? "BOOKED ROOM" : "",
          "$roomName - $roomType : $roomNumbers"
        ]);

        isFirst = false;
      }
    }

    final hallId = hallDetails!['lodge_id'] ?? 0;
    final bookingId = bookingDetails['booking_id'] ?? 0;
    final billNo = '$hallId$bookingId';
    final billDateTime = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());
    final userId = bookingDetails['user_id'].toString();
    final adminDetails = await fetchAdminDetails(hallId, userId);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),

        build: (context) => [
        pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          if (hallDetails['logo'] != null)
            pw.Image(
              pw.MemoryImage(base64Decode(hallDetails['logo'])),
              width: 70,
              height: 70,
            ),

          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  hallDetails['name']?.toString().toUpperCase() ?? 'LODGE NAME',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    font: fontBold,
                    color: royalColor,
                  ),
                  textAlign: pw.TextAlign.center,
                ),

                if ((hallDetails['address'] ?? '').toString().isNotEmpty)
                  pw.Text(
                    hallDetails['address'],
                    style: pw.TextStyle(font: font),
                    textAlign: pw.TextAlign.center,
                  ),

                if ((hallDetails['phone'] ?? '').toString().isNotEmpty)
                  pw.Text(
                    'Phone: ${hallDetails['phone']}',
                    style: pw.TextStyle(font: font),
                  ),

                if ((hallDetails['email'] ?? '').toString().isNotEmpty)
                  pw.Text(
                    'Email: ${hallDetails['email']}',
                    style: pw.TextStyle(font: font),
                  ),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 5),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text("Bill No: $billNo",
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: royalColor,
                  font: fontBold)),
          pw.Text("Generated At: $billDateTime",
              style: pw.TextStyle(fontSize: 10, font: font)),
        ],
      ),
      pw.Divider(color: royalColor,thickness: 1),
      pw.SizedBox(height: 10),
      _sectionHeader("PERSONAL INFORMATION", royalColor, fontBold),
      _infoTable([
        if ((bookingDetails['name'] ?? '').toString().isNotEmpty)
          ["NAME", bookingDetails['name']],
        if ((bookingDetails['phone'] ?? '').toString().isNotEmpty)
          ["PHONE", bookingDetails['phone']],
        if ((bookingDetails['address'] ?? '').toString().isNotEmpty)
          ["ADDRESS", bookingDetails['address']],
        if ((bookingDetails['email'] ?? '').toString().isNotEmpty)
          ["EMAIL", bookingDetails['email']],
        if (bookingDetails['alternate_phone'] != null &&
            (bookingDetails['alternate_phone']).isNotEmpty)
          [
            "ALTERNATE PHONE",
            (bookingDetails['alternate_phone'])
          ],
      ], royalLight, font),
      pw.SizedBox(height: 6),
      _sectionHeader("BOOKING INFORMATION", royalColor, font),
      _infoTable([
        ...bookedRooms,
        if ((bookingDetails['check_in'] ?? '').toString().isNotEmpty)
          ["CHECK-IN", formatDate(bookingDetails['check_in'])],
        if ((bookingDetails['check_out'] ?? '').toString().isNotEmpty)
          ["CHECK-OUT", formatDate(bookingDetails['check_out'])],
        if ((bookingDetails['numberofguest'] ?? '').toString().isNotEmpty)
          ["NUMBER OF GUEST", bookingDetails['numberofguest'].toString()],
      ], royalLight, font),
      pw.SizedBox(height: 6),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: PdfPageFormat.a4.availableWidth * 0.80,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: double.infinity,
                  color: royalColor,
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Text(
                    "PAYMENT INFORMATION",
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        font: fontBold,
                        fontSize: 9
                    ),
                  ),
                ),
                pw.SizedBox(height: 6),

                ...[
                  if (bookingDetails['specification']['number_of_days'] != null) "NUMBER OF DAYS",
                  if (bookingDetails['specification']['number_of_rooms'] != null) "NUMBER OF ROOMS",
                  if (bookingDetails['baseamount'] != null) "BASE AMOUNT",
                  if (bookingDetails['gst'] != null) "GST",
                  if (bookingDetails['amount'] != null) "TOTAL AMOUNT RECEIVED",
                  if (bookingDetails['deposite'] != null && bookingDetails['deposite'] != 0) "DEPOSITE",

                ].map((label) {
                  final isBalance = label == "BALANCE";
                  return pw.Container(
                    width: double.infinity,
                    color: royalLight,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    margin: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Text(
                      label,
                      style: pw.TextStyle(
                        font: isBalance ? fontBold : font,
                        fontWeight: isBalance ? pw.FontWeight.bold : pw.FontWeight.normal,fontSize: 9,
                      ),
                    ),
                  );
                }),

              ],
            ),
          ),

          pw.SizedBox(width: PdfPageFormat.a4.availableWidth * 0.02),

          pw.Container(
            width: PdfPageFormat.a4.availableWidth * 0.27,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  width: double.infinity,
                  color: royalColor,
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Text(
                    "AMOUNT",
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        font: fontBold,
                        fontSize: 9
                    ),
                  ),
                ),
                pw.SizedBox(height: 6),

                ...[
                  if (bookingDetails['specification']['number_of_days'] != null) "${bookingDetails['specification']['number_of_days']}",
                  if (bookingDetails['specification']['number_of_rooms'] != null) "Rs.${bookingDetails['specification']['number_of_rooms']}",
                  if (bookingDetails['baseamount'] != null) "Rs.${bookingDetails['baseamount']}",
                  if (bookingDetails['gst'] != null) "Rs.${bookingDetails['gst']}",
                  if (bookingDetails['amount'] != null) "Rs.${bookingDetails['amount']}",
                  if (bookingDetails['deposite'] != null && bookingDetails['deposite'] != 0) "Rs.${bookingDetails['deposite']}",
                ].map((amount) {
                  final isBalance = amount.contains(bookingDetails['Balance'].toString());
                  return pw.Container(
                    width: double.infinity,
                    color: royalLight,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    margin: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Text(
                      amount,
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 9,
                        font: isBalance ? fontBold : font,
                        fontWeight: isBalance ? pw.FontWeight.bold : pw.FontWeight.normal,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
          pw.SizedBox(height: 6),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: PdfPageFormat.a4.availableWidth * 0.80,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: double.infinity,
                      color: royalColor,
                      padding: const pw.EdgeInsets.all(2),
                      child: pw.Text(
                        "CANCELLATION INFORMATION",
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            font: fontBold,
                            fontSize: 9
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 6),

                    ...[
                      if (serverData!['amount_paid'] != null) "AMOUNT PAID",
                      if (serverData['cancel_charge'] != null ) "CANCELLATION CHARGE",
                      if (serverData['refund'] != null ) "REFUND",

                    ].map((label) {
                      final isBalance = label == "REFUND";
                      return pw.Container(
                        width: double.infinity,
                        color: royalLight,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        margin: const pw.EdgeInsets.only(bottom: 2),
                        child: pw.Text(
                          label,
                          style: pw.TextStyle(
                            font: isBalance ? fontBold : font,
                            fontWeight: isBalance ? pw.FontWeight.bold : pw.FontWeight.normal,fontSize: 9,
                          ),
                        ),
                      );
                    }),

                  ],
                ),
              ),

              pw.SizedBox(width: PdfPageFormat.a4.availableWidth * 0.02),

              pw.Container(
                width: PdfPageFormat.a4.availableWidth * 0.27,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: double.infinity,
                      color: royalColor,
                      padding: const pw.EdgeInsets.all(2),
                      child: pw.Text(
                        "AMOUNT",
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            font: fontBold,
                            fontSize: 9
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 6),

                    ...[
                      if (serverData['amount_paid'] != null) "Rs.${serverData['amount_paid']}",
                      if (serverData['cancel_charge'] != null ) "Rs.${serverData['cancel_charge']}",
                      if (serverData['refund'] != null) "Rs.${serverData['refund']}",
                    ].map((amount) {
                      final isBalance = amount.contains(serverData['refund'].toString());
                      return pw.Container(
                        width: double.infinity,
                        color: royalLight,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        margin: const pw.EdgeInsets.only(bottom: 2),
                        child: pw.Text(
                          amount,
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 9,
                            font: isBalance ? fontBold : font,
                            fontWeight: isBalance ? pw.FontWeight.bold : pw.FontWeight.normal,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                children: [
                  pw.Text(
                    adminDetails?['name'] ?? 'Manager',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold,
                      fontSize: 9,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Container(width: 120, height: 1, color: PdfColors.grey),
                  pw.Text(
                    "Manager",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
              pw.Column(
                children: [
                  pw.Container(width: 120, height: 1, color: PdfColors.grey),
                  pw.Text(
                    "Booking Person",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 5),
        ],
      ),
    );

    return pdf.save();
  }
  pw.Widget _sectionHeader(String title, PdfColor color, pw.Font font) {
    return pw.Container(
      width: double.infinity,
      color: color,
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: pw.Text(title,
          style: pw.TextStyle(
              color: PdfColors.white, fontWeight: pw.FontWeight.bold, font: font,fontSize: 9)),
    );
  }

  pw.Widget _infoTable(List<List<String?>> data, PdfColor shade, pw.Font font) {
    return pw.Center(
      child: pw.Table(
        columnWidths: {
          0: const pw.FixedColumnWidth(100),
          1: const pw.FixedColumnWidth(300),
        },
        border: pw.TableBorder.all(color: PdfColors.white),

        children: data.map((row) {
          if (row.length == 3) {
            return pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Container(
                    color: PdfColors.white,
                    child: pw.Text(row[0] ?? "",
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, font: font,fontSize: 9)),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        color: shade,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: pw.Text(row[1] ?? "", style: pw.TextStyle(font: font,fontSize: 9)),
                      ),
                      pw.SizedBox(width: 4),
                      pw.Text("to", style: pw.TextStyle(font: font,fontSize: 9)),
                      pw.SizedBox(width: 4),
                      pw.Container(
                        color: shade,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: pw.Text(row[2] ?? "", style: pw.TextStyle(font: font,fontSize: 9)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          } else {
            return pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Container(
                    color: PdfColors.white,
                    child: pw.Text(row[0] ?? "",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font,fontSize: 9)),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Container(
                    color: shade,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: pw.Text(row[1] ?? "", style: pw.TextStyle(font: font,fontSize: 9)),
                  ),
                ),
              ],
            );
          }
        }).toList(),
      ),
    );
  }
}
