import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../public/config.dart';
import '../../../../public/main_navigation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'partial_cancel_bill.dart';

const Color royal = Color(0xFF19527A);
const Color royalLight = Color(0xFF629AC1);

class PartialCancelPage extends StatefulWidget {
  final Map<String, dynamic> booking;

  const PartialCancelPage({super.key, required this.booking});

  @override
  State<PartialCancelPage> createState() => PartialCancelPageState();
}

class PartialCancelPageState extends State<PartialCancelPage> {
  Map<String, dynamic>? hallDetails;
  bool bookingSuccess = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool submitting = false;
  Map<String, dynamic>? bookingResponse;
  final TextEditingController _reasonPercentageController = TextEditingController();
  final TextEditingController _cancelPercentageController = TextEditingController();
  final TextEditingController _cancelChargeController = TextEditingController();
  final TextEditingController _refundController = TextEditingController();
  List<dynamic> selectedRooms = [];
  late double originalBaseAmount;
  late int originalRoomCount;
  late int numDays;
  List<Map<String, dynamic>> buildRoomNumbersPayload() {
    List<Map<String, dynamic>> result = [];

    for (var group in widget.booking['booked_room']) {
      String roomName = group[0];
      String roomType = group[1];
      List allRooms = group[2];

      // selected rooms that belong to this room group
      List selected = allRooms
          .where((n) => selectedRooms.contains(n))
          .toList();

      if (selected.isNotEmpty) {
        result.add({
          "room_name": roomName,
          "room_type": roomType,
          "room_numbers": selected
        });
      }
    }

    return result;
  }


  @override
  void initState() {
    super.initState();
    _fetchHallDetails();
    _fetchCancelInfo();
    _reasonPercentageController.text = "Nill";
    originalBaseAmount = widget.booking['baseamount'] * 1.0;
    originalRoomCount  = widget.booking['specification']['number_of_rooms'];
    numDays            = widget.booking['specification']['number_of_days'];
    selectedRooms = [];
    for (var group in widget.booking['booked_room']) {
      selectedRooms.addAll(group[2]);
    }
  }

  @override
  void dispose() {
    _resetToOriginalState();
    super.dispose();
  }

  void _resetToOriginalState() {
    setState(() {
      selectedRooms = List.from(widget.booking['room_number']);
      widget.booking['baseamount'] = originalBaseAmount;
      _reasonPercentageController.text = "Nill";
      _cancelPercentageController.text = "";
      _cancelChargeController.text = "";
      _refundController.text = "";
      _fetchCancelInfo();
    });
  }

  void _recalculateBaseAmount() {
    double newBase = 0;

    for (var group in widget.booking['room_amount']) {
      String name = group['room_name'];
      String type = group['room_type'];
      int price = group['base_amount_per_room'];

      // find matching booked_room group
      var booked = widget.booking['booked_room'].firstWhere(
            (r) => r[0] == name && r[1] == type,
        orElse: () => null,
      );

      if (booked == null) continue;

      List myRooms = booked[2];

      // count selected room numbers for this type
      int selectedCount = myRooms.where((r) => selectedRooms.contains(r)).length;

      newBase += selectedCount * price;
    }

    setState(() {
      widget.booking['baseamount'] = newBase;
    });
  }

  Widget buildBookedRoomSelector() {
    List booked = widget.booking['booked_room'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: booked.map<Widget>((group) {
        String roomName = group[0];
        String roomType = group[1];
        List roomNumbers = group[2];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$roomName - $roomType",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: royal,
              ),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: roomNumbers.map<Widget>((room) {
                final isSelected = selectedRooms.contains(room);

                return ChoiceChip(
                  label: Text(
                    room.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                  selected: isSelected,
                  selectedColor: royal,
                  backgroundColor: royalLight,
                  checkmarkColor: Colors.white,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        selectedRooms.add(room);
                      } else {
                        selectedRooms.remove(room);
                      }

                      if (selectedRooms.isEmpty) {
                        selectedRooms.add(room);
                      }

                      _recalculateBaseAmount();
                      _fetchCancelInfo();
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
          ],
        );
      }).toList(),
    );
  }

  Future<void> _fetchCancelInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lodgeId = prefs.getInt('lodgeId');
      final bookingId = widget.booking['booking_id'];
      final baseAmount = widget.booking['baseamount'];
      final checkIn = widget.booking['check_in'];

