import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../public/config.dart';
import '../../../../public/main_navigation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'bill.dart';

const Color royal = Color(0xFF19527A);
const Color royalLight = Color(0xFF629AC1);

class BillingDetailsPage extends StatefulWidget {
  final Map<String, dynamic> booking;

  const BillingDetailsPage({super.key, required this.booking});

  @override
  State<BillingDetailsPage> createState() => BillingDetailsPageState();
}

class BillingDetailsPageState extends State<BillingDetailsPage> {
  Map<String, dynamic>? hallDetails;
  bool bookingSuccess = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool submitting = false;
  Map<String, dynamic>? bookingResponse;
  List<TextEditingController> _chargeControllers = [];

  late final int bookingId;
  List<Map<String, dynamic>> charges = [];
  bool isLoadingCharges = true;
  String? selectedPaymentMethod;

  @override
  void initState() {
    super.initState();
    bookingId = widget.booking['booking_id'];
    _fetchHallDetails();
    _fetchCharges();
  }
  double _calculateBalancePayment() {
    double balance = double.tryParse(widget.booking['Balance']?.toString() ?? '0') ?? 0;
    double deposit = double.tryParse(widget.booking['deposite']?.toString() ?? '0') ?? 0;

    double chargesTotal = charges.fold(
      0,
          (sum, c) => sum + (double.tryParse(c['amount'].toString()) ?? 0),
    );

    double total = balance + chargesTotal;
    return total - deposit;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchCharges() async {
    setState(() => isLoadingCharges = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final lodgeId = prefs.getInt('lodgeId');

      if (lodgeId == null) {
        _showMessage('Lodge ID not found');
        return;
      }

      final url = Uri.parse('$baseUrl/billings/charges/$bookingId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
            charges = List<Map<String, dynamic>>.from(data['charges'] ?? []);
            _chargeControllers = charges
                .map((c) => TextEditingController(text: c['amount'].toString()))
                .toList();
        });
      } else {
        _showMessage('Failed to fetch charges');
      }
    } catch (e) {
      _showMessage('Error fetching charges: $e');
    } finally {
      setState(() => isLoadingCharges = false);
    }
  }

  Widget _billingInfoSection() {
    double balance = widget.booking['Balance'] != null
        ? double.tryParse(widget.booking['Balance'].toString()) ?? 0
        : 0;
    double deposit = widget.booking['deposite'] != null
        ? double.tryParse(widget.booking['deposite'].toString()) ?? 0
        : 0;

    double chargesTotal = charges.fold(0, (sum, c) {
      double amt = double.tryParse(c['amount'].toString()) ?? 0;
      return sum + amt;
    });

    double total = balance + chargesTotal;
    double balancePayment = _calculateBalancePayment();

    List<Widget> rows = [];

    if (balance != 0) {
      rows.add(_billTextField("Balance", balance.toStringAsFixed(2)));
    }

    for (int i = 0; i < charges.length; i++) {
      final c = charges[i];
      final amount = c['amount'].toString();
      rows.add(
        GestureDetector(
          onTap: () => _showChargeDialog(existingCharge: c, index: i),
          child: _billTextField(c['reason'] ?? 'No Reason', amount),
        ),
      );
    }

    rows.add(_billTextField("Total", total.toStringAsFixed(2), isTotal: true));

    if (deposit != 0) {
      rows.add(_billTextField("Deposit", deposit.toStringAsFixed(2)));
      rows.add(
        _billTextField(
          "Balance Payment",
          balancePayment.abs().toStringAsFixed(2),
          isTotal: true,
          valueColor: balancePayment >= 0 ? Colors.green : Colors.red,
        ),
      );
    }

    rows.add(
      Center(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: royal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 120),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text("Add"),
          onPressed: () => _showChargeDialog(),
        ),
      ),
    );

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
            children: rows,
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
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _billTextField(String label, String value,
      {bool isTotal = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "$label:",
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: royal,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: TextFormField(
              key: ValueKey("$label$value"), // 👈 ADD THIS
              readOnly: true,
              initialValue: value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? royal,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
              decoration: _inputDecoration(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showChargeDialog({Map<String, dynamic>? existingCharge, int? index}) async {
    final reasonController =
    TextEditingController(text: existingCharge != null ? existingCharge['reason'] : '');
    final amountController = TextEditingController(
        text: existingCharge != null ? existingCharge['amount'].toString() : '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingCharge != null ? "Edit Charge" : "Add Charge"),
        titleTextStyle: TextStyle(
          color: royal,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              style: TextStyle(color: royal),
              controller: reasonController,
              cursorColor: royal,
              decoration: InputDecoration(
                hintStyle: TextStyle(color: royal),
                hintText: "Enter the reason",
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              style: TextStyle(color: royal),
              controller: amountController,
              cursorColor: royal,
              decoration: InputDecoration(
                hintStyle: TextStyle(color: royal),
                hintText: "Enter the amount",
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: royal,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: royal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final reason = reasonController.text.trim();
              final amount = double.tryParse(amountController.text.trim()) ?? 0;

              if (reason.isEmpty) {
                _showMessage("Reason cannot be empty");
                return;
              }

              setState(() {
                if (existingCharge != null && index != null) {
                  charges[index] = {"reason": reason, "amount": amount};
                  _chargeControllers[index].text = amount.toString();
                } else {
                  charges.add({"reason": reason, "amount": amount});
                  _chargeControllers.add(TextEditingController(text: amount.toString()));
                }

                // 🔥 Force recalculation of all totals instantly
                widget.booking['BalancePayment'] = _calculateBalancePayment();
              });

              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
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
              if (b['deposite'] != null &&
                  b['deposite'].toString().trim() != "0" &&
                  b['deposite'].toString().trim() != "0.0")
                _paymentRow("Deposite", "₹${b["deposite"]}")
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
              const SizedBox(height: 10),
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
              child:  Text(
                "PERSONAL INFORMATION",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
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

  Future<void> _bookRooms() async {
    setState(() => submitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final lodgeId = prefs.getInt('lodgeId');
      final userId = prefs.getString('userId');
      final bookingID = bookingId;
      final currentTime = DateTime.now().toIso8601String();

      if (lodgeId == null || userId == null) {
        _showMessage("LodgeId or UserId not found");
        return;
      }

      double balance = double.tryParse(widget.booking['Balance']?.toString() ?? '0') ?? 0;
      if (balance != 0) {
        charges.add({"reason": "Balance", "amount": balance});
      }

      Map<String, dynamic> reasonJson = {
        for (var c in charges)
          c['reason'].toString(): double.tryParse(c['amount'].toString()) ?? 0
      };

      double chargesTotal =
      reasonJson.values.fold(0, (sum, value) => sum + (value as num));

      double deposit = double.tryParse(widget.booking['deposite']?.toString() ?? '0') ?? 0;
      deposit = (deposit == 0) ? 0 : deposit;

      double? balancePayment = chargesTotal - deposit;
      balancePayment = (balancePayment == 0) ? null : balancePayment;
      if ((chargesTotal > 0) || (balancePayment != null && balancePayment != 0)) {
        final paymentMethod = await _selectPaymentMethod();
        if (paymentMethod == null) {
          _showMessage("Please select a payment method");
          return;
        }

        selectedPaymentMethod = paymentMethod;
      }
      final body = {
        "lodge_id": lodgeId,
        "user_id": userId,
        "booking_id": bookingID,
        "reason": reasonJson.isNotEmpty ? reasonJson : null,
        "total": chargesTotal > 0 ? chargesTotal : null,
        "balancePayment": (balancePayment != null && balancePayment != 0)
            ? balancePayment
            : 0,
        "payment_method": selectedPaymentMethod,
        "current_time": currentTime,
      };
      final url = Uri.parse("$baseUrl/billings");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        _showMessage("Billing saved successfully!");

        setState(() {
          bookingSuccess = true;
          bookingResponse = data;
        });
      } else {
        _showMessage("Failed: ${response.body}");
      }
    } catch (e) {
      _showMessage("Error: $e");
    } finally {
      setState(() => submitting = false);
    }
  }

  Future<String?> _selectPaymentMethod() async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: royal, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Select Payment Method",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: royal,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, "CASH"),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: royalLight.withAlpha(40),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: royal, width: 1),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.money, color: royal, size: 28),
                              const SizedBox(width: 8),
                              Text(
                                "Cash",
                                style: TextStyle(
                                  color: royal,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, "ONLINE"),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: royalLight.withAlpha(40),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: royal, width: 1),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.phone_iphone, color: royal, size: 28),
                              const SizedBox(width: 8),
                              Text(
                                "Online",
                                style: TextStyle(
                                  color: royal,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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

  Widget _bookingInfoSection(Map<String, dynamic> b) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: royal, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.only(
              top: 25, left: 12, right: 12, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    flex: 2,
                    child: Text(
                      "Number of Guests",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: royal),
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
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: royal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      style: TextStyle(color: royal),
                      readOnly: true,
                      initialValue: formatTo12Hour(
                          DateTime.parse(b['check_in'])),
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
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: royal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      style: TextStyle(color: royal),
                      readOnly: true,
                      initialValue: formatTo12Hour(
                          DateTime.parse(b['check_out'])),
                      decoration: _inputDecoration(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
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
              const SizedBox(height: 15),
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
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
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
    bool isPageLoading = hallDetails == null || isLoadingCharges;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, res) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: royal,
          title: const Text("Check Out", style: TextStyle(color: Colors.white)),
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
        body: isPageLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: bookingSuccess
                ? SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  if (hallDetails != null) _buildHallCard(hallDetails!),
                  const SizedBox(height: 40),
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: royal, width: 2),
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.white,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 20),
                                const Text(
                                  "Generate bill for check-out.\nView it as PDF and download.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: royal,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 30),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: royal,
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 30),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => BillPage(
                                          bookingDetails: widget.booking,
                                          serverData: bookingResponse,
                                          hallDetail:hallDetails,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    "Generate Bill",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: -20,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
                              decoration: BoxDecoration(
                                color: royal,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "GENERATE BILL",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ) : SingleChildScrollView(
              padding: const EdgeInsets.all(2),
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
                  _billingInfoSection(),
                  const SizedBox(height: 30),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: royal),
                      onPressed: submitting ? null : _bookRooms,
                      child: submitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Confirm Check Out",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 70),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleBackNavigation() {
    if (bookingSuccess) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: 0)),
            (route) => false,
      );
    } else {
      Navigator.pop(context);
    }
  }
}
