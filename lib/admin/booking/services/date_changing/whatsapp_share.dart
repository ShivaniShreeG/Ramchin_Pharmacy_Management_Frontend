import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../public/main_navigation.dart';

const Color royal = Color(0xFF19527A);

class UpdatedBookingSummaryPage extends StatelessWidget {
  final Map<String, dynamic> oldBooking;
  final Map<String, dynamic> newBooking;
  final Map<String, dynamic> hallDetails;

  const UpdatedBookingSummaryPage({
    super.key,
    required this.oldBooking,
    required this.newBooking,
    required this.hallDetails,
  });

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

  Widget buildLabelValueBooking(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Flexible(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  List<String> parseAlternatePhones(dynamic altPhones) {
    List<String> phones = [];
    if (altPhones != null && altPhones.toString().isNotEmpty) {
      try {
        final alt = jsonDecode(altPhones.toString());
        if (alt is List) phones = alt.map((e) => e.toString()).toList();
      } catch (_) {
        phones = altPhones.toString().split(',').map((e) => e.trim()).toList();
      }
    }
    return phones;
  }

  String generateShareText() {
    final buffer = StringBuffer();

    buffer.writeln("```");
    buffer.writeln("   Updated Booking Confirmation");
    buffer.writeln("---------------------------");
    buffer.writeln("This is your official booking confirmation message from ${hallDetails['name']},${hallDetails['address']}");
    buffer.writeln("📱 ${hallDetails['phone']}");
    buffer.writeln("");

    buffer.writeln("Booking ID  : ${newBooking['booking_id']}");
    buffer.writeln("⚠️ Keep your Booking ID for future reference.");
    buffer.writeln("");

    buffer.writeln("Previous Booking:");
    buffer.writeln("Check-in : ${formatDateTime(oldBooking['check_in'])}");
    buffer.writeln("Check-out: ${formatDateTime(oldBooking['check_out'])}");

    final oldRooms = oldBooking['booked_room'] as List<dynamic>? ?? [];
    for (var room in oldRooms) {
      final name = room[0]?.toString() ?? '';
      final type = room[1]?.toString() ?? '';
      final nums = List<String>.from(room[2] ?? []);
      buffer.writeln("Room: $type - $name (${nums.join(', ')})");
    }

    buffer.writeln("");
    buffer.writeln("Updated Booking:");
    buffer.writeln("Check-in : ${formatDateTime(newBooking['check_in'])}");
    buffer.writeln("Check-out: ${formatDateTime(newBooking['check_out'])}");

    final newRooms = newBooking['booked_room'] as List<dynamic>? ?? [];
    for (var room in newRooms) {
      final name = room[0]?.toString() ?? '';
      final type = room[1]?.toString() ?? '';
      final nums = List<String>.from(room[2] ?? []);
      buffer.writeln("Room: $type - $name (${nums.join(', ')})");
    }

    buffer.writeln("---------------------------");
    buffer.writeln("Thank you for choosing us! 😊");
    buffer.writeln("```");

    return buffer.toString();
  }

  Future<void> shareViaWhatsApp() async {
    if (newBooking['phone'] == null || newBooking['phone'].toString().isEmpty) return;

    final text = Uri.encodeComponent(generateShareText());
    final phoneNumber = newBooking['phone'].toString().replaceAll(' ', '');
    final url = 'https://wa.me/$phoneNumber?text=$text';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      debugPrint("Cannot launch WhatsApp");
    }
  }

  Widget bookingDetailsCard() {
    final oldRooms = oldBooking['booked_room'] as List<dynamic>? ?? [];
    final newRooms = newBooking['booked_room'] as List<dynamic>? ?? [];

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
                Text("Previous Booking",
                    style: TextStyle(color: royal, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                if (oldBooking['check_in'] != null)
                  buildLabelValueBooking("Check-in", formatDateTime(oldBooking['check_in'])),
                if (oldBooking['check_out'] != null)
                  buildLabelValueBooking("Check-out", formatDateTime(oldBooking['check_out'])),
                if (oldRooms.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text("Rooms:", style: TextStyle(color: royal, fontWeight: FontWeight.bold)),
                  ...oldRooms.map((room) {
                    final name = room[0]?.toString() ?? '';
                    final type = room[1]?.toString() ?? '';
                    final nums = List<String>.from(room[2] ?? []);
                    return buildLabelValueBooking("Room", "$type - $name (${nums.join(', ')})");
                  }),
                ],
                const SizedBox(height: 15),
                Divider(color: royal, thickness: 1),
                const SizedBox(height: 10),
                Text("Updated Booking",
                    style: TextStyle(color: royal, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                if (newBooking['check_in'] != null)
                  buildLabelValueBooking("Check-in", formatDateTime(newBooking['check_in'])),
                if (newBooking['check_out'] != null)
                  buildLabelValueBooking("Check-out", formatDateTime(newBooking['check_out'])),
                if (newRooms.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text("Rooms:", style: TextStyle(color: royal, fontWeight: FontWeight.bold)),
                  ...newRooms.map((room) {
                    final name = room[0]?.toString() ?? '';
                    final type = room[1]?.toString() ?? '';
                    final nums = List<String>.from(room[2] ?? []);
                    return buildLabelValueBooking("Room", "$type - $name (${nums.join(', ')})");
                  }),
                ],
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
              child: const Text(
                "Booking Summary",
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
    );
  }

  void _handleBackNavigation(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigation(initialIndex: 0)),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackNavigation(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Booking Summary",style: TextStyle(color: Colors.white),),
          backgroundColor: royal,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back,color: Colors.white),
            onPressed: () => _handleBackNavigation(context),
          ),
        ),
        backgroundColor: Colors.grey.shade100,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              bookingDetailsCard(),
            ],
          ),
        ),
      ),
    );
  }
}
