import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../public/main_navigation.dart';
import '../../services/config.dart';

const Color royal = Color(0xFF875C3F);

class TicketStatusPage extends StatefulWidget {
  const TicketStatusPage({super.key});

  @override
  State<TicketStatusPage> createState() => _TicketStatusPageState();
}

class _TicketStatusPageState extends State<TicketStatusPage> {
  List<dynamic> tickets = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getInt("shopId");
      final userId = prefs.getString("userId");

      if (shopId == null || userId == null) return;

      final res = await http.get(
        Uri.parse("$baseUrl/submit-ticket/$shopId/$userId"),
      );

      if (res.statusCode == 200) {
        tickets = jsonDecode(res.body);
      } else {
        tickets = [];
      }
    } catch (e) {
      debugPrint("Error fetching tickets: $e");
      tickets = [];
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _statusChip(String status) {
    final style = _statusStyle(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style['color'].withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style['color']),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: style['color'],
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // Map ticket status to color & icon
  Map<String, dynamic> _statusStyle(String status) {
    switch (status.toUpperCase()) {
      case "PENDING":
        return {'color': Colors.orange, 'icon': Icons.hourglass_top};
      case "OPEN":
        return {'color': Colors.blue, 'icon': Icons.open_in_new};
      case "IN_PROGRESS":
        return {'color': Colors.purple, 'icon': Icons.autorenew};
      case "RESOLVED":
        return {'color': Colors.green, 'icon': Icons.check_circle};
      case "CLOSED":
        return {'color': Colors.grey, 'icon': Icons.close};
      default:
        return {'color': Colors.black, 'icon': Icons.info};
    }
  }

  Widget _buildTicketCard(Map ticket) {
    DateTime createdAt =
        DateTime.tryParse(ticket['created_at'] ?? '') ?? DateTime.now();
    DateTime updatedAt =
        DateTime.tryParse(ticket['updated_at'] ?? '') ?? DateTime.now();

    final status = ticket['status'] ?? 'UNKNOWN';

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: royal.withValues(alpha: 0.6)),
      ),

      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Top row: Issue + Status chip
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    ticket['issue'] ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _statusChip(status),
              ],
            ),


            const SizedBox(height: 10),

            /// Raised at

            Text(
              "Raised at • ${DateFormat('dd MMM yyyy').format(createdAt)}",
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "Last activity • ${DateFormat('dd MMM yyyy').format(updatedAt)}",
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),

            const Divider(height: 22,color: royal,thickness: 0.5,),

            /// Info text
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.support_agent, size: 18, color: Colors.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Our support team will review your request and contact you via registered email.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
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
      appBar: AppBar(
        title: const Text("Ticket Status"),
        backgroundColor: royal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            color: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: 2)),
              );
            },
          ),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : tickets.isEmpty
          ? const Center(child: Text("No tickets found."))
          : RefreshIndicator(
        onRefresh: _fetchTickets,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            final ticket = tickets[index] as Map;
            return _buildTicketCard(ticket);
          },
        ),
      ),
    );
  }
}
