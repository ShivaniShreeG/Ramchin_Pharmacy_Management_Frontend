import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // for date formatting
import '../../../public/config.dart';

const Color royalblue = Color(0xFF376EA1);
const Color royal = Color(0xFF19527A);
const Color royalLight = Color(0xFF629AC1);

class ViewTicketsPage extends StatefulWidget {
  final dynamic hall;

  const ViewTicketsPage({super.key, required this.hall});

  @override
  State<ViewTicketsPage> createState() => _ViewTicketsPageState();
}

class _ViewTicketsPageState extends State<ViewTicketsPage> {

  bool _isLoading = true;
  List<dynamic> _messages = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/submit-ticket/lodge/${widget.hall['lodge_id']}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages = (data is List) ? data : [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _showMessage("❌ Failed to load messages (Code: ${response.statusCode}).");
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _showMessage("❌ Error fetching messages: $e");
        _isLoading = false;
      });
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:  TextStyle(
            color: isError ? Colors.redAccent.shade400 : royal,
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

  String _formatDate(String? isoDate) {
    if (isoDate == null) return "Unknown Date";
    try {
      final dateTime = DateTime.parse(isoDate).toLocal();
      return DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        foregroundColor: Colors.white,
        title: Text(
          "Tickets - ${widget.hall['name'] ?? 'Lodge'}",
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Colors.white,
            onPressed: _fetchMessages,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: TextStyle(color: royal, fontSize: 16),
        ),
      )
          : _messages.isEmpty
          ? Center(
        child: Text(
          "No tickets found for this hall.",
          style: TextStyle(color: royal, fontSize: 16),
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchMessages,
        color: royal,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            final ticket = _messages[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: royalLight.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: royal, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket['issue'] ?? 'No issue provided',
                    style: TextStyle(
                      color: royal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.person, color: royal, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        "User ID: ${ticket['user_id'] ?? 'Unknown'}",
                        style: TextStyle(
                          color: royal.withValues(alpha:0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, color: royal, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(ticket['created_at']),
                        style: TextStyle(
                          color: royal.withValues(alpha:0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),

                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
