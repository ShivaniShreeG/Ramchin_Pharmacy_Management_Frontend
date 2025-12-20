import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../public/config.dart';
import '../../../../public/main_navigation.dart';
import '../../../../public/alternate_phone_formatter.dart';
import 'package:url_launcher/url_launcher.dart';

const Color royal = Color(0xFF19527A);

class PreBookingPage extends StatefulWidget {
  final DateTime checkIn;
  final DateTime checkOut;
  final List<List<dynamic>> bookedRooms;

  const PreBookingPage({
    super.key,
    required this.checkIn,
    required this.checkOut,
    required this.bookedRooms,
  });

  @override
  State<PreBookingPage> createState() => _PreBookingPageState();
}

class _PreBookingPageState extends State<PreBookingPage> {
  bool submitting = false;
  bool loadingPrice = true;
  final TextEditingController advanceController = TextEditingController(text:"0");
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController altPhoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController balanceController = TextEditingController();
  final TextEditingController depositController = TextEditingController(text: "0");
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  double balance = 0;
  double deposit = 0.0;
  String? selectedPaymentMethod;

  Map<String, dynamic>? pricingData;
  List<String> selectedRoomNumbers = [];
  Map<String, dynamic>? hallDetails;
  List<Uint8List?> guestIdBytes = [];
  int numGuests = 1;

  String pricingType = "NORMAL";
  double? overriddenBaseAmount;
  bool bookingSuccess = false;
  Map<String, dynamic>? bookingDetails;
  List<String> getAllRoomNumbers() {
    List<String> allNumbers = [];
    for (var room in widget.bookedRooms) {
      List<String> nums = List<String>.from(room[2]);
      allNumbers.addAll(nums);
    }
    return allNumbers;
  }

  List<Map<String, String>> getRoomDetails() {
    return widget.bookedRooms.map((room) {
      return {
        "room_name": room[0].toString(),
        "room_type": room[1].toString(),
        "numbers": jsonEncode(room[2]),
      };
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchPricing();
    _fetchHallDetails();
    phoneController.addListener(_onPhoneChanged);
    selectedRoomNumbers = getAllRoomNumbers();
    phoneController.text = '+91';
    phoneController.selection = TextSelection.fromPosition(
      TextPosition(offset: phoneController.text.length),
    );
  }

  void _onPhoneChanged() {
    final phone = phoneController.text.trim();
    if (phone.length == 13) {
      _fetchBookingByPhone(phone);
    }
  }

  @override
  void dispose() {
    phoneController.removeListener(_onPhoneChanged);
    phoneController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:  TextStyle(
            color: royal,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: royal,width: 2)
        ),
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
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

  Future<void> _fetchPricing({String? newPricingType}) async {
    setState(() {
      loadingPrice = true;
      pricingData = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final lodgeId = prefs.getInt("lodgeId");
      if (lodgeId == null) throw Exception("Lodge ID not found");

      final body = {
        "lodge_id": lodgeId,
        "booked_rooms": widget.bookedRooms,
        "check_in": widget.checkIn.toIso8601String(),
        "check_out": widget.checkOut.toIso8601String(),
      };

      if (newPricingType != null) body["pricing_type"] = newPricingType;

      final url = Uri.parse(
          "$baseUrl/calendar/${newPricingType != null ? "update-pricing" : "calculate-pricing"}"
      );

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          pricingType = (data["status"] ?? "NORMAL").toString();
          pricingData = {
            "gst_rate": data["gst_rate"],
            "num_days": data["num_days"],
            "total_base": data["total_base_amount"],
            "gst": data["gst_amount"],
            "grand_total": data["total_amount"],
            "groups": data["rooms"],
          };

          if (data["rooms"] != null && data["rooms"].isNotEmpty) {
            overriddenBaseAmount =
                data["rooms"][0]["base_amount_per_room"]?.toDouble();
          }
        });

        _recalculateGroupPricing();
      } else {
        _showMessage("Pricing error: ${response.body}");
      }
    } catch (e) {
      _showMessage("Error fetching pricing: $e");
    } finally {
      setState(() => loadingPrice = false);
    }
  }

