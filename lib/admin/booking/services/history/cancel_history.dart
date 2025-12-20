import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../public/config.dart';
import '../../../../public/main_navigation.dart';
import 'cancel_history_details.dart';
import 'package:intl/intl.dart';
import 'partial_history.dart';

const Color royalblue = Color(0xFF376EA1);
const Color royal = Color(0xFF19527A);
const Color royalLight = Color(0xFF629AC1);

class CancelHistoryPage extends StatefulWidget {
  const CancelHistoryPage({super.key});

  @override
  State<CancelHistoryPage> createState() => _CancelHistoryPageState();
}

class _CancelHistoryPageState extends State<CancelHistoryPage> {
  bool _isFetching = true;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _filteredBookings = [];
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? hallDetails;
  DateTime? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _loadBookings();
    _searchController.addListener(_onSearchChanged);
    _fetchHallDetails();
  }

  void _applyFilters() {
    if (_selectedMonth == null) {
      setState(() => _filteredBookings = _bookings);
      return;
    }

    final month = _selectedMonth!.month;
    final year = _selectedMonth!.year;

    setState(() {
      _filteredBookings = _bookings.where((b) {
        final checkIn = DateTime.parse(b["check_in"]);
        return checkIn.month == month && checkIn.year == year;
      }).toList();
    });
  }

  Future<void> _pickMonthYear() async {
    int selectedYear = _selectedMonth?.year ?? DateTime.now().year;
    int selectedMonth = _selectedMonth?.month ?? DateTime.now().month;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              title: const Text("Select Month & Year"),
              titleTextStyle: TextStyle(color: royal,fontSize: 25),
              content: SizedBox(
                height: 260,
                child: Column(
                  children: [
                    // Year selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          color: royal,
                          onPressed: () {
                            setInnerState(() => selectedYear--); // FIX ✔
                          },
                        ),
                        Text(
                          "$selectedYear",
                          style: const TextStyle(fontSize: 20,color: royal),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          color: royal,
                          onPressed: () {
                            setInnerState(() => selectedYear++); // FIX ✔
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Month grid
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 3,
                        children: List.generate(12, (i) {
                          final monthNum = i + 1;
                          final monthName = DateFormat('MMMM')
                              .format(DateTime(2024, monthNum));

                          final isSelected =
                              monthNum == selectedMonth &&
                                  selectedYear == (_selectedMonth?.year ?? -1);

                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              setState(() {
                                _selectedMonth =
                                    DateTime(selectedYear, monthNum);
                              });
                              _applyFilters();
                            },
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? royal
                                    : royalLight.withAlpha(40),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  monthName.substring(0, 3),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : royal,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");

    if (lodgeId == null) return;

    try {
      final fullUrl = Uri.parse("$baseUrl/history/cancelled/$lodgeId");
      final fullRes = await http.get(fullUrl);

      List<Map<String, dynamic>> fullCancelData = [];
      if (fullRes.statusCode == 200) {
        final fullData = jsonDecode(fullRes.body);
        if (fullData is List) {
          fullCancelData = List<Map<String, dynamic>>.from(fullData);
        }
      }
      final partialUrl = Uri.parse("$baseUrl/history/partial/$lodgeId");
      final partialRes = await http.get(partialUrl);

      List<Map<String, dynamic>> partialCancelData = [];
      if (partialRes.statusCode == 200) {
        final partialData = jsonDecode(partialRes.body);
        if (partialData is List) {
          partialCancelData = partialData.map<Map<String, dynamic>>((p) {
            final booking = p["booking"];
            return {
              "partial_id": p["id"],
              "booking_id": booking["booking_id"],
              "name": booking["name"],
              "phone": booking["phone"],
              "booked_room":booking["booked_room"],
              "check_in": booking["check_in"],
              "check_out": booking["check_out"],
              "status": "PARTIAL CANCEL",
              "partial_data": p,
            };
          }).toList();
        }
      }

      List<Map<String, dynamic>> finalData = [
        ...fullCancelData,
        ...partialCancelData
      ];

      finalData.sort((a, b) {
        return DateTime.parse(a["check_in"])
            .compareTo(DateTime.parse(b["check_in"]));
      });

      setState(() {
        _bookings = finalData;
        _filteredBookings = _bookings;
      });
      _applyFilters();
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => _isFetching = false);
    }
  }

  String formatDateTime(String dateTimeString) {
    try {
      final dt = DateTime.parse(dateTimeString);
      return DateFormat('dd MMM yyyy • hh:mm a').format(dt);
    } catch (e) {
      return dateTimeString;
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

  void _onSearchChanged() {
    final q = _searchController.text.toLowerCase();

    setState(() {
      _filteredBookings = _bookings.where((b) {
        final name = b["name"].toString().toLowerCase();
        final phone = b["phone"].toString().toLowerCase();
        final room = b["room_name"].toString().toLowerCase();
        final id = b["booking_id"].toString().toLowerCase();

        return name.contains(q) ||
            phone.contains(q) ||
            room.contains(q) ||
            id.contains(q);
      }).toList();
    });
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

  Widget _buildBookingCard(Map<String, dynamic> b) {
    return GestureDetector(
      onTap: () {
        if (b["status"] == "PARTIAL CANCEL") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PartialCancelDetailsPage(booking: b["partial_data"]),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CancelDetailsPage(booking: b),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: royalLight.withAlpha(18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: royal, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Booking #${b["booking_id"]}",
                  style: TextStyle(
                      color: royal, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    b["status"] == "PARTIAL CANCEL" ? "PARTIAL" : b["status"],
                    style: TextStyle(
                      color: royal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Icon(Icons.person, size: 18, color: royal),
                const SizedBox(width: 6),
                Text(
                  b["name"],
                  style: TextStyle(color: royal, fontSize: 16),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Row(
              children: [
                Icon(Icons.phone, size: 18, color: royal),
                const SizedBox(width: 6),
                Text(
                  b["phone"].toString(),
                  style: TextStyle(color: royal, fontSize: 15),
                ),
              ],
            ),

            const SizedBox(height: 6),

            if (b["booked_room"] != null && (b["booked_room"] as List).isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: (b["booked_room"] as List<dynamic>).map<Widget>((room) {
                  final roomName = room[0] ?? "-";
                  final roomType = room[1] ?? "-";
                  final roomNumbers = room[2] != null && (room[2] as List).isNotEmpty
                      ? (room[2] as List).join(", ")
                      : "-";

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.meeting_room, size: 18, color: royal),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "$roomName ($roomType) • Rooms: $roomNumbers",
                            style: TextStyle(color: royal, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 8),

            Row(
              children: [
                Icon(Icons.login, size: 18, color: royal),
                const SizedBox(width: 6),
                Text(
                  "Check-In: ${formatDateTime(b["check_in"])}",
                  style: TextStyle(color: royal, fontSize: 15),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Row(
              children: [
                Icon(Icons.logout, size: 18, color: royal),
                const SizedBox(width: 6),
                Text(
                  "Check-Out: ${formatDateTime(b["check_out"])}",
                  style: TextStyle(color: royal, fontSize: 15),
                ),
              ],
            ),

          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text("Cancel History", style: TextStyle(color: Colors.white)),
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
      body: _isFetching
          ? Center(child: CircularProgressIndicator(color: royal))
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            hallDetails == null
                ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
                : _buildHallCard(hallDetails!),

            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              style: TextStyle(color: royal),
              cursorColor: royal,
              decoration: InputDecoration(
                hintText: "Search by name, phone, room, booking id...",
                hintStyle: TextStyle(color: royal),
                prefixIcon: Icon(Icons.search, color: royal),
                filled: true,
                fillColor: royalLight.withAlpha(20),
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
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickMonthYear,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      _selectedMonth == null
                          ? "Filter by Month"
                          : DateFormat("MMMM yyyy").format(_selectedMonth!),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: royal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _filteredBookings.isEmpty
                  ? Center(
                child: Text(
                  "No pre-bookings found",
                  style: TextStyle(color: royal, fontSize: 16),
                ),
              )
                  : ListView(
                children: _filteredBookings
                    .map(_buildBookingCard)
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
