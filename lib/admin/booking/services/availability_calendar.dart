import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../public/config.dart';
import '../../../public/main_navigation.dart';

const Color royalblue = Color(0xFF376EA1);
const Color royal = Color(0xFF19527A);
const Color royalLight = Color(0xFF629AC1);

class AvailabilityCalendarPage extends StatefulWidget {
  const AvailabilityCalendarPage({super.key});

  @override
  State<AvailabilityCalendarPage> createState() =>
      _AvailabilityCalendarPageState();
}

class _AvailabilityCalendarPageState extends State<AvailabilityCalendarPage> {
  int? lodgeId;

  DateTime? checkIn;
  DateTime? checkOut;

  bool loadingRooms = false;
  List<dynamic> availableRooms = [];
  Map<String, dynamic>? hallDetails;

  @override
  void initState() {
    super.initState();
    _loadLodge();

  }

  Future<void> _loadLodge() async {
    final prefs = await SharedPreferences.getInstance();
    lodgeId = prefs.getInt("lodgeId");
    if (lodgeId == null) {
      _showMessage("No lodge selected.");
      return;
    }

    await _fetchHallDetails(lodgeId!);
    setState(() {});
  }

  Future<void> _fetchAvailableRooms() async {
    if (checkIn == null || checkOut == null || lodgeId == null) return;

    setState(() => loadingRooms = true);

    final url = Uri.parse(
      "$baseUrl/calendar/available-rooms/$lodgeId"
          "?check_in=${checkIn!.toIso8601String()}"
          "&check_out=${checkOut!.toIso8601String()}",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      availableRooms = jsonDecode(response.body);
    } else {
      availableRooms = [];
    }

    setState(() => loadingRooms = false);
  }

  Future<void> _fetchHallDetails(int lodgeId) async {
    try {
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

  String formatDateTime12(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? "PM" : "AM";

    return "${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')} "
        "$hour:$minute $ampm";
  }

  void _selectCheckInOut(DateTime selected) async {
    DateTime? tempIn;
    DateTime? tempOut;

    tempIn = DateTime(selected.year, selected.month, selected.day, 18, 0);
    final nextDay = selected.add(const Duration(days: 1));
    tempOut = DateTime(nextDay.year, nextDay.month, nextDay.day, 18, 0);

    final result = await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, update) {
            return AlertDialog(
              title: const Center(
                child: Text(
                  "Select Check-In & Check-Out",
                  style: TextStyle(
                    color: royal,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Check-In",
                    style: TextStyle(
                      color: royal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: royal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      final dt = await _pickDateTime(tempIn!);
                      if (dt != null) update(() => tempIn = dt);
                    },
                    child: Text(
                      formatDateTime12(tempIn!),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    "Check-Out",
                    style: TextStyle(
                      color: royal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: royal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      final dt = await _pickDateTime(tempOut!);
                      if (dt != null) update(() => tempOut = dt);
                    },
                    child: Text(
                      formatDateTime12(tempOut!),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),

              actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: royal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),


                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: royal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, "OK"),
                  child: const Text(
                    "OK",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == "OK") {
      setState(() {
        checkIn = tempIn;
        checkOut = tempOut;
      });

      await _fetchAvailableRooms();
    }
  }

  void _selectRoomNumbers(dynamic room) {
    final List<String> allNumbers =
    List<String>.from(room['all_room_numbers'] ?? []);
    final Set<String> availableNumbers =
    Set<String>.from(room['available_rooms'] ?? []);

    final selected = <String>[];

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, update) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),

              title: Center(
                child: Text(
                  "Select Rooms (${room['room_type']} - ${room['room_name']})",
                  style: const TextStyle(
                    color: royal,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: allNumbers.map((n) {
                        final bool isAvailable = availableNumbers.contains(n);
                        final bool isSelected = selected.contains(n);

                        return ChoiceChip(
                          label: Text(n),
                          selected: isSelected,
                          selectedColor: royal,
                          disabledColor: Colors.grey.shade300,
                          labelStyle: TextStyle(
                            color: isAvailable
                                ? (isSelected ? Colors.white : royal)
                                : royal,
                          ),
                          checkmarkColor: Colors.white,
                          side: BorderSide(color: royal),
                          onSelected: isAvailable
                              ? (_) {
                            update(() {
                              isSelected
                                  ? selected.remove(n)
                                  : selected.add(n);
                            });
                          }
                              : null,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: royal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (lodgeId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: royal)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text("Date Availability",
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: 0)),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (hallDetails != null)
              _buildHallCard(hallDetails!),
            const SizedBox(height: 20),
            if (checkIn == null && checkOut == null)
              Center(
                child: SizedBox(
                  width: 350,
                  child: Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                        color: royal,
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: TableCalendar(
                        firstDay: DateTime.now(),
                        lastDay: DateTime.now().add(const Duration(days: 365)),
                        focusedDay: DateTime.now(),
                        calendarFormat: CalendarFormat.month,
                        onDaySelected: (day, _) => _selectCheckInOut(day),
                        selectedDayPredicate: (_) => false,
                        availableGestures: AvailableGestures.all,

                        calendarStyle: CalendarStyle(
                          defaultTextStyle: const TextStyle(color: royal),
                          weekendTextStyle: const TextStyle(color: royal),

                          todayDecoration: BoxDecoration(
                            color: royal.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: royal, width: 2),
                          ),
                          todayTextStyle: const TextStyle(
                            color: royal,
                            fontWeight: FontWeight.bold,
                          ),

                          selectedDecoration: BoxDecoration(
                            color: royal,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          selectedTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        headerStyle: const HeaderStyle(
                          titleCentered: true,
                          formatButtonVisible: false,
                          titleTextStyle: TextStyle(
                            color: royal,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle: TextStyle(color: royal),
                          weekendStyle: TextStyle(color: royal),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (checkIn == null && checkOut == null)
              const SizedBox(height: 5),
            if (checkIn == null && checkOut == null)
              Text(
                "Please select a date from the calendar.",
                style: TextStyle(color: royal),
              ),

            const SizedBox(height: 20),

            if (checkIn != null && checkOut != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: royal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            checkIn = null;
                            checkOut = null;
                            availableRooms = [];
                          });
                        },
                        child: const Text(
                          "Change Date",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      "Available Rooms",
                      style: const TextStyle(
                        color: royal,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Center(
                    child: Text(
                      "Check-In: ${formatDateTime12(checkIn!)}",
                      style: const TextStyle(
                        color: royal,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  Center(
                    child: Text(
                      "Check-Out: ${formatDateTime12(checkOut!)}",
                      style: const TextStyle(
                        color: royal,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),

            const SizedBox(height: 20),

            if (loadingRooms)
              const CircularProgressIndicator(color: royal)
            else
              Column(
                children: availableRooms.map((room) {
                  return Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                        color: royal,
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      title: Text(
                        "${room['room_type']} - ${room['room_name']}",
                        style: const TextStyle(
                          color: royal,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        "Available: ${room['available_rooms'].length} / ${room['total_rooms']}",
                        style: TextStyle(color: royal),
                      ),
                      trailing:
                      const Icon(Icons.arrow_forward_ios, color: royal),
                      onTap: () => _selectRoomNumbers(room),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