  Widget _paymentSection() {
    if (pricingData == null) return const SizedBox();

    final groups = pricingData!["groups"] ?? [];
    final numDays = pricingData!["num_days"] ?? 1;

    const double labelWidth = 120;

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
            children: [
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: const Text(
                      "Pricing Type",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: royal,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: royalLight.withValues(alpha: 0.1),
                        border: Border.all(color: royal, width: 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: pricingType,
                          isExpanded: true,
                          alignment: Alignment.centerRight,
                          dropdownColor: Colors.white,
                          icon: const Icon(Icons.arrow_drop_down, color: royal),
                          style: const TextStyle(
                            color: royal,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: "NORMAL",
                              child: Text("Normal", style: TextStyle(color: royal)),
                            ),
                            DropdownMenuItem(
                              value: "PEAK_HOUR",
                              child: Text("Peak Hour", style: TextStyle(color: royal)),
                            ),
                          ],
                          onChanged: (value) async {
                            if (value == null) return;
                            setState(() => pricingType = value);
                            await _fetchPricing(newPricingType: value);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _labelValueRowStyled("Total Rooms", selectedRoomNumbers.length.toString(), labelWidth),
              const SizedBox(height: 10),
              _labelValueRowStyled("No of Days", numDays.toString(), labelWidth),
              const SizedBox(height: 10),
              ...groups.map<Widget>((group) {
                final name = group["room_name"];
                final type = group["room_type"];
                final count = group["room_count"];
                final base = group["base_amount_per_room"];
                final groupTotal = group["group_total_base_amount"];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Text(
                          "$name - $type",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: royal,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _labelValueRowStyled("Rooms", count.toString(), labelWidth),
                    const SizedBox(height: 10),
                    _editableRow(
                      "Base",
                      labelWidth,
                          (val) {
                        final newBase = double.tryParse(val);
                        if (newBase != null) {
                          group["base_amount_per_room"] = newBase;
                          group["group_total_base_amount"] =
                              newBase * group["room_count"] * numDays;
                          _recalculateGroupPricing();
                        }
                      },
                      initialValue: base.toString(),
                    ),
                    const SizedBox(height: 10),
                    _labelValueRowStyled("Total", "₹${groupTotal.toString()}", labelWidth),
                    const SizedBox(height: 10),
                  ],
                );
              }),
              Divider(
                color: royal,
                thickness: 1,
                height: 20,
              ),
              _labelValueRowStyled("Total Base", pricingData!["total_base"].toString(), labelWidth),
              const SizedBox(height: 10),
              _labelValueRowStyled("GST ${pricingData!["gst_rate"]}%", pricingData!["gst"].toString(), labelWidth),
              const SizedBox(height: 10),
              _labelValueRowStyled("Total Amount", pricingData!["grand_total"].toString(), labelWidth, bold: true),
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
              child: const Text(
                "PRICE DETAILS",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
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

  Widget _labelValueRowStyled(String label, String value, double labelWidth, {bool bold = false}) {
    final controller = TextEditingController(text: value);

    return Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, color: royal),
          ),
        ),
        Expanded(
          child: TextField(
            readOnly: true,
            controller: controller,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: royal,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: royalLight.withValues(alpha: 0.1),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: royal, width: 1),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: royal, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _editableRow(
      String label,
      double width,
      Function(String) onChanged, {
        TextEditingController? controller,
        String? initialValue,
      }) {
    return Row(
      children: [
        SizedBox(
          width: width,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: royal,
            ),
          ),
        ),
        Expanded(
          child: TextFormField(
            cursorColor: royal,
            controller: controller,
            initialValue: controller == null ? initialValue : null,
            textAlign: TextAlign.right,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontSize: 14,
              color: royal,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: royalLight.withValues(alpha: 0.1),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: royal, width: 1),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: royal, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (val) {
              onChanged(val);
            },
          ),
        ),
      ],
    );
  }