      final url = Uri.parse('$baseUrl/cancels/cancel-price');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bookingId': bookingId,
          'baseAmount': baseAmount,
          'checkInDate': checkIn,
          'lodgeId': lodgeId,
        }),
      );

      if (response.statusCode == 200||response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          _cancelPercentageController.text = data['cancelPercentage'].toString();
          _cancelChargeController.text = data['cancellationCharge'].toStringAsFixed(2);
          _refundController.text = data['refund'].toStringAsFixed(2);
        });
      } else {
        _showMessage('Failed to fetch cancellation info');
      }
    } catch (e) {
      _showMessage('Error: $e');
    }
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

  Widget _cancelInfoSection(Map<String, dynamic> b) {
    final double baseAmount = b["baseamount"]?.toDouble() ?? 0.0;

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
              Center(
                child: Text("Unselect the rooms you need.",style: TextStyle(color: royal),),
              ),
              const SizedBox(height: 10),

              Center(
                child: buildBookedRoomSelector(),
              ),

              const SizedBox(height: 15),

              _cancelRow("No. of Days", "$numDays"),

              const SizedBox(height: 10),

              _cancelRow("No. of Rooms", "${selectedRooms.length}"),  

              const SizedBox(height: 10),

              _cancelRow("Base Amount", "₹${baseAmount.toStringAsFixed(2)}"), 

              const SizedBox(height: 10),

              _editableRow(
                "Reason",
                _reasonPercentageController,
                onChanged: (val) {},
                inputFormatters: [],
              ),

              const SizedBox(height: 10),

              _editableRow(
                "Cancel %",
                _cancelPercentageController,
                suffix: "%",
                onChanged: (val) {
                  double perc = double.tryParse(val) ?? 0;

                  final charge = (baseAmount * perc / 100).clamp(0, baseAmount);
                  final refund = (baseAmount - charge).clamp(0, baseAmount);

                  setState(() {
                    _cancelChargeController.text = charge.toStringAsFixed(2);
                    _refundController.text = refund.toStringAsFixed(2);
                  });
                },
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d{0,2})?$')),
                ],
              ),

              const SizedBox(height: 10),

                _editableRow(
                "Cancellation Charge",
                _cancelChargeController,
                onChanged: (val) {
                  double charge = double.tryParse(val) ?? 0;

                  final perc = ((charge / baseAmount) * 100).clamp(0, 100);
                  final refund = (baseAmount - charge).clamp(0, baseAmount);

                  setState(() {
                    _cancelPercentageController.text = perc.toStringAsFixed(2);
                    _refundController.text = refund.toStringAsFixed(2);
                  });
                },
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d{0,10}(\.\d{0,2})?$')),
                ],
              ),

              const SizedBox(height: 10),

              _editableRow(
                "Refund Amount",
                _refundController,
                onChanged: (val) {
                  double refund = double.tryParse(val) ?? 0;

                  final charge = (baseAmount - refund).clamp(0, baseAmount);
                  final perc = ((charge / baseAmount) * 100).clamp(0, 100);

                  setState(() {
                    _cancelChargeController.text = charge.toStringAsFixed(2);
                    _cancelPercentageController.text = perc.toStringAsFixed(2);
                  });
                },
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d{0,10}(\.\d{0,2})?$')),
                ],
              ),
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
                "CANCELLATION INFORMATION",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _partialCancel() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage("Please fill all required fields");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");
    final userId = prefs.getString("userId");
    final bookingID = widget.booking['booking_id'];

    if (lodgeId == null || userId == null) {
      _showMessage("Lodge ID or User ID not found!");
      return;
    }

    setState(() => submitting = true);

    final url = Uri.parse("$baseUrl/cancels/partial");

    final body = {
      "bookingId": bookingID,
      "lodgeId": lodgeId,
      "userId": userId,
      "roomNumbers": buildRoomNumbersPayload(),
      "reason": _reasonPercentageController.text,
      "amountPaid": widget.booking['baseamount'],
      "cancelCharge": double.tryParse(_cancelChargeController.text) ?? 0,
      "refund": double.tryParse(_refundController.text) ?? 0,
    };

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    setState(() => submitting = false);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);

      _showMessage("Cancellation Successful!");

      setState(() {
        bookingSuccess = true;
        bookingResponse = data;
      });

      _resetToOriginalState();

    } else {
      _showMessage("Cancellation failed: ${response.body}");
    }
  }

  Widget _cancelRow(String label, String value) {
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
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: royal, width: 1),
              color: royal.withValues(alpha: 0.05),
            ),
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: royal),
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

  Widget _editableRow(
      String label,
      TextEditingController controller, {
        String? prefix,
        String? suffix,
        required Function(String) onChanged,
        List<TextInputFormatter>? inputFormatters,
      }) {
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
            controller: controller,
            keyboardType: prefix == null && suffix == null
                ? TextInputType.text
                : const TextInputType.numberWithOptions(decimal: true),
            onChanged: onChanged,
            cursorColor: royal,
            inputFormatters: inputFormatters,
            textAlign: TextAlign.right,
            style: const TextStyle(color: royal),
            decoration: InputDecoration(
              suffixText: suffix,
              suffixStyle: const TextStyle(color: royal, fontWeight: FontWeight.bold),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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

  Widget _personalInfoSection(Map<String, dynamic> b) {
    bool hasvalue(dynamic val) => val != null && val.toString().trim().isNotEmpty;

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

              if (hasvalue(b["alternate_phone"])) ...[
                const SizedBox(height: 10),
                _infoTextField("Alt Phone", b["alternate_phone"]),
              ],

              if (hasvalue(b["email"])) ...[
                const SizedBox(height: 10),
                _infoTextField("Email", b["email"]),
              ],

              if (hasvalue(b["address"])) ...[
                const SizedBox(height: 10),
                _infoTextField("Address", b["address"]),
              ],
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
              const SizedBox(height: 10),

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
                      readOnly: true,
                      cursorColor: royal,
                      textAlign: TextAlign.right,
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
              _paymentRow("No. of Rooms", b["specification"]["number_of_rooms"].toString()),
              const SizedBox(height: 10),

              _paymentRow("Base Amount", "₹${b["baseamount"]}"),
              const SizedBox(height: 10),
              _paymentRow("GST", "₹${b["gst"]}"),
              const SizedBox(height: 10),
              _paymentRow("Total Amount", "₹${b["amount"]}"),
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
                "Booking ID: ${b["booking_id"]}",
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
          title: const Text("Partially Cancel Booking", style: TextStyle(color: Colors.white)),
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
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: bookingSuccess
                ? SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
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
                            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
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
                                  "Generate bill for cancellation.\nView it as PDF and download.",
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
                                        builder: (context) => PartialCancelBillPage(
                                          bookingDetails: widget.booking,
                                          serverData: bookingResponse,
                                          hallDetails:hallDetails,
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
                  const SizedBox(height: 40),
                  _cancelInfoSection(b),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: royal),
                      onPressed: submitting ? null : _partialCancel,
                      child: submitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Cancel Booking",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _personalInfoSection(b),
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
