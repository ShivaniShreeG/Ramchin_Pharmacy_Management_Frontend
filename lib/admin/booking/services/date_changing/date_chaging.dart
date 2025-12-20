import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../public/config.dart';
import '../../../../public/main_navigation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'whatsapp_share.dart';

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
  TextEditingController changeCheckInController = TextEditingController();
  TextEditingController changeCheckOutController = TextEditingController();
  Map<String, int> roomCounts = {};
  bool checkingAvailability = false;
  Map<String, dynamic>? availabilityResult;
  bool canSubmit = false;

  @override
  void initState() {
    super.initState();
    _fetchHallDetails();
    changeCheckInController.text = formatTo12Hour(DateTime.parse(widget.booking['check_in']));
    changeCheckOutController.text = formatTo12Hour(DateTime.parse(widget.booking['check_out']));


    for (var room in widget.booking['booked_room']) {
      final key = "${room[0]}-${room[1]}";
      roomCounts[key] = (room[2] as List).length;
    }
  }

  Future<void> _onSubmitPressed() async {
    if (availabilityResult == null || !canSubmit) {
      _showMessage("Please check availability first.");
      return;
    }

    DateTime checkIn = DateFormat('dd-MM-yyyy hh:mm a')
        .parse(changeCheckInController.text);

    DateTime checkOut = DateFormat('dd-MM-yyyy hh:mm a')
        .parse(changeCheckOutController.text);

    // Prepare rooms list from API availability result
    List<dynamic> updatedRooms = availabilityResult!['details'].map((room) {
      return {
        "room_name": room['room_name'],
        "room_type": room['room_type'],
        "rooms": room['rooms'], // updated room numbers
      };
    }).toList();

    try {
      final url = Uri.parse("$baseUrl/booking/update-date");
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "booking_id": widget.booking['booking_id'],
          "lodge_id": widget.booking['lodge_id'],
          "check_in": checkIn.toIso8601String(),
          "check_out": checkOut.toIso8601String(),
          "updated_rooms": updatedRooms,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);

        _showMessage("Booking updated successfully!");
        if(!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UpdatedBookingSummaryPage(
              oldBooking: widget.booking,
              newBooking: result["update_booking"], // FIXED
              hallDetails: hallDetails!,
            ),
          ),
        );
      } else {
        _showMessage("Update failed!");
      }
    } catch (e) {
      _showMessage("Error submitting: $e");
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

  Future<DateTime?> _pickDateTime(DateTime defaultDate) async {

    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: defaultDate,
      builder: (context, child) {
        final theme = Theme.of(context);

        return Theme(
          data: theme.copyWith(
            colorScheme: const ColorScheme.light(
              primary: royal,
              onPrimary: Colors.white,
              onSurface: royal,
            ),

            inputDecorationTheme: InputDecorationTheme(
              filled: false,
              fillColor: Colors.transparent,

              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: royal, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: royal, width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),

              labelStyle: const TextStyle(color: royal),
              hintStyle: const TextStyle(color: royal),
              suffixIconColor: royal,
            ),

            textTheme: theme.textTheme.copyWith(
              bodySmall:const TextStyle(color: royal) ,
              bodyMedium: const TextStyle(color: royal),
              bodyLarge: const TextStyle(color: royal),
              titleMedium: const TextStyle(color: royal),
            ),

            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: royal,
              selectionColor: Colors.white,
              selectionHandleColor: royal,
            ),

            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: royal,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (!mounted) return null;

    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            primaryColor: royal,
            colorScheme: const ColorScheme.light(
              primary: royal,
              onPrimary: Colors.white,
              onSurface: royal,
            ),

            textTheme: Theme.of(context).textTheme.copyWith(
              titleLarge: const TextStyle(
                color: royal,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),

            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: royal,
              selectionColor: royal,
              selectionHandleColor: royal,
            ),

            inputDecorationTheme: InputDecorationTheme(
              labelStyle: const TextStyle(color: royal),
              hintStyle: const TextStyle(color: royal),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: royal, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: royal, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
            ),

            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              dialHandColor: royal,
              dialBackgroundColor: royal.withValues(alpha: 0.08),
              dialTextColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return royal;
              }),
              hourMinuteColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return royal.withValues(alpha: 0.15);
                return royal.withValues(alpha: 0.1);
              }),
              hourMinuteTextColor: WidgetStateColor.resolveWith((states) => royal),
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: royal, width: 1.5),
              ),
              dayPeriodColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return royal;
                return royal.withValues(alpha: 0.1);
              }),
              dayPeriodTextColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return royal;
              }),
              dayPeriodBorderSide: const BorderSide(color: royal, width: 1.5),
              dayPeriodShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (time == null) return null;

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Widget _dateChangeSection() {
    final oldCheckIn = DateTime.parse(widget.booking['check_in']);
    final oldCheckOut = DateTime.parse(widget.booking['check_out']);
    final oldDuration = oldCheckOut.difference(oldCheckIn);
    Future<void> pickDateTimeController(TextEditingController controller, DateTime defaultDate) async {
      final picked = await _pickDateTime(defaultDate);
      if (picked != null) {
        // Update Check-In
        controller.text = formatTo12Hour(picked);

        // Auto-calculate Check-Out using original duration
        final newCheckOut = picked.add(oldDuration);
        changeCheckOutController.text = formatTo12Hour(newCheckOut);
      }
    }
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
              // Check-In
              const Text("Check-In", style: TextStyle(fontWeight: FontWeight.bold, color: royal)),
              const SizedBox(height: 5),
              TextFormField(
                style: const TextStyle(color: royal),
                controller: changeCheckInController,
                readOnly: true,
                onTap: () {
                  final defaultDate = DateTime.tryParse(widget.booking['check_in']) ?? DateTime.now();
                  pickDateTimeController(changeCheckInController, defaultDate);
                },
                decoration: _inputDecoration(),
              ),
              const SizedBox(height: 10),

              // Check-Out
              const Text("Check-Out", style: TextStyle(fontWeight: FontWeight.bold, color: royal)),
              const SizedBox(height: 5),
              TextFormField(
                style: const TextStyle(color: royal),
                controller: changeCheckOutController,
                readOnly: true, // user cannot manually edit
                decoration: _inputDecoration(),
              ),
              const SizedBox(height: 20),

              // Rooms
              const Text("Rooms", style: TextStyle(fontWeight: FontWeight.bold, color: royal)),
              const SizedBox(height: 5),
              Column(
                children: widget.booking['booked_room'].map<Widget>((room) {
                  final name = room[0]?.toString() ?? "-";
                  final type = room[1]?.toString() ?? "-";

                  List<String> roomsToShow = List<String>.from(room[2]);
                  String message = "Currently booked";

                  if (availabilityResult != null && availabilityResult!['details'] != null) {
                    final matched = availabilityResult!['details'].firstWhere(
                          (d) => d['room_name'] == name && d['room_type'] == type,
                      orElse: () => null,
                    );
                    if (matched != null) {
                      roomsToShow = List<String>.from(matched['rooms']);
                      message = matched['message'];
                    }
                  }

                  final roomNumbersText = roomsToShow.isNotEmpty ? roomsToShow.join(", ") : "-";

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("$name • $type", style: const TextStyle(color: royal)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text("Rooms: $roomNumbersText", style: const TextStyle(color: royal)),
                      Text(
                        message,
                        style: TextStyle(
                          color: message.contains("Available") ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  );
                }).toList(),
              ),

              // OK button
              Center(
                child: ElevatedButton(
                  onPressed: checkingAvailability ? null : _onCheckAvailabilityPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: royal,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(checkingAvailability ? "Checking..." : "OK"),
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
                "DATE & ROOM CHANGE",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onCheckAvailabilityPressed() async {
    DateTime? checkIn, checkOut;
    try {
      checkIn = DateFormat('dd-MM-yyyy hh:mm a').parse(changeCheckInController.text);
      checkOut = DateFormat('dd-MM-yyyy hh:mm a').parse(changeCheckOutController.text);
      if (!checkOut.isAfter(checkIn)) {
        _showMessage("Check-out must be after check-in!");
        return;
      }
    } catch (_) {
      _showMessage("Invalid date format!");
      return;
    }

    setState(() => checkingAvailability = true);

    try {
      final roomRequests = roomCounts.entries.map((e) {
        final split = e.key.split('-');
        return {
          "room_name": split[0],
          "room_type": split[1],
          "count": e.value,
        };
      }).toList();

      final url = Uri.parse('$baseUrl/booking/check-availability');
      final resp = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "lodge_id": widget.booking['lodge_id'],
          "check_in": checkIn.toIso8601String(),
          "check_out": checkOut.toIso8601String(),
          "room_requests": roomRequests,
        }),
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = jsonDecode(resp.body);
        setState(() {
          availabilityResult = data;
          canSubmit = data['all_available'] == true;   // ENABLE SUBMIT
        });

        if (data['all_available']) {
          _showMessage("All rooms available for selected dates!");
        } else {
          _showMessage("Some rooms are not available");
        }
      } else {
        _showMessage("Error checking availability");
      }
    } catch (e) {
      _showMessage("Error: $e");
    } finally {
      setState(() => checkingAvailability = false);
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

  Widget _personalInfoSection(Map<String, dynamic> b) {
    bool hasValue(dynamic val) =>
        val != null && val
            .toString()
            .trim()
            .isNotEmpty;

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
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
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
            // Right-align the value
            style: const TextStyle(color: royal),
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
          padding: const EdgeInsets.only(
              top: 25, left: 12, right: 12, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              _paymentRow("No. of Days",
                  b["specification"]["number_of_days"].toString()),
              const SizedBox(height: 10),

              _paymentRow("No. of Rooms",
                  b["specification"]["number_of_rooms"].toString()),
              const SizedBox(height: 10),

              _paymentRow("Base Amount", "₹${b["baseamount"]}"),
              const SizedBox(height: 10),

              _paymentRow("GST", "₹${b["gst"]}"),
              const SizedBox(height: 10),

              _paymentRow("Total Amount", "₹${b["amount"]}"),
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
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text(
            "Date Changing", style: TextStyle(color: Colors.white)),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (hallDetails != null) _buildHallCard(hallDetails!),
            const SizedBox(height: 30),
            _dateChangeSection(),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton(
                onPressed: canSubmit ? _onSubmitPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSubmit ? Colors.green : Colors.grey,
                  foregroundColor: Colors.white,
                ),
                child: const Text("SUBMIT"),
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 6, horizontal: 12),
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
            const SizedBox(height: 70),
          ],
        ),
      ),
    );
  }
}