  void _recalculateGroupPricing() {
    final groups = pricingData!["groups"];
    final gstRate = pricingData!["gst_rate"] ?? 18;

    double newTotalBase = 0;

    for (var grp in groups) {
      newTotalBase += (grp["group_total_base_amount"] ?? 0.0).toDouble();
    }

    final gstAmount = (newTotalBase * gstRate / 100);
    final grandTotal = newTotalBase + gstAmount;

    setState(() {
      pricingData!["total_base"] = newTotalBase;
      pricingData!["gst"] = gstAmount;
      pricingData!["grand_total"] = grandTotal;

      final advance = double.tryParse(advanceController.text) ?? 0.0;
      balanceController.text = (grandTotal - advance).toStringAsFixed(2);
    });
  }

  Widget _personalInfoSection() {
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
            children: [
              const SizedBox(height: 10),
              _buildRow(
                "Phone",
                phoneController,
                keyboardType: TextInputType.number,
                maxLength: 13,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Phone is required";
                  if (!RegExp(r'^\+\d{1,4}\d{10}$').hasMatch(val)) {
                    return "Include country code and exactly 10 digits";
                  }
                  return null;
                },
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d+]')), // allow digits and +
                  LengthLimitingTextInputFormatter(13),
                ],
                hideCounter: true,
              ),
              const SizedBox(height: 10),
              _buildRow("Name", nameController, validator: (val) {
                if (val == null || val.trim().isEmpty) return "Name is required";
                return null;
              }),
              const SizedBox(height: 10),
              _buildRow(
                "Alternate Phone",
                altPhoneController,
                keyboardType: TextInputType.number,
                inputFormatters: [AlternatePhoneFormatter()],
                validator: (val) {
                  if (val != null && val.isNotEmpty) {
                    final numbers = val.split(',');
                    for (var n in numbers) {
                      if (n.length != 10) return "Each phone must be 10 digits";
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _buildRow("Address", addressController, validator: (val) {
                if (val == null || val.trim().isEmpty) return "Address is required";
                return null;
              }),
              const SizedBox(height: 10),
              _buildRow(
                "Email",
                emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val != null && val.isNotEmpty) {
                    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+\w{2,4}').hasMatch(val)) {
                      return "Enter valid email";
                    }
                  }
                  return null;
                },
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
                "PERSONAL INFORMATION",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _guestsSection() {
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
            children: [
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
                    flex: 3,
                    child: TextFormField(
                      initialValue: numGuests.toString(),
                      keyboardType: TextInputType.number,
                      cursorColor: royal,
                      style: TextStyle(color: royal),
                      onChanged: (value) {
                        setState(() {
                          numGuests = int.tryParse(value) ?? 1;
                        });
                      },
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                    ),
                  ),
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
                "GUESTS",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _bookRooms() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage("Please fill all required fields");
      return;
    }
    if (selectedRoomNumbers.isEmpty) {
      _showMessage("Select at least one room.");
      return;
    }
    final paymentMethod = await _selectPaymentMethod();
    if (paymentMethod == null) {
      _showMessage("Please select a payment method");
      return;
    }
    selectedPaymentMethod = paymentMethod;
    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");
    final userId = prefs.getString("userId");

    if (lodgeId == null || userId == null) {
      _showMessage("Lodge ID or User ID not found!");
      return;
    }

    setState(() => submitting = true);

    final roomCount = selectedRoomNumbers.length;
    final numDays = pricingData?["num_days"] ?? 1;
    final totalBase = pricingData?["total_base"] ?? 0.0;
    final gstAmount = pricingData?["gst"] ?? 0.0;
    final grandTotal = pricingData?["grand_total"] ?? 0.0;
    final advance = grandTotal;
    final balance = 0.0;


    final roomsPayload = (pricingData?["groups"] as List<dynamic>? ?? []).map((group) {
      return {
        "room_name": group["room_name"],
        "room_type": group["room_type"],
        "room_count": group["room_count"],
        "base_amount_per_room": group["base_amount_per_room"],
        "group_total_base_amount": group["group_total_base_amount"],
      };
    }).toList();

    final uri = Uri.parse("$baseUrl/booking/pre-book");

    try {
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "lodge_id": lodgeId.toString(),
          "user_id": userId,
          "name": nameController.text,
          "phone": phoneController.text,
          "alternate_phone": altPhoneController.text,
          "email": emailController.text,
          "address": addressController.text,
          "numberofguest": numGuests.toString(),
          "specification": jsonEncode({
            "number_of_days": numDays,
            "number_of_rooms": roomCount,
          }),
          "check_in": widget.checkIn.toIso8601String(),
          "check_out": widget.checkOut.toIso8601String(),
          "baseamount": totalBase.toString(),
          "gst": gstAmount.toString(),
          "amount": grandTotal.toString(),
          "advance": advance.toString(),
          "balance": balance.toString(),
          "rooms": jsonEncode(roomsPayload),
          "booked_rooms": jsonEncode(widget.bookedRooms),
          "payment_method": selectedPaymentMethod!,
        }),
      );
      setState(() => submitting = false);

      dynamic responseJson;
      try {
        responseJson = jsonDecode(response.body);
      } catch (e) {
        responseJson = {"message": response.body};
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage(responseJson['message'] ?? 'Booking Successful!');

        setState(() {
          bookingSuccess = true;
          bookingDetails = responseJson["booking"];
        });
      }
      else {
        _showMessage("Booking failed: ${responseJson['message'] ?? response.body}");
      }
    } catch (e) {
      setState(() => submitting = false);
      _showMessage("Booking failed: $e");
    }
  }

  Widget _bookingInfoSection() {
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
              const SizedBox(height: 20),
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
                      initialValue: formatTo12Hour(widget.checkIn),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
                      initialValue: formatTo12Hour(widget.checkOut),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Center(
                child: Text(
                  "Selected Room Details",
                  style: const TextStyle(
                    color: royal,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Column(
                  children: widget.bookedRooms.map((room) {
                    final name = room[0];
                    final type = room[1];
                    final nums = List<String>.from(room[2]);

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: royal),
                      ),
                      child: ListTile(
                        title: Text("$type - $name", style: TextStyle(color: royal, fontWeight: FontWeight.bold)),
                        subtitle: Text("Rooms: ${nums.join(', ')}", style: TextStyle(color: royal)),
                      ),
                    );
                  }).toList(),
                ),
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
                "BOOKING INFORMATION",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHallCard(Map<String, dynamic> hall) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      padding: const EdgeInsets.all(16),
      height: 95,
      decoration: BoxDecoration(
        color: royal,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: royal, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: royal.withValues(alpha:0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              child: const Icon(
                Icons.home_work_rounded,
                color: royal,
                size: 35,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                hall['name']?.toString().toUpperCase() ?? "LODGE NAME",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
      String label,
      TextEditingController controller, {
        TextInputType keyboardType = TextInputType.text,
        int? maxLength,
        String? Function(String?)? validator,
        bool hideCounter = false,
        List<TextInputFormatter>? inputFormatters,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Padding(
            padding: const EdgeInsets.only(top: 15),
            child: Text(label, style: const TextStyle(color: royal,fontWeight: FontWeight.bold)),
          ),
        ),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            cursorColor: royal,
            style: TextStyle(color: royal),
            validator: validator,
            decoration: _inputDecoration(
              label: label,
              counterText: hideCounter ? '' : null,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _fetchBookingByPhone(String phone) async {
    if (phone.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lodgeId = prefs.getInt("lodgeId");
      if (lodgeId == null) return;

      final url = Uri.parse("$baseUrl/booking/latest/$lodgeId/$phone");

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data != null) {
          setState(() {
            nameController.text = data["name"] ?? "";
            addressController.text = data["address"] ?? "";
            altPhoneController.text = data["alternate_phone"] ?? "";
            emailController.text = data["email"] ?? "";
          });
        }
      }
    } catch (e) {
      _showMessage("Error fetching previous booking: $e");
    }
  }

  InputDecoration _inputDecoration({required String label, String? counterText}) {
    String lowerLabel = lowercaseFirst(label);
    return InputDecoration(
      hintText: "Enter the $lowerLabel",
      hintStyle: TextStyle(color: royal.withValues(alpha: 0.7)),
      filled: true,
      fillColor: royal.withValues(alpha: 0.05),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: royal, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: royal, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      errorBorder: OutlineInputBorder(
        borderSide:
        const BorderSide(color: Colors.redAccent, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide:
        const BorderSide(color: Colors.redAccent, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      counterText: counterText,
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

  Widget buildLabelValueBooking(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(80),
          1: FixedColumnWidth(5),
          2: FlexColumnWidth(),
        },
        children: [
          TableRow(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12,color: royal)),
              const Text(":", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,color: royal)),
              Text(value, style: const TextStyle(fontSize: 12,color: royal)),
            ],
          ),
        ],
      ),
    );
  }

  String lowercaseFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toLowerCase() + text.substring(1);
  }

  Widget bookingDetailsCard({
    required Map<String, dynamic> booking,
    required Color royal,
  }) {

    String formatTo12Hour(DateTime dt) {
      return "${dt.day.toString().padLeft(2, '0')}-"
          "${dt.month.toString().padLeft(2, '0')}-"
          "${dt.year} "
          "${(dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString().padLeft(2, '0')}:"
          "${dt.minute.toString().padLeft(2, '0')} "
          "${dt.hour >= 12 ? "PM" : "AM"}";
    }

    String formatDateTime(String? dateTimeStr) {
      if (dateTimeStr == null) return 'N/A';
      try {
        final dt = DateTime.parse(dateTimeStr);
        return formatTo12Hour(dt);
      } catch (e) {
        return 'Invalid date';
      }
    }

    final bookedRooms = booking['booked_room'] as List<dynamic>?;

    List<String> alternatePhones = [];
    if (booking['alternate_phone'] != null &&
        booking['alternate_phone'].toString().isNotEmpty) {
      try {
        final alt = jsonDecode(booking['alternate_phone'].toString());
        if (alt is List) alternatePhones = alt.map((e) => e.toString()).toList();
      } catch (_) {
        alternatePhones =
            booking['alternate_phone'].toString().split(',').map((e) => e.trim()).toList();
      }
    }

    String generateShareText() {

      final buffer = StringBuffer();

      buffer.writeln("```");
      buffer.writeln("   Booking Confirmation");
      buffer.writeln("---------------------------");
      buffer.writeln("This is your official booking confirmation"
          " message from ${hallDetails?['name']},${hallDetails?['address']}");
      buffer.writeln("📱 ${hallDetails?['phone']}");
      buffer.writeln("");

      buffer.writeln("Booking ID  : ${booking['booking_id']}");
      buffer.writeln("⚠️ Keep your Booking ID for future reference.");
      buffer.writeln("");

      buffer.writeln("     Booking Details");
      buffer.writeln("");

      buffer.writeln("Name      : ${booking['name']}");
      buffer.writeln("Phone     : ${booking['phone']}");

      if (alternatePhones.isNotEmpty) {
        buffer.writeln("Alt Phone : ${alternatePhones.join(', ')}");
      }

      if (booking['email'] != null && booking['email'].toString().trim().isNotEmpty){
        buffer.writeln("Email     : ${booking['email']}");
      }

      if (booking['address'] != null) {
        buffer.writeln("Address   : ${booking['address']}");
      }

      buffer.writeln("");

      buffer.writeln("       Booking Info");
      buffer.writeln("");

      buffer.writeln("Check-in     : ${formatDateTime(booking['check_in'])}");
      buffer.writeln("Check-out    : ${formatDateTime(booking['check_out'])}");

      if (bookedRooms != null && bookedRooms.isNotEmpty) {
        for (var room in bookedRooms) {
          final name = room[0]?.toString() ?? '';
          final type = room[1]?.toString() ?? '';
          final nums = List<String>.from(room[2] ?? []);

          buffer.writeln("Room Type    : $type - $name");
          if (nums.isNotEmpty) {
            buffer.writeln("Room Numbers : ${nums.join(', ')}");
          }
          buffer.writeln("");
        }
      }

      if (booking['numberofguest'] != null) {
        buffer.writeln("No. of Guests: ${booking['numberofguest']}");
      }

      buffer.writeln("");
      buffer.writeln("      Payment Details");
      buffer.writeln("");

      buffer.writeln("Base Amount     : ${booking['baseamount']}");
      buffer.writeln("GST             : ${booking['gst']}");
      buffer.writeln("Total Amount    : ${booking['amount']}");
      buffer.writeln("");

      buffer.writeln("---------------------------");
      buffer.writeln("Thank you for choosing us! 😊");
      buffer.writeln("```");

      return buffer.toString();
    }

    Future<void> shareViaWhatsApp() async {
      if (booking['phone'] == null || booking['phone'].toString().isEmpty) return;

      final text = Uri.encodeComponent(generateShareText());
      final phoneNumber = booking['phone'].toString().replaceAll(' ', '');
      final url = 'https://wa.me/$phoneNumber?text=$text';

      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        debugPrint("Cannot launch WhatsApp");
      }
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: royal, width: 2),
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: royal.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                if (booking['name'] != null || booking['phone'] != null)
                  Column(
                    children: [
                      if (booking['name'] != null)
                        buildLabelValueBooking("Name", booking['name']),
                      if (booking['phone'] != null)
                        buildLabelValueBooking("Phone", booking['phone']),
                      if (booking['address'] != null)
                        buildLabelValueBooking("Address", booking['address']),
                      if (alternatePhones.isNotEmpty)
                        buildLabelValueBooking("Alt Phone", alternatePhones.join(', ')),
                      if (booking['email'] != null && booking['email'].toString().trim().isNotEmpty)
                        buildLabelValueBooking("Email", booking['email']),
                    ],
                  ),

                const SizedBox(height: 15),
                Divider(color: royal, thickness: 1),
                const SizedBox(height: 10),

                Column(
                  children: [
                    if (booking['check_in'] != null)
                      buildLabelValueBooking("Check-in", formatDateTime(booking['check_in'])),
                    if (booking['check_out'] != null)
                      buildLabelValueBooking("Check-out", formatDateTime(booking['check_out'])),
                    if (booking['numberofguest'] != null)
                      buildLabelValueBooking("Guests", booking['numberofguest'].toString()),
                    if (bookedRooms != null && bookedRooms.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                "Booked Rooms",
                                style: TextStyle(
                                  color: royal,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          ...bookedRooms.map((room) {
                            final name = room[0]?.toString() ?? '';
                            final type = room[1]?.toString() ?? '';
                            final nums = List<String>.from(room[2] ?? []);

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  buildLabelValueBooking("Room", "$type - $name"),
                                  if (nums.isNotEmpty)
                                    buildLabelValueBooking("Room Numbers", nums.join(', ')),
                                ],
                              ),
                            );
                          })
                        ],
                      ),
                  ],
                ),

                const SizedBox(height: 15),
                Divider(color: royal, thickness: 1),
                const SizedBox(height: 10),
                Column(
                  children: [
                    if (booking['baseamount'] != null)
                      buildLabelValueBooking("Base Amount", booking['baseamount'].toString()),
                    if (booking['gst'] != null)
                      buildLabelValueBooking("GST", booking['gst'].toString()),
                    if (booking['amount'] != null)
                      buildLabelValueBooking("Total Amount", booking['amount'].toString()),
                  ],
                ),


                const SizedBox(height: 20),

                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: royal),
                    onPressed: shareViaWhatsApp,
                    icon: const Icon(Icons.share, color: Colors.white),
                    label: const Text(
                      "Share via WhatsApp",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 10,
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
              child: Text(
                "Booking ID: ${booking['booking_id']}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
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
        title: const Text("Room Pre-Booking", style: TextStyle(color: Colors.white)),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hallDetails != null) _buildHallCard(hallDetails!),
                const SizedBox(height: 20),

                bookingDetailsCard(booking: bookingDetails!, royal: royal),
                const SizedBox(height: 70),
              ],
            ),
          )
              : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hallDetails != null)
                  _buildHallCard(hallDetails!),
                const SizedBox(height: 40),
                _personalInfoSection(),
                const SizedBox(height: 40),
                _bookingInfoSection(),
                const SizedBox(height: 40),
                _guestsSection(),
                const SizedBox(height: 40),
                _paymentSection(),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: royal),
                    onPressed: submitting ? null : _bookRooms,
                    child: submitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Confirm Booking", style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 70),
              ],
            ),
          ),
        ),
      ),
    )
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
