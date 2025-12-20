import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../public/config.dart';
import '../../../../public/main_navigation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

const Color royal = Color(0xFF19527A);
const Color royalLight = Color(0xFF629AC1);

class BookingDetailsPage extends StatefulWidget {
  final Map<String, dynamic> booking;

  const BookingDetailsPage({super.key, required this.booking});

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  Map<String, dynamic>? hallDetails;
  bool bookingSuccess = false;
  bool submitting = false;
  Map<String, dynamic>? bookingResponse;

  @override
  void initState() {
    super.initState();
    _fetchHallDetails();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchHallDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lodgeId = prefs.getInt("lodgeId");

      final url = Uri.parse('$baseUrl/lodges/$lodgeId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        hallDetails = jsonDecode(response.body);
      }
    } catch (e) {
      _showMessage("Error fetching lodge details: $e");
    } finally {
      setState(() {});
    }
  }

  String formatDate(String dt) {
    try {
      final dateTime = DateTime.parse(dt);
      return DateFormat('dd MMM yyyy • hh:mm a').format(dateTime);
    } catch (e) {
      return dt;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: royal)),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: royal, width: 2),
        ),
      ),
    );
  }

  Widget _buildHallCard(Map<String, dynamic> hall) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: royal,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: royal, width: 1.5),
      ),
      child: Row(
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
              color: Colors.white,
              child: const Icon(Icons.home_work_rounded,
                  color: royal, size: 35),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hall['name']?.toString().toUpperCase() ?? "LODGE NAME",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  String formatTo12Hour(DateTime dt) {
    return "${dt.day.toString().padLeft(2, '0')}-"
        "${dt.month.toString().padLeft(2, '0')}-"
        "${dt.year} "
        "${(dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString().padLeft(2, '0')}:"
        "${dt.minute.toString().padLeft(2, '0')} "
        "${dt.hour >= 12 ? "PM" : "AM"}";
  }

  void _showGuestIdProofs(List<dynamic> urls) {
    final validUrls = urls.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();

    if (validUrls.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          height: 400,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const Text(
                "Guest ID Proofs",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18,color: royal),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: validUrls.length,
                  itemBuilder: (context, index) {
                    final url = validUrls[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          Expanded(
                            child: Image.network(url, fit: BoxFit.contain),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _downloadImage(url),
                            icon: const Icon(Icons.download),
                            label: const Text("Download"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: royal,
                              foregroundColor: Colors.white,
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child:  Text("Close",style: TextStyle(color: royal),),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _downloadImage(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      _showMessage("Cannot open URL");
    }
  }

  void _showAadharNumbers(List<dynamic> numbersList) {
    final numbers = numbersList.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    if (numbers.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Guest Aadhar Numbers",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: royal),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: numbers.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: royal,
                        child: Text("${index + 1}", style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(numbers[index], style: const TextStyle(fontWeight: FontWeight.bold,color: royal)),
                    );
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close", style: TextStyle(color: royal)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bookingInfoSection(Map<String, dynamic> b) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: royal, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.only(top: 25, left: 12, right: 12, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    flex: 2,
                    child: Text(
                      "Number of Guests",
                      style: TextStyle(fontWeight: FontWeight.bold, color: royal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      initialValue: b['numberofguest'].toString(),
                      keyboardType: TextInputType.number,
                      cursorColor: royal,
                      readOnly: true,
                      style: TextStyle(color: royal),
                      decoration: InputDecoration(
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
                        fillColor: royal.withValues(alpha: 0.05),
                        isDense: true,
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    flex: 2,
                    child: Text(
                      "Check-In",
                      style: TextStyle(fontWeight: FontWeight.bold, color: royal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      style: TextStyle(color: royal),
                      readOnly: true,
                      initialValue: formatTo12Hour(DateTime.parse(b['check_in'])),
                      decoration: _inputDecoration(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  const Expanded(
                    flex: 2,
                    child: Text(
                      "Check-Out",
                      style: TextStyle(fontWeight: FontWeight.bold, color: royal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      style: TextStyle(color: royal),
                      readOnly: true,
                      initialValue: formatTo12Hour(DateTime.parse(b['check_out'])),
                      decoration: _inputDecoration(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              Center(
                child: Text(
                  "Booked Room Details",
                  style: TextStyle(
                    color: royal,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Center(
                child: _buildSelectedRooms(b),
              ),
              const SizedBox(height: 10),

              if (b['aadhar_number'] != null && (b['aadhar_number'] as List).isNotEmpty) ...[
                const SizedBox(height: 10),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _showAadharNumbers(b['aadhar_number']),
                    icon: const Icon(Icons.account_box),
                    label: const Text("View Aadhar Numbers"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: royal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],

              if (b['id_proof'] != null && (b['id_proof'] as List).isNotEmpty) ...[
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _showGuestIdProofs(b['id_proof']),
                    icon: const Icon(Icons.image),
                    label: const Text("View Guest ID Proofs"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: royal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        Positioned(
          top: -12,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              decoration: BoxDecoration(
                color: royal,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "BOOKING INFORMATION",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedRooms(dynamic b) {
    final bookedRooms = b['booked_room'];

    if (bookedRooms == null || bookedRooms is! List || bookedRooms.isEmpty) {
      return Text(
        "No room details available",
        style: TextStyle(color: royal, fontSize: 14, fontStyle: FontStyle.italic),
      );
    }

    return Column(
      children: bookedRooms.map<Widget>((room) {
        final name = room[0]?.toString() ?? "-";
        final type = room[1]?.toString() ?? "-";

        final nums = (room[2] is List)
            ? List<String>.from(room[2]).join(", ")
            : "-";

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: royal),
          ),
          child: ListTile(
            leading: Icon(Icons.meeting_room, color: royal),
            title: Text("$name • $type",
                style: TextStyle(
                    color: royal,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            subtitle: Text(
              "Rooms: $nums",
              style: TextStyle(color: royal),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget cancelledRoomsCard(List<dynamic> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: royal, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              "Cancelled Rooms",
              style: TextStyle(
                color: royal,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...items.map((r) {
            final name = r['room_name'] ?? '';
            final type = r['room_type'] ?? '';
            final nums = (r['cancelled_numbers'] ?? []).join(', ');

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                "$name ($type): $nums",
                style: const TextStyle(
                  color: royal,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          })
        ],
      ),
    );
  }

  Widget _partialCancelSection(List<dynamic> data) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: royal, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.only(top: 25, left: 12, right: 12, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              ...data.map((cancel) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    cancelledRoomsCard(cancel["room_number"] ?? []),

                    const SizedBox(height:10),
                    _paymentRow("Amount Paid",
                        "₹${cancel['amount_paid'] ?? 0}"),

                    const SizedBox(height: 5),
                    _paymentRow("Cancel Charge",
                        "₹${cancel['cancel_charge'] ?? 0}"),

                    const SizedBox(height: 5),
                    _paymentRow("Refund Amount",
                        "₹${cancel['refund'] ?? 0}"),

                    const SizedBox(height: 5),
                    _paymentRow("Cancelled At",formatDate(cancel['created_at'])),
                  ],
                );
              })
            ],
          ),
        ),
        Positioned(
          top: -12,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              decoration: BoxDecoration(
                color: royal,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "PARTIAL CANCELLATION",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _billingSection(Map<String, dynamic>? data, Map<String, dynamic> b) {
    if (data == null && (b["deposite"] == null || b["deposite"].toString() == "0")) {
      return const SizedBox.shrink();
    }

    final reason = data?["reason"] ?? {};
    final billingTotal = data?["total"] != null
        ? double.tryParse(data!["total"].toString()) ?? 0
        : 0;

    final deposit = double.tryParse(b["deposite"]?.toString() ?? "0") ?? 0;
    final finalAmount = billingTotal - deposit;
    final displayAmount = finalAmount.abs().toStringAsFixed(2);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: royal, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.only(top: 25, left: 12, right: 12, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              if (reason is Map && data != null)
                ...reason.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _billRow(e.key.toString(), "₹${e.value ?? 0}"),
                )),

              if (data != null && billingTotal > 0) ...[
                const SizedBox(height: 10),
                _billRow("Billing Total", "₹$billingTotal"),
              ],


              if (deposit > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      flex: 2,
                      child: Text("Deposit:",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: royal)),
                    ),
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        readOnly: true,
                        initialValue: "₹$deposit",
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: _inputDecoration(),
                      ),
                    ),
                  ],
                ),
              ],

              if (data != null || deposit > 0) ...[
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        finalAmount < 0 ? "Refund Due:" : "Payable:",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: royal),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        readOnly: true,
                        initialValue: "₹$displayAmount",
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: finalAmount < 0 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: _inputDecoration(),
                      ),
                    ),
                  ],
                ),
              ],
              if (data != null) ...[
                const SizedBox(height: 10),
                _paymentRow("Billed At", formatDate(data['created_at'])),
              ],

            ],
          ),
        ),
        Positioned(
          top: -12,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              decoration: BoxDecoration(
                color: royal,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "BILLING INFORMATION",
                style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _personalInfoSection(Map<String, dynamic> b) {
    bool hasValue(dynamic val) => val != null && val.toString().trim().isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: royal, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.only(top: 25, left: 12, right: 12, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              _infoTextField("Name", b["name"]),

              const SizedBox(height: 10),
              _infoTextField("Phone", b["phone"]),

              if (hasValue(b["alternate_phone"])) ...[
                const SizedBox(height: 10),
                _infoTextField("Alt Phone", b["alternate_phone"]),
              ],

              if (hasValue(b["email"])) ...[
                const SizedBox(height: 10),
                _infoTextField("Email", b["email"]),
              ],

              if (hasValue(b["address"])) ...[
                const SizedBox(height: 10),
                _infoTextField("Address", b["address"]),
              ],
            ],
          ),
        ),

        Positioned(
          top: -12,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              decoration: BoxDecoration(
                color: royal,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "PERSONAL INFORMATION",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            "$label:",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: royal,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: TextFormField(
            readOnly: true,
            initialValue: value,
            textAlign: TextAlign.right,
            style: const TextStyle(color: royal),
            decoration: _inputDecoration(),
          ),
        ),
      ],
    );
  }

  Widget _billRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            "$label:",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: royal,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: TextFormField(
            readOnly: true,
            initialValue: value,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.green),
            decoration: _inputDecoration(),
          ),
        ),
      ],
    );
  }

  Widget _infoTextField(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            "$label:",
            style: const TextStyle(fontWeight: FontWeight.bold, color: royal),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: TextFormField(
            readOnly: true,
            initialValue: value,
            style: const TextStyle(color: royal),
            decoration: _inputDecoration(),
          ),
        ),
      ],
    );
  }

  Widget _paymentInfoSection(Map<String, dynamic> b) {

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: royal, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.only(top: 25, left: 12, right: 12, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              _paymentRow("No. of Days", b["specification"]["number_of_days"].toString()),
              const SizedBox(height: 10),

              _paymentRow("No. of Rooms", b["specification"]["number_of_rooms"].toString()),
              const SizedBox(height: 10),

              _paymentRow("Base Amount", "₹${b["baseamount"]}"),
              const SizedBox(height: 10),

              _paymentRow("GST", "₹${b["gst"]}"),
              const SizedBox(height: 10),

              _paymentRow("Total Amount", "₹${b["amount"]}"),
              const SizedBox(height: 10),

              if(b['deposite']!=null && b['deposite'].toString()!="0")
                _paymentRow("Deposite", "₹${b["deposite"]}"),
              
              const SizedBox(height: 10),
              _paymentRow("Booked At", formatDate(b['created_at']))
            ],
          ),
        ),

        Positioned(
          top: -12,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              decoration: BoxDecoration(
                color: royal,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "PAYMENT INFORMATION",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: royal, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: royal, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: royal.withValues(alpha: 0.05),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final b = widget.booking;

    final Map<String, dynamic>? billingData = b["billing"];

    final bool hasBilling =
        (b["status"] == "BILLED");

    final List<dynamic>? partialList = b["PartialCancels"];
    final bool hasPartial = partialList != null && partialList.isNotEmpty;


    return Scaffold(
        appBar: AppBar(
          backgroundColor: royal,
          title: const Text("Booking Details", style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.home, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: 0)),
                );
              },
            ),
          ],
        ),
        body:SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (hallDetails != null) _buildHallCard(hallDetails!),
                  const SizedBox(height: 30),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      decoration: BoxDecoration(
                        color: royal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Booking ID: ${b["booking_id"]}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _personalInfoSection(b),
                  const SizedBox(height: 30),
                  _bookingInfoSection(b),
                  const SizedBox(height: 30),
                  _paymentInfoSection(b),
                  const SizedBox(height: 30),
                  if (hasPartial) _partialCancelSection(partialList),
                  if (hasPartial) const SizedBox(height: 30),
                  if (hasBilling)
                    _billingSection(billingData, b),
                  const SizedBox(height: 70),
                ],
              ),
            ),
          );
  }
}
