import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/admin/booking/services/calender_book.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../public/config.dart';
import 'booking/services/check_in/checkin.dart';
import 'booking/services/upcoming/upcoming_bookings.dart';
import 'booking/services/history/booking_history.dart';
import 'booking/services/charges_for_booking.dart';
import 'booking/services/date_changing/booking_list.dart';
import 'booking/services/cancel/cancel.dart';
import 'booking/services/billing/billing.dart';
import 'booking/services/availability_calendar.dart';
import 'booking/services/view_facilitator.dart';
import 'booking/accounts/add_income_page.dart';
import 'booking/accounts/add_expense.dart';
import 'booking/accounts/view_finance.dart';
import 'booking/accounts/reports.dart';
import 'booking/accounts/add_drawing.dart';
import 'booking/services/history/cancel_history.dart';

const Color royalblue = Color(0xFF376EA1);
const Color royal = Color(0xFF19527A);
const Color royalLight = Color(0xFF629AC1);

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? selectedHall;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHall();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isError? Colors.redAccent.shade400 : royal,
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

  Future<void> _loadHall() async {
    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt('lodgeId');
    if (lodgeId != null) {
      await fetchHallDetails(lodgeId);
    } else {
      setState(() => _isLoading = false);
      _showMessage("No lodge ID found in saved data", isError: true);
    }
  }

  Future<void> fetchHallDetails(int lodgeId) async {
    try {
      final url = Uri.parse('$baseUrl/lodges/$lodgeId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          selectedHall = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showMessage("Failed to load lodge details (Code: ${response.statusCode})", isError: true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage("Error connecting to server: $e", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;
    double textScale = (screenWidth / 390).clamp(0.8, 1.4);
    double boxScale  = (screenHeight / 840).clamp(0.8, 1.4);

    return Scaffold(
      backgroundColor: royalLight.withValues(alpha: 0.2),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: royal),
      )
          : SingleChildScrollView(
        child: Container(padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (selectedHall != null)
              Align(
                alignment: Alignment.center,
                child: _buildHallCard(selectedHall!, textScale, boxScale,screenWidth),
              ),
            SizedBox(height: 20 * boxScale),
            Align(
              alignment: Alignment.center,
              child: _buildBookingServiceCard(
                  screenWidth),

            ),
            SizedBox(height: 20 * boxScale),

            Align(
              alignment: Alignment.center,
              child: _buildExpenseCard(screenWidth),
            ),
          ],
        ),
      ),
    )
    );
  }

  Widget _buildHallCard(
      Map<String, dynamic> hall,
      double textScale,
      double boxScale,
      double screenWidth,
      ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20 * boxScale),
        side: const BorderSide(
          color: royal,
          width: 1.5,
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16 * boxScale),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: (screenWidth > 900 ? 40 : 40) * boxScale,
              backgroundColor: royalLight,
              backgroundImage: hall['logo'] != null
                  ? MemoryImage(base64Decode(hall['logo']))
                  : null,
              child: hall['logo'] == null
                  ? Icon(Icons.home_work_rounded,
                  size: (screenWidth > 900 ? 40 : 40) * boxScale,
                  color: royal)
                  : null,
            ),
            SizedBox(width: 16 * boxScale),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hall['name'] ?? 'No Name',
                    style: TextStyle(
                      fontSize: 18 * textScale,
                      fontWeight: FontWeight.bold,
                      color: royal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4 * boxScale),
                  Text(
                    hall['address'] ?? 'No Address',
                    style: TextStyle(
                      fontSize: 14 * textScale,
                      color: royal,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseCard(double screenWidth) {
    final buttonSize = 70.0;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(
          color: royal,
          width: 1.5,
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Accounts",
                  style: TextStyle(
                    color: royal,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: const Icon(
                    Icons.arrow_drop_down,
                    color: royal,
                    size: 40,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildManageButton(
                  icon: Icons.list_alt,
                  label: "Add Income",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddIncomePage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.add_chart,
                  label: "Add Expense ",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddExpensePage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.add_to_photos,
                  label: "Add Drawing",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddDrawingPage()),
                    );
                  },
                  size: buttonSize,
                ),

                _buildManageButton(
                  icon: Icons.analytics,
                  label: "View Finance",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ViewFinancePage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.analytics,
                  label: "Reports",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ReportsPage()),
                    );
                  },
                  size: buttonSize,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingServiceCard(double screenWidth) {
    final double buttonSize = 70.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: royal, width: 1.5),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  "Booking Service",
                  style: TextStyle(
                    color: royal,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: royal, size: 40),
              ],
            ),

            const SizedBox(height: 16),

            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildManageButton(
                  icon: Icons.event_available,
                  label: "Room Booking",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => SelectRoomByCalendarPage()),
                    );
                  },
                  size: buttonSize,
                ),

                _buildManageButton(
                  icon: Icons.check_circle,
                  label: "Check In",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => PreBookedListPage()),
                    );
                  },
                  size: buttonSize,
                ),

                _buildManageButton(
                  icon: Icons.change_circle_outlined,
                  label: "Date Changing",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => DateChangingPage()),
                    );
                  },
                  size: buttonSize,
                ),

                _buildManageButton(
                  icon: Icons.cancel,
                  label: "Cancel Booking",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => CancelBookedPage()),
                    );
                  },
                  size: buttonSize,
                ),

                _buildManageButton(
                  icon: Icons.add_box,
                  label: "Add Charges",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => AddChargesPage()),
                    );
                  },
                  size: buttonSize,
                ),

                _buildManageButton(
                  icon: Icons.receipt_long,
                  label: "Check Out",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => BookingsListPage()),
                    );
                  },
                  size: buttonSize,
                ),

                _buildManageButton(
                  icon: Icons.search,
                  label: "Date Availability",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => AvailabilityCalendarPage()),
                    );
                  },
                  size: buttonSize,
                ),

                _buildManageButton(
                  icon: Icons.work_history_outlined,
                  label: "Upcoming Booking",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => UpcomingBookingsPage()),
                    );
                  },
                  size: buttonSize,
                ),

                _buildManageButton(
                  icon: Icons.history,
                  label: "Booking History",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => BookingsHistoryPage()),
                    );
                  },
                  size: buttonSize,
                ),

                _buildManageButton(
                  icon: Icons.free_cancellation,
                  label: "Cancellation History",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => CancelHistoryPage()),
                    );
                  },
                  size: buttonSize,
                ),

                _buildManageButton(
                  icon: Icons.domain_add,
                  label: "Facilitators",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ViewFacilitatorPage()),
                    );
                  },
                  size: buttonSize,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required double size,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: royalLight.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: royal,
                width: 1.5 ,
              ),
              boxShadow: [
                BoxShadow(
                  color: royal.withValues(alpha:0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, size: 32, color:Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: size,
          height: 36,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: royal,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
