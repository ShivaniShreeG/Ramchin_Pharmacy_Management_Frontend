import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../public/config.dart';
import '../../../../public/main_navigation.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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
  final TextEditingController _depositController = TextEditingController(text: "0");
  List<Uint8List?> guestIdBytes = [];
  bool bookingSuccess = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool submitting = false;
  Map<String, dynamic>? bookingResponse;
  int visibleAadhaarCount = 1;
  List<TextEditingController> aadhaarControllers = [];

  int numGuests = 1;
  List<File?> guestIdProofs = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchHallDetails();
    aadhaarControllers = List.generate(numGuests, (_) => TextEditingController());
    numGuests = widget.booking.containsKey('numberofguest')
        ? (widget.booking['numberofguest'] as int)
        : 1;
    guestIdProofs = [null];
    guestIdBytes = [null];
  }

  @override
  void dispose() {
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _bookRooms() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage("Please fill all required fields");
      return;
    }

    final validProofs = guestIdProofs.where((file) => file != null).toList();

    if (validProofs.isEmpty) {
      _showMessage("Please upload at least one guest ID proof.");
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

    final deposite = double.tryParse(_depositController.text) ?? 0.0;

    final uri = Uri.parse("$baseUrl/booking/$lodgeId/$bookingID");
    var request = http.MultipartRequest('PUT', uri);

    request.fields.addAll({
      "numberofguest": numGuests.toString(),
      "deposite": deposite.toStringAsFixed(2),
      "aadhar_number": jsonEncode(
        aadhaarControllers
            .map((c) => c.text.trim())
            .where((text) => text.isNotEmpty)
            .toList(),
      ),
    });

    for (int i = 0; i < validProofs.length; i++) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'id_proofs',
          validProofs[i]!.path,
        ),
      );
    }
    final streamedResponse = await request.send();
    final respBody = await streamedResponse.stream.bytesToString();
    dynamic responseJson;

    try {
      responseJson = jsonDecode(respBody);
    } catch (e) {
      responseJson = {"message": respBody};
    }

    setState(() => submitting = false);

    if (streamedResponse.statusCode == 200 ||streamedResponse.statusCode == 201) {
      _showMessage(responseJson['message'] ?? 'Booking Successful!');
      if(!mounted) return;
      setState(() {
        bookingSuccess = true;
        bookingResponse = responseJson['booking'];
      });
    } else {
      _showMessage("Booking failed: ${responseJson['message'] ?? respBody}");
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
                        fillColor: royal.withAlpha(12),
                        isDense: true,
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                      onChanged: (val) {
                        int newCount = int.tryParse(val) ?? 1;
                        if (newCount < 1) newCount = 1;
                        setState(() {
                          numGuests = newCount;

                          if (visibleAadhaarCount > numGuests) {
                            visibleAadhaarCount = numGuests;
                          }
                          if (aadhaarControllers.length > numGuests) {
                            aadhaarControllers = aadhaarControllers.sublist(0, numGuests);
                          } else if (aadhaarControllers.length < numGuests) {
                            aadhaarControllers.addAll(
                                List.generate(numGuests - aadhaarControllers.length, (_) => TextEditingController())
                            );
                          }

                          if (guestIdProofs.length > newCount) {
                            guestIdProofs = guestIdProofs.sublist(0, newCount);
                            guestIdBytes = guestIdBytes.sublist(0, newCount);
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Column(
                children: List.generate(visibleAadhaarCount, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            "Guest ${index + 1} ID Proof",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, color: royal),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: aadhaarControllers[index],
                            keyboardType: TextInputType.number,
                            maxLength: 20,
                            style: const TextStyle(color: royal),
                            cursorColor: royal,
                            decoration: InputDecoration(
                              hintText: "Enter your ID Proof number",
                              hintStyle: TextStyle(color: royal),
                              counterText: "",
                              filled: true,
                              fillColor: royal.withAlpha(12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: royal, width: 1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: royal, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "ID Proof required";
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 5),
                        if (visibleAadhaarCount > 1)
                          IconButton(
                            onPressed: () {
                              setState(() {
                                visibleAadhaarCount--;
                              });
                            },
                            icon: Icon(Icons.remove_circle, color: Colors.red),
                          ),
                      ],
                    ),
                  );
                }),
              ),

              const SizedBox(height: 5),

              Align(
                alignment: Alignment.center,
                child: ElevatedButton.icon(
                  onPressed: visibleAadhaarCount < numGuests
                      ? () {
                    setState(() {
                      visibleAadhaarCount++;
                    });
                  }
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text("Add Guest Aadhaar"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: visibleAadhaarCount < numGuests ? royal : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Column(
                children: List.generate(guestIdProofs.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () {
                              final bytes = guestIdBytes[index];
                              if (bytes != null) {
                                showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 300,
                                        height: 400,
                                        child: Image.memory(bytes, fit: BoxFit.contain),
                                      ),
                                    ),
                                  ),
                                );
                              } else {
                                _showMessage("No image selected for Guest ${index + 1}");
                              }
                            },
                            child: Row(
                              children: [
                                Text(
                                  "Guest ${index + 1} ID",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, color: royal),
                                ),
                                if (guestIdBytes[index] != null) ...[
                                  const SizedBox(width: 5),
                                  const Icon(Icons.preview, size: 18, color: royal),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: royal,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(170, 36),
                                  ),
                                  onPressed: () => _pickImage(index),
                                  child: Text(
                                    guestIdBytes[index] != null ? "Selected" : "Upload",
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              if (guestIdProofs.length > 1)
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      guestIdProofs.removeAt(index);
                                      guestIdBytes.removeAt(index);
                                    });
                                  },
                                  icon: Icon(Icons.remove_circle, color: Colors.red),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),

              const SizedBox(height: 12),

              Align(
                alignment: Alignment.center,
                child: ElevatedButton.icon(
                  onPressed: guestIdProofs.length < numGuests
                      ? () {
                    setState(() {
                      guestIdProofs.add(null);
                      guestIdBytes.add(null);
                    });
                  }
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text("Add Guest ID"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: guestIdProofs.length < numGuests ? royal : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
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
                "GUESTS",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage(int index) async {
    if (index >= guestIdBytes.length || index >= guestIdProofs.length) {
      _showMessage("Guest list not ready yet. Try again.");
      return;
    }

    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: royal),
        ),
        title: Text(
          "Select Image Source",
          style: const TextStyle(
            color: royal,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Choose the source for the guest ID",
              style: TextStyle(color: royal),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, ImageSource.camera),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: royal,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Camera"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, ImageSource.gallery),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: royal,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Gallery"),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: royal,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Cancel"),
              ),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1080,
        maxHeight: 1920,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();

        setState(() {
          guestIdBytes[index] = bytes;
          guestIdProofs[index] = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showMessage("Error picking image: $e");
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
          padding: const EdgeInsets.only(top: 25, left: 12, right: 12, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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

              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    flex: 2,
                    child: Text(
                      "Deposit:",
                      style: TextStyle(fontWeight: FontWeight.bold, color: royal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: _depositController,
                      cursorColor: royal,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: royal),
                      decoration: _inputDecoration().copyWith(
                        hintText: "Enter deposit amount",
                        hintStyle: TextStyle(color: royal.withValues(alpha: 0.5)),
                      ),
                      onTap: () {
                        if (_depositController.text == "0") {
                          _depositController.clear();
                        }
                      },
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
    final idProofs = booking['id_proof'] as List<dynamic>?;
    final aadhaarList = (booking['aadhar_number'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();

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
      buffer.writeln("   Check-IN Confirmation");
      buffer.writeln("---------------------------");
      buffer.writeln("This is your official Check-In confirmation"
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

      if (booking['email'] != null) {
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
      double dep = double.tryParse(booking['deposite']?.toString() ?? "0") ?? 0;
      if (dep > 0) {
        buffer.writeln("Deposit Paid    : ${booking['deposite']}");
      }

      double adv = double.tryParse(booking['advance']?.toString() ?? "0") ?? 0;
      double totalPaid = adv + dep;

      if (dep > 0) {
        buffer.writeln("Total Paid      : $totalPaid");
      }
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
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
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
                    if (booking['numberofguest'] != null)
                      buildLabelValueBooking("Guests", booking['numberofguest'].toString()),
                    if (aadhaarList != null && aadhaarList.isNotEmpty)
                      buildLabelValueBooking("Aadhaar Numbers", aadhaarList.join(', ')),
                    if (idProofs != null && idProofs.isNotEmpty)
                      buildLabelValueBooking("ID Proofs", idProofs.join(', ')),
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
                    if (booking['deposite'] != null && booking['deposite'].toString().trim() != "0" &&
                        booking['deposite'].toString().trim() != "0.0")
                      buildLabelValueBooking("Deposite", booking['deposite'].toString()),
                    if (booking['deposite'] != null &&booking['deposite'].toString().trim() != "0" &&
                        booking['deposite'].toString().trim() != "0.0")
                      buildLabelValueBooking("Total Paid",  (
                          (booking['advance'] != null ? double.tryParse(booking['advance'].toString()) ?? 0 : 0) +
                              (booking['deposite'] != null ? double.tryParse(booking['deposite'].toString()) ?? 0 : 0)
                      ).toString() ),
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
          title: const Text("Check-In", style: TextStyle(color: Colors.white)),
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
            child: bookingSuccess && bookingResponse != null
                ? SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hallDetails != null) _buildHallCard(hallDetails!),
                  const SizedBox(height: 20),
                  bookingDetailsCard(booking: bookingResponse!, royal: royal),
                  const SizedBox(height: 70),
                ],
              ),
            )
                : SingleChildScrollView(
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
                  _guestsSection(),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: royal),
                      onPressed: submitting ? null : _bookRooms,
                      child: submitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Confirm Check-In",
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
